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
    let node = FileNode(url: root, isDirectory: true)

    #expect(node.searchMarkdownFiles(matching: "部署", showHidden: false).map(\.name) == ["部署指南.md"])
}

@Test func detectsFilesInsideDirectoryWithoutMatchingSiblingPrefixes() {
    let node = FileNode(url: URL(fileURLWithPath: "/docs/project"), isDirectory: true)

    #expect(node.contains(URL(fileURLWithPath: "/docs/project/spec/guide.md")))
    #expect(!node.contains(URL(fileURLWithPath: "/docs/project-copy/guide.md")))
    #expect(!node.contains(URL(fileURLWithPath: "/docs/project")))
}
