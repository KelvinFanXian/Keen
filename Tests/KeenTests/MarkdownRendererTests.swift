import Foundation
import Testing
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

@Test func includesMarkedInspiredReadingStyles() {
    let result = MarkdownRenderer().render(source: "# 阅读", baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(result.html.contains("data-style='ink'"))
    #expect(result.html.contains("data-style='manuscript'"))
    #expect(result.html.contains("data-style='everforest-light'"))
    #expect(result.html.contains("--bg:#fdf6e3"))
    #expect(result.html.contains("window.keenConfigure=(theme,style,size,width)"))
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

@Test func blocksRemoteAndTraversingImages() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let images = directory.appendingPathComponent("images", isDirectory: true)
    try? FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try? Data([0x89, 0x50, 0x4e, 0x47]).write(to: images.appendingPathComponent("diagram.png"))
    let source = """
    ![remote](https://example.com/a.png)
    ![traverse](../secret.png)
    ![local](images/diagram.png)
    """
    let result = MarkdownRenderer().render(source: source, baseURL: directory)
    #expect(!result.html.contains("src=\"https://example.com"))
    #expect(!result.html.contains("src=\"../secret.png"))
    #expect(result.html.contains("src=\"keen-local-image:"))
    #expect(result.html.contains("images/diagram.png"))
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

@Test func rendersInDocumentAnchorNavigation() {
    let source = """
    [跳转](#阅读体验)

    ## 阅读体验

    [返回](#阅读体验)
    """
    let result = MarkdownRenderer().render(source: source, baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(result.headings.first?.id == "阅读体验")
    #expect(result.html.contains("href=\"#阅读体验\""))
    #expect(result.html.contains("href?.startsWith('#')"))
    #expect(result.html.contains("target.scrollIntoView({behavior:'auto',block:'start'})"))
}


