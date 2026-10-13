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
    #expect(result.html.contains("<table>"))
    #expect(result.html.contains("<ul class=\"task-list\">"))
    #expect(result.html.contains("type=\"checkbox\" checked"))
}

@Test func blocksRemoteAndTraversingImages() {
    let source = """
    ![remote](https://example.com/a.png)
    ![traverse](../secret.png)
    ![local](images/diagram.png)
    """
    let result = MarkdownRenderer().render(source: source, baseURL: URL(fileURLWithPath: "/tmp/docs"))
    #expect(!result.html.contains("src=\"https://example.com"))
    #expect(!result.html.contains("src=\"../secret.png"))
    #expect(result.html.contains("src=\"images/diagram.png\""))
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

    let extensionless = root.appendingPathComponent("标准产能汇报表人工复测手册")
    #expect(DocumentLinkResolver.resolve(extensionless)?.fileURL == chinese)
}


