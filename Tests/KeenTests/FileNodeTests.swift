import Foundation
import Testing
@testable import Keen

@Test func reloadsDirectoryChildrenAfterChanges() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("keen-file-node-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let first = root.appendingPathComponent("first.md")
    try Data("# First".utf8).write(to: first)
    let node = FileNode(url: root, isDirectory: true)
    #expect(node.loadChildren(showHidden: false).map(\.name) == ["first.md"])

    try FileManager.default.removeItem(at: first)
    let second = root.appendingPathComponent("second.md")
    try Data("# Second".utf8).write(to: second)
    #expect(node.reloadChildren(showHidden: false).map(\.name) == ["second.md"])
}

@Test func searchesMarkdownFilesByName() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("keen-file-search-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try Data("# Guide".utf8).write(to: root.appendingPathComponent("部署指南.md"))
    try Data("ignored".utf8).write(to: root.appendingPathComponent("部署日志.txt"))
    let nested = root.appendingPathComponent("bug-fix", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("# Checklist".utf8).write(to: nested.appendingPathComponent("缺陷清单.md"))
    let node = FileNode(url: root, isDirectory: true)

    #expect(node.searchMarkdownFiles(matching: "部署", showHidden: false).map(\.name) == ["部署指南.md"])
    #expect(node.searchMarkdownFiles(matching: "bug-fix", showHidden: false).map(\.name) == ["缺陷清单.md"])
}

@Test func searchesWorkspaceMarkdownContentsAndRelativePaths() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("keen-text-search-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let nested = root.appendingPathComponent("review-notes", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try "# 清单\n已记录 D-05，需要复测。\n".write(
        to: nested.appendingPathComponent("缺陷.md"), atomically: true, encoding: .utf8
    )
    try "# 无关内容\n".write(
        to: root.appendingPathComponent("D-05-标题.md"), atomically: true, encoding: .utf8
    )
    try "D-05 不应搜索非 Markdown 文件".write(
        to: root.appendingPathComponent("日志.txt"), atomically: true, encoding: .utf8
    )

    let contentHits = WorkspaceTextSearch.search(rootURL: root, query: "d-05", showHidden: false)
    #expect(contentHits.map(\.url.lastPathComponent) == ["缺陷.md", "D-05-标题.md"])
    #expect(contentHits.first?.lineNumber == 2)
    #expect(contentHits.first?.excerpt?.contains("复测") == true)

    let pathHits = WorkspaceTextSearch.search(rootURL: root, query: "review-notes", showHidden: false)
    #expect(pathHits.map(\.url.lastPathComponent) == ["缺陷.md"])
    #expect(pathHits.first?.lineNumber == nil)
}

@Test func detectsFilesInsideDirectoryWithoutMatchingSiblingPrefixes() {
    let node = FileNode(url: URL(fileURLWithPath: "/docs/project"), isDirectory: true)

    #expect(node.contains(URL(fileURLWithPath: "/docs/project/spec/guide.md")))
    #expect(!node.contains(URL(fileURLWithPath: "/docs/project-copy/guide.md")))
    #expect(!node.contains(URL(fileURLWithPath: "/docs/project")))
}
