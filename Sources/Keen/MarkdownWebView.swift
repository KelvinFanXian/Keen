import AppKit
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let document: RenderedDocument
    let sourceURL: URL
    let baseURL: URL
    let theme: ReadingTheme
    let readingStyle: ReadingStyle
    let fontSize: Double
    let readingWidth: Double
    let reloadToken: UUID
    let restoreScrollY: Double?
    let findCommand: PageFindCommand
    @Binding var findResult: PageFindResult
    @Binding var selectedHeadingID: String?
    let openLocalMarkdown: (URL, String?) -> Void
    let onScrollPositionChanged: (URL, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(findResult: $findResult, selectedHeadingID: $selectedHeadingID, sourceURL: sourceURL, openLocalMarkdown: openLocalMarkdown, onScrollPositionChanged: onScrollPositionChanged)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "keen")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.loadedToken = reloadToken
        context.coordinator.loadedSourceURL = sourceURL
        context.coordinator.pendingScrollY = restoreScrollY
        webView.loadHTMLString(document.html, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.openLocalMarkdown = openLocalMarkdown
        context.coordinator.onScrollPositionChanged = onScrollPositionChanged
        context.coordinator.sourceURL = sourceURL
        context.coordinator.findCommand = findCommand
        if context.coordinator.loadedToken != reloadToken {
            if let restoreScrollY {
                context.coordinator.pendingScrollY = restoreScrollY
            } else if context.coordinator.loadedSourceURL == sourceURL {
                context.coordinator.capturePosition()
            } else {
                context.coordinator.pendingHeadingID = selectedHeadingID
            }
            context.coordinator.loadedToken = reloadToken
            context.coordinator.loadedSourceURL = sourceURL
            webView.loadHTMLString(document.html, baseURL: baseURL)
        }
        let js = "window.keenConfigure('\(theme.rawValue)', '\(readingStyle.rawValue)', \(fontSize), \(readingWidth));"
        context.coordinator.configurationScript = js
        webView.evaluateJavaScript(js)
        if context.coordinator.lastRequestedHeading != selectedHeadingID, let id = selectedHeadingID {
            context.coordinator.lastRequestedHeading = id
            let encoded = id.replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("window.keenScrollTo('\(encoded)')")
        }
        context.coordinator.performFindIfNeeded()
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "keen")
        webView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        @Binding var findResult: PageFindResult
        @Binding var selectedHeadingID: String?
        var sourceURL: URL
        var openLocalMarkdown: (URL, String?) -> Void
        var onScrollPositionChanged: (URL, Double) -> Void
        weak var webView: WKWebView?
        var loadedToken: UUID?
        var loadedSourceURL: URL?
        var lastRequestedHeading: String?
        var pendingHeadingID: String?
        var pendingScrollY: Double?
        var configurationScript = "window.keenConfigure('system', 'swiss', 15, 860);"
        var findCommand = PageFindCommand()
        private var performedFindRevision = -1
        private var savedHeading: String?
        private var savedOffset: Double = 0

        init(findResult: Binding<PageFindResult>, selectedHeadingID: Binding<String?>, sourceURL: URL, openLocalMarkdown: @escaping (URL, String?) -> Void, onScrollPositionChanged: @escaping (URL, Double) -> Void) {
            _findResult = findResult
            _selectedHeadingID = selectedHeadingID
            self.sourceURL = sourceURL
            self.openLocalMarkdown = openLocalMarkdown
            self.onScrollPositionChanged = onScrollPositionChanged
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let object = message.body as? [String: Any], let type = object["type"] as? String else { return }
            switch type {
            case "heading":
                guard let id = object["id"] as? String else { return }
                lastRequestedHeading = id
                selectedHeadingID = id
            case "scroll":
                guard let y = object["y"] as? Double else { return }
                onScrollPositionChanged(sourceURL, y)
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(configurationScript)
            if let pendingScrollY {
                webView.evaluateJavaScript("window.scrollTo(0, \(pendingScrollY))")
                self.pendingScrollY = nil
                self.pendingHeadingID = nil
                self.savedHeading = nil
                self.savedOffset = 0
                self.lastRequestedHeading = selectedHeadingID
            } else if let targetHeading = pendingHeadingID ?? savedHeading ?? selectedHeadingID {
                let encoded = targetHeading.replacingOccurrences(of: "'", with: "\\'")
                webView.evaluateJavaScript("window.keenScrollTo('\(encoded)'); window.scrollBy(0, \(savedOffset));")
                self.savedHeading = nil
                self.pendingHeadingID = nil
                self.lastRequestedHeading = targetHeading
            } else {
                webView.evaluateJavaScript("window.scrollTo(0, 0)")
            }
            performedFindRevision = -1
            performFindIfNeeded()
        }

        func performFindIfNeeded() {
            guard performedFindRevision != findCommand.revision, let webView else { return }
            performedFindRevision = findCommand.revision
            let query = findCommand.active ? findCommand.query : ""
            guard let data = try? JSONEncoder().encode(query),
                  let encodedQuery = String(data: data, encoding: .utf8) else { return }
            let script = "window.keenFind(\(encodedQuery), \(findCommand.backwards ? "true" : "false"));"
            webView.evaluateJavaScript(PageFindScript.source + script) { [weak self] value, _ in
                let dictionary = value as? [String: Any]
                let result = PageFindResult(
                    index: dictionary?["index"] as? Int ?? 0,
                    count: dictionary?["count"] as? Int ?? 0
                )
                DispatchQueue.main.async { self?.findResult = result }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
                return .allow
            }
            if let target = DocumentLinkResolver.resolve(url) {
                if target.fileURL.standardizedFileURL == sourceURL.standardizedFileURL,
                   let headingID = target.headingID {
                    selectedHeadingID = headingID
                    lastRequestedHeading = headingID
                    let encoded = headingID.replacingOccurrences(of: "'", with: "\\'")
                    _ = try? await webView.evaluateJavaScript("window.keenScrollTo('\(encoded)')")
                } else {
                    if let scrollY = try? await webView.evaluateJavaScript("window.scrollY") as? Double {
                        onScrollPositionChanged(sourceURL, scrollY)
                    }
                    openLocalMarkdown(target.fileURL, target.headingID)
                }
            } else if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            } else if url.isFileURL {
                NSWorkspace.shared.open(url)
            }
            return .cancel
        }

        func capturePosition() {
            savedHeading = selectedHeadingID
            let id = selectedHeadingID?.replacingOccurrences(of: "'", with: "\\'") ?? ""
            webView?.evaluateJavaScript("window.scrollY - (document.getElementById('\(id)')?.offsetTop || 0)") { [weak self] value, _ in
                self?.savedOffset = value as? Double ?? 0
            }
        }
    }
}

struct PageFindCommand: Equatable {
    private(set) var query = ""
    private(set) var backwards = false
    private(set) var active = false
    private(set) var revision = 0

    mutating func activate(query: String) {
        active = true
        request(query: query, backwards: false)
    }

    mutating func deactivate() {
        active = false
        revision += 1
    }

    mutating func request(query: String, backwards: Bool) {
        self.query = query
        self.backwards = backwards
        revision += 1
    }
}

struct PageFindResult: Equatable {
    var index = 0
    var count = 0
}

private enum PageFindScript {
    static let source = #"""
    (() => {
      if (window.keenFind) return;
      const clear = () => {
        document.querySelectorAll('mark[data-keen-find]').forEach(mark => {
          mark.replaceWith(document.createTextNode(mark.textContent || ''));
        });
        (document.querySelector('main') || document.body).normalize();
        window.__keenFindQuery = '';
        window.__keenFindIndex = -1;
      };
      window.keenFind = (query, backwards) => {
        query = query || '';
        const sameQuery = window.__keenFindQuery === query;
        if (!sameQuery) {
          clear();
          window.__keenFindQuery = query;
          if (query) {
            const root = document.querySelector('main') || document.body;
            const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
              acceptNode(node) {
                if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
                const parent = node.parentElement;
                if (!parent || parent.closest('script, style, textarea, svg, mark[data-keen-find]')) return NodeFilter.FILTER_REJECT;
                return NodeFilter.FILTER_ACCEPT;
              }
            });
            const nodes = [];
            while (walker.nextNode()) nodes.push(walker.currentNode);
            const needle = query.toLocaleLowerCase();
            nodes.forEach(node => {
              const text = node.nodeValue || '';
              const lower = text.toLocaleLowerCase();
              let start = 0;
              let match;
              const fragment = document.createDocumentFragment();
              while ((match = lower.indexOf(needle, start)) !== -1) {
                if (match > start) fragment.append(document.createTextNode(text.slice(start, match)));
                const mark = document.createElement('mark');
                mark.dataset.keenFind = 'true';
                mark.textContent = text.slice(match, match + query.length);
                mark.style.cssText = 'background:#ffe08a;color:inherit;border-radius:2px;padding:0 1px;';
                fragment.append(mark);
                start = match + query.length;
              }
              if (start > 0) {
                if (start < text.length) fragment.append(document.createTextNode(text.slice(start)));
                node.replaceWith(fragment);
              }
            });
          }
        }
        const marks = Array.from(document.querySelectorAll('mark[data-keen-find]'));
        if (!marks.length) {
          window.__keenFindIndex = -1;
          return { index: 0, count: 0 };
        }
        let index = window.__keenFindIndex;
        if (!sameQuery || index < 0 || index >= marks.length) index = backwards ? marks.length - 1 : 0;
        else index = (index + (backwards ? -1 : 1) + marks.length) % marks.length;
        marks.forEach((mark, itemIndex) => {
          mark.style.background = itemIndex === index ? '#ffad42' : '#ffe08a';
          mark.style.boxShadow = itemIndex === index ? '0 0 0 1px rgba(170,90,0,.28)' : 'none';
        });
        window.__keenFindIndex = index;
        marks[index].scrollIntoView({ block: 'center', behavior: 'smooth' });
        return { index: index + 1, count: marks.length };
      };
    })();
    """#
}
