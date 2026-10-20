import Foundation
import Testing
@testable import Keen

@Test func commandURLResolvesExistingUnicodeDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("keen 命令测试 \(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    var components = URLComponents()
    components.scheme = "keen"
    components.host = "open"
    components.queryItems = [URLQueryItem(name: "path", value: root.path)]

    #expect(KeenLaunchURL.directory(from: try #require(components.url)) == root.standardizedFileURL)
}

@Test func commandURLRejectsMissingOrNonDirectoryTargets() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("keen-command-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("note.md")
    try "# Note".write(to: file, atomically: true, encoding: .utf8)

    for path in [file.path, root.appendingPathComponent("missing").path] {
        var components = URLComponents()
        components.scheme = "keen"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        #expect(KeenLaunchURL.directory(from: try #require(components.url)) == nil)
    }
}
