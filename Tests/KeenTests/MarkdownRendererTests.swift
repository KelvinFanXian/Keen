import Foundation
import Testing
import WebKit
@testable import Keen

@Test func rendersHeadingsAndSourceLines() {
    let source = """
    # Keen

    正文

    ## 阅读体验
    """
    let result = MarkdownRenderer().render(source: source, baseURL: URL(fileURLWithPath: "/tmp"))
    #expect(result.headings.count == 2)
    #expect(result.headings[0].title == "Keen")
    #expect(result.headings[0].line == 1)
    #expect(result.headings[1].line == 5)
    #expect(result.html.contains("id=\"keen\""))
}

@Test func escapesUntrustedHTML() {
    let result = MarkdownRenderer().render(source: "<script>alert('x')</script>", baseURL: URL(fileURLWithPath: "/tmp"))
    #expect(!result.html.contains("<script>alert('x')</script>"))
    #expect(result.html.contains("&lt;script&gt;"))
}

@Test func rendersGFMTableAndTaskList() {
    let source = """
    | 功能 | 状态 |
    | --- | --- |
    | 大纲 | 完成 |

    - [x] 渲染
    - [ ] 搜索
    """
    let result = MarkdownRenderer().render(source: source, baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(result.html.contains("class=\"table-wrap\""))
    #expect(result.html.contains("<table class=\"columns-2\">"))
    #expect(result.html.contains("<ul class=\"task-list\">"))
    #expect(result.html.contains("type=\"checkbox\" checked"))
}

@Test func usesOnlySwissLightReadingStyle() {
    let result = MarkdownRenderer().render(source: "# 阅读", baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(ReadingStyle.allCases == [.swiss])
    #expect(ReadingTheme.allCases == [.light])
    #expect(result.html.contains("data-style='swiss'"))
    #expect(!result.html.contains("data-style='everforest-light'"))
    #expect(result.html.contains("window.keenConfigure=(theme,style,size,width,enableVim)"))
}

@Test func vimReaderCommandsStayInReadOnlyWebView() {
    let result = MarkdownRenderer().render(source: "# 阅读", baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(result.html.contains("if(!vimEnabled || event.defaultPrevented || event.metaKey || event.altKey || event.isComposing) return"))
    #expect(result.html.contains("input,textarea,select,[contenteditable="))
    for command in ["nextFind", "previousFind", "back", "forward", "nextTab", "previousTab"] {
        #expect(result.html.contains("sendVimCommand('\(command)')"))
    }
}

@Test func appliesHistoryWidthsOnlyToMatchingTable() {
    let source = """
    | 时间 | 版本 | 描述 | 作者 | 审核人 |
    | --- | --- | --- | --- | --- |
    | 2026-10-13 15:49:57 | 0.1 | 建档 | 范显 | |

    | 日期 | 编号 | 标题 | 状态 | 记录 |
    | --- | --- | --- | --- | --- |
    | 2026-10-13 | G:B43 | 标题 | 处理中 | 记录.md |
    """
    let result = MarkdownRenderer().render(source: source, baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(result.html.components(separatedBy: "<table class=\"columns-5 history-table\">").count == 2)
    #expect(result.html.contains("class=\"columns-5\"><thead><tr><th>日期</th>"))
    #expect(result.html.contains("html[data-style='swiss'] table.history-table,table.history-table { width:100%; table-layout:auto; }"))
}

@Test func appliesStableWidthsToIssueTable() {
    let source = """
    | 正式编号 | 问题 | 证据 | 状态 |
    | --- | --- | --- | --- |
    | G:B37 | 新增按钮不可见 | 审计命中 | 已修复 |
    """
    let result = MarkdownRenderer().render(source: source, baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(result.html.contains("<table class=\"columns-4 issue-table\">"))
    #expect(result.html.contains("table.issue-table th:nth-child(1)"))
}

@Test func rendersRemoteImagesAndBlocksUnsafeSources() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let images = directory.appendingPathComponent("images", isDirectory: true)
    try? FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try? Data([0x89, 0x50, 0x4e, 0x47]).write(to: images.appendingPathComponent("diagram.png"))
    let source = """
    ![remote](https://example.com/a.png)
    ![insecure](http://example.com/b.png)
    ![scheme-relative](//example.com/c.png)
    ![script](javascript:alert(1))
    ![file](file:///tmp/private.png)
    ![traverse](../secret.png)
    ![local](images/diagram.png)
    """
    let result = MarkdownRenderer().render(source: source, baseURL: directory)
    #expect(result.html.contains("src=\"https://example.com/a.png\" alt=\"remote\" data-remote-image"))
    #expect(result.html.contains("src=\"http://example.com/b.png\" alt=\"insecure\" data-remote-image"))
    #expect(result.html.contains("src=\"https://example.com/c.png\" alt=\"scheme-relative\" data-remote-image"))
    #expect(!result.html.contains("src=\"javascript:"))
    #expect(!result.html.contains("src=\"file:"))
    #expect(!result.html.contains("src=\"../secret.png"))
    #expect(result.html.contains("src=\"keen-local-image:"))
    #expect(result.html.contains("images/diagram.png"))
    #expect(result.html.contains("img.addEventListener('error',showFailure"))
    #expect(result.html.contains("fallback.append(link)"))
}

@Test func loadsChineseNamedImagesOnlyInsideDocumentDirectory() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let images = directory.appendingPathComponent("prd", isDirectory: true)
    try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let image = images.appendingPathComponent("01-在线打码新增页.png")
    try Data([0x89, 0x50, 0x4e, 0x47]).write(to: image)
    let resourceURL = try #require(LocalImageResource.url(for: "./prd/01-在线打码新增页.png", relativeTo: directory))
    #expect(LocalImageResource.fileURL(for: resourceURL, inside: directory) == image)
    #expect(LocalImageResource.url(for: "../outside.png", relativeTo: directory) == nil)
    #expect(LocalImageResource.url(for: "https://example.com/a.png", relativeTo: directory) == nil)
    #expect(LocalImageResource.fileURL(for: resourceURL, inside: directory.appendingPathComponent("other")) == nil)
}

@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["KEEN_WEBKIT_INTEGRATION"] == "1"))
func webViewLoadsLocalImageResource() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let image = directory.appendingPathComponent("图片.png")
    let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg=="))
    try png.write(to: image)
    let resourceURL = try #require(LocalImageResource.url(for: "图片.png", relativeTo: directory))

    let configuration = WKWebViewConfiguration()
    configuration.setURLSchemeHandler(LocalImageSchemeHandler(directory: directory), forURLScheme: LocalImageResource.scheme)
    let webView = WKWebView(frame: .init(x: 0, y: 0, width: 100, height: 100), configuration: configuration)
    webView.loadHTMLString("<img src=\"\(resourceURL.absoluteString)\">", baseURL: directory)
    var width = 0
    for _ in 0..<50 {
        try await Task.sleep(for: .milliseconds(100))
        width = (try? await webView.evaluateJavaScript("document.images[0]?.naturalWidth") as? Int) ?? 0
        if width > 0 { break }
    }
    #expect(width == 1)
}

@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["KEEN_WEBKIT_INTEGRATION"] == "1"))
func webViewLoadsRemoteImage() async throws {
    let remoteURL = "https://oss-kelvinvan.oss-cn-chengdu.aliyuncs.com/img/image-20220802173323332.png"
    let document = MarkdownRenderer().render(source: "![远程图片](\(remoteURL))", baseURL: FileManager.default.temporaryDirectory)
    let webView = WKWebView(frame: .init(x: 0, y: 0, width: 100, height: 100))
    webView.loadHTMLString(document.html, baseURL: FileManager.default.temporaryDirectory)
    var width = 0
    for _ in 0..<100 {
        try await Task.sleep(for: .milliseconds(100))
        width = (try? await webView.evaluateJavaScript("document.images[0]?.naturalWidth") as? Int) ?? 0
        if width > 0 { break }
    }
    #expect(width > 0)
}

private final class LocalLinkMessageRecorder: NSObject, WKScriptMessageHandler {
    var message: [String: Any]?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.message = message.body as? [String: Any]
    }
}

@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["KEEN_WEBKIT_INTEGRATION"] == "1"))
func webViewPostsRelativeMarkdownLinkClick() async throws {
    let recorder = LocalLinkMessageRecorder()
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.add(recorder, name: "keen")
    let webView = WKWebView(frame: .init(x: 0, y: 0, width: 300, height: 200), configuration: configuration)
    let directory = FileManager.default.temporaryDirectory
    let destination = "../release/云表低代码平台快照迁移范围与冗余裁剪.md"
    let rendered = MarkdownRenderer().render(source: "[快照迁移](\(destination))", baseURL: directory)
    webView.loadHTMLString(rendered.html, baseURL: directory)
    var loadedHref: String?
    for _ in 0..<50 {
        loadedHref = try? await webView.evaluateJavaScript("document.querySelector('a')?.getAttribute('href')") as? String
        if loadedHref == destination { break }
        try await Task.sleep(for: .milliseconds(100))
    }
    #expect(loadedHref == destination)
    _ = try await webView.evaluateJavaScript("document.querySelector('a')?.click()")
    for _ in 0..<50 where recorder.message == nil {
        try await Task.sleep(for: .milliseconds(100))
    }
    #expect(recorder.message?["type"] as? String == "localLink")
    #expect(recorder.message?["href"] as? String == destination)
}

@Test func loadsMermaidOnlyWhenNeeded() {
    let plain = MarkdownRenderer().render(source: "```swift\nprint(1)\n```", baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(!plain.html.contains("globalThis[\"mermaid\"]"))
    #expect(!plain.html.contains("<section class=\"mermaid-shell\""))

    let diagram = MarkdownRenderer().render(source: "```mermaid\nflowchart TD\nA --> B\n```", baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(diagram.html.contains("globalThis[\"mermaid\"]"))
    #expect(diagram.html.contains("class=\"mermaid-shell\""))
    #expect(diagram.html.contains("securityLevel: 'strict'"))
    #expect(diagram.html.contains("keenMermaidZoom"))
    #expect(diagram.html.contains("svg.viewBox?.baseVal"))
    #expect(diagram.html.contains("Math.min(1, (viewport.clientWidth - 8) / naturalWidth)"))
    #expect(diagram.html.contains("(viewport.clientWidth - scaledWidth) / 2"))
    #expect(diagram.html.contains("nodeSpacing: 28"))
    #expect(diagram.html.contains("rankSpacing: 34"))
    #expect(diagram.html.contains("layout: 'elk'"))
    #expect(diagram.html.contains("curve: 'rounded'"))
    #expect(diagram.html.contains(".mermaid .node rect { rx:12px; ry:12px; }"))
    #expect(diagram.html.contains("svg.style.width = `${width}px`"))
    #expect(!diagram.html.contains("scale(${stage.dataset.scale"))
}

@Test func fitsAllMermaidDiagramsInOneDocument() {
    let source = """
    ```mermaid
    flowchart TD
    A --> B
    ```

    ```mermaid
    flowchart LR
    C --> D
    ```
    """
    let html = MarkdownRenderer().render(source: source, baseURL: URL(fileURLWithPath: "/tmp/docs")).html
    #expect(html.components(separatedBy: "class=\"mermaid-shell\"").count == 3)
    #expect(html.contains("window.keenMermaidFit = () => shells.forEach(fit)"))
    #expect(html.components(separatedBy: "onclick=\"keenMermaidFit()\"").count == 3)
}

@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["KEEN_WEBKIT_INTEGRATION"] == "1"))
func webViewFitsMermaidWithoutScalingTheWholeStage() async throws {
    let source = """
    ```mermaid
    flowchart TD
    A["基础数据已导入"] --> B["生产主档已入库"]
    A --> C["组织已建档"]
    B --> D["标准产能已试迁"]
    B --> E["手工任务已试迁"]
    C --> F["人员映射与任职"]
    D --> G["历史审批与在途处置"]
    E --> G
    F --> G
    ```
    """
    let document = MarkdownRenderer().render(source: source, baseURL: FileManager.default.temporaryDirectory)
    let webView = WKWebView(frame: .init(x: 0, y: 0, width: 640, height: 600))
    webView.loadHTMLString(document.html, baseURL: FileManager.default.temporaryDirectory)

    var measurements: [String: Any]?
    for _ in 0..<100 {
        measurements = try? await webView.evaluateJavaScript("""
        (() => {
          const stage = document.querySelector('.mermaid-stage');
          const svg = stage?.querySelector('svg');
          if (!svg) return null;
          if (!stage.dataset.naturalWidth) window.keenMermaidFit();
          return {
            naturalWidth: Number(stage.dataset.naturalWidth),
            scale: Number(stage.dataset.scale),
            svgWidth: svg.getBoundingClientRect().width,
            stageWidth: stage.getBoundingClientRect().width,
            transform: getComputedStyle(stage).transform,
            viewportWidth: document.querySelector('.mermaid-viewport').clientWidth
          };
        })()
        """) as? [String: Any]
        if measurements != nil { break }
        try await Task.sleep(for: .milliseconds(100))
    }
    let result = try #require(measurements)
    let naturalWidth = try #require(result["naturalWidth"] as? Double)
    let scale = try #require(result["scale"] as? Double)
    let svgWidth = try #require(result["svgWidth"] as? Double)
    let stageWidth = try #require(result["stageWidth"] as? Double)
    let viewportWidth = try #require(result["viewportWidth"] as? Int)
    #expect(naturalWidth > 0)
    #expect(scale > 0 && scale <= 1)
    #expect(abs(svgWidth - naturalWidth * scale) < 2)
    #expect(abs(stageWidth - svgWidth) < 2)
    #expect(svgWidth <= Double(viewportWidth))
    #expect((result["transform"] as? String)?.hasPrefix("matrix(1, 0, 0, 1,") == true)
}

@Test func resolvesMarkdownLinksAndAnchors() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let chinese = root.appendingPathComponent("标准产能汇报表人工复测手册.md")
    try Data("# 复测手册".utf8).write(to: chinese)
    let encoded = URL(string: chinese.absoluteString + "#移动端复测")!
    let target = try #require(DocumentLinkResolver.resolve(encoded))
    #expect(target.fileURL == chinese)
    #expect(target.headingID == "移动端复测")

    let percent = URL(string: chinese.absoluteString + "#50%25%20%E5%AE%8C%E6%88%90")!
    #expect(DocumentLinkResolver.resolve(percent)?.headingID == "50% 完成")

    let extensionless = root.appendingPathComponent("标准产能汇报表人工复测手册")
    #expect(DocumentLinkResolver.resolve(extensionless)?.fileURL == chinese)
}

@Test func resolvesRelativeChineseMarkdownLinks() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceDirectory = root.appendingPathComponent("云表低代码平台数据与迁移", isDirectory: true)
    let targetDirectory = root.appendingPathComponent("release", isDirectory: true)
    let bracketDirectory = root.appendingPathComponent("[pe]模块-生产执行", isDirectory: true)
    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: bracketDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let source = sourceDirectory.appendingPathComponent("03-wjuat历史数据迁移方案.md")
    let target = targetDirectory.appendingPathComponent("云表低代码平台快照迁移范围与冗余裁剪.md")
    let bracketTarget = bracketDirectory.appendingPathComponent("03-决策记录.md")
    try Data("# 来源".utf8).write(to: source)
    try Data("# 目标".utf8).write(to: target)
    try Data("# 决策".utf8).write(to: bracketTarget)

    let destination = "../release/云表低代码平台快照迁移范围与冗余裁剪.md"
    #expect(DocumentLinkResolver.resolve(destination, relativeTo: source)?.fileURL == target)
    let rendered = MarkdownRenderer().render(source: "[快照迁移](\(destination))", baseURL: sourceDirectory)
    #expect(rendered.html.contains("href=\"\(destination)\""))
    #expect(rendered.html.contains("type:'localLink',href"))
    let bracketDestination = "../[pe]模块-生产执行/03-决策记录.md"
    #expect(DocumentLinkResolver.resolve(bracketDestination, relativeTo: source)?.fileURL == bracketTarget)
    let bracketRendered = MarkdownRenderer().render(source: "[决策记录](\(bracketDestination))", baseURL: sourceDirectory)
    #expect(bracketRendered.html.contains("href=\"\(bracketDestination)\""))
}

@Test func rendersInDocumentAnchorNavigation() {
    let source = """
    [跳转](#阅读体验)

    ## 阅读体验

    [返回](#阅读体验)
    """
    let result = MarkdownRenderer().render(source: source, baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(result.headings.first?.id == "阅读体验")
    #expect(result.html.contains("href=\"#阅读体验\""))
    #expect(result.html.contains("if(href.startsWith('#'))"))
    #expect(result.html.contains("target.scrollIntoView({behavior:'auto',block:'start'})"))
}


