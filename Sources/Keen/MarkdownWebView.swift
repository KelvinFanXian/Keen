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
    @Binding var selectedHeadingID: String?
    let openLocalMarkdown: (URL, String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedHeadingID: $selectedHeadingID, sourceURL: sourceURL, openLocalMarkdown: openLocalMarkdown)
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
        webView.loadHTMLString(document.html, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.openLocalMarkdown = openLocalMarkdown
        context.coordinator.sourceURL = sourceURL
        if context.coordinator.loadedToken != reloadToken {
            if context.coordinator.loadedSourceURL == sourceURL {
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
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "keen")
        webView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        @Binding var selectedHeadingID: String?
        var sourceURL: URL
        var openLocalMarkdown: (URL, String?) -> Void
        weak var webView: WKWebView?
        var loadedToken: UUID?
        var loadedSourceURL: URL?
        var lastRequestedHeading: String?
        var pendingHeadingID: String?
        var configurationScript = "window.keenConfigure('system', 'swiss', 15, 860);"
        private var savedHeading: String?
        private var savedOffset: Double = 0

        init(selectedHeadingID: Binding<String?>, sourceURL: URL, openLocalMarkdown: @escaping (URL, String?) -> Void) {
            _selectedHeadingID = selectedHeadingID
            self.sourceURL = sourceURL
            self.openLocalMarkdown = openLocalMarkdown
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let object = message.body as? [String: Any], object["type"] as? String == "heading", let id = object["id"] as? String else { return }
            lastRequestedHeading = id
            selectedHeadingID = id
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(configurationScript)
            if let targetHeading = pendingHeadingID ?? savedHeading ?? selectedHeadingID {
                let encoded = targetHeading.replacingOccurrences(of: "'", with: "\\'")
                webView.evaluateJavaScript("window.keenScrollTo('\(encoded)'); window.scrollBy(0, \(savedOffset));")
                self.savedHeading = nil
                self.pendingHeadingID = nil
                self.lastRequestedHeading = targetHeading
            } else {
                webView.evaluateJavaScript("window.scrollTo(0, 0)")
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
