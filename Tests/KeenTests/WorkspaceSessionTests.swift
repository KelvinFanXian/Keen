import Foundation
import Testing
@testable import Keen

@Test func workspaceTabSessionsRoundTripWithoutMixingProjects() throws {
    let sessions = [
        "/projects/first": WorkspaceTabSession(openTabPaths: ["/projects/first/a.md"], selectedPath: "/projects/first/a.md"),
        "/projects/second": WorkspaceTabSession(openTabPaths: ["/projects/second/b.md"], selectedPath: "/projects/second/b.md")
    ]

    let data = try JSONEncoder().encode(sessions)
    let restored = try JSONDecoder().decode([String: WorkspaceTabSession].self, from: data)
    #expect(restored == sessions)
}

@Test func recentWorkspacesAreDeduplicatedAndLimited() {
    var history = RecentWorkspaceHistory(limit: 3)
    history.record(URL(fileURLWithPath: "/projects/one"))
    history.record(URL(fileURLWithPath: "/projects/two"))
    history.record(URL(fileURLWithPath: "/projects/three"))
    history.record(URL(fileURLWithPath: "/projects/four"))
    history.record(URL(fileURLWithPath: "/projects/two"))

    #expect(history.urls.map(\.lastPathComponent) == ["two", "four", "three"])
}

@Test func pinnedWorkspaceStaysFirstAndCanBeRemoved() {
    let first = URL(fileURLWithPath: "/projects/one")
    let second = URL(fileURLWithPath: "/projects/two")
    var history = RecentWorkspaceHistory(urls: [first, second], limit: 2)

    history.togglePinned(second)
    history.record(first)
    #expect(history.urls == [second, first])
    #expect(history.isPinned(second))

    history.remove(second)
    #expect(history.urls == [first])
    #expect(!history.isPinned(second))
}
