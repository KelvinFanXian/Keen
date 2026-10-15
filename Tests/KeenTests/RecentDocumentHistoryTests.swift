import Foundation
import Testing
@testable import Keen

@Test func keepsTenMostRecentDocumentsAndPromotesReopenedFile() {
    var history = RecentDocumentHistory(limit: 10)
    for index in 0..<12 {
        history.record(URL(fileURLWithPath: "/docs/\(index).md"))
    }

    #expect(history.urls.count == 10)
    #expect(history.urls.first?.lastPathComponent == "11.md")
    #expect(history.urls.last?.lastPathComponent == "2.md")

    history.record(URL(fileURLWithPath: "/docs/5.md"))
    #expect(history.urls.first?.lastPathComponent == "5.md")
    #expect(history.urls.filter { $0.lastPathComponent == "5.md" }.count == 1)
}

@Test func isolatesRecentDocumentsByWorkspace() {
    let firstWorkspace = URL(fileURLWithPath: "/projects/first")
    let secondWorkspace = URL(fileURLWithPath: "/projects/second")
    let firstDocument = URL(fileURLWithPath: "/projects/first/README.md")
    let secondDocument = URL(fileURLWithPath: "/projects/second/README.md")
    var history = WorkspaceRecentDocumentHistory()

    history.record(firstDocument, in: firstWorkspace)
    history.record(secondDocument, in: secondWorkspace)

    #expect(history.documents(in: firstWorkspace) == [firstDocument])
    #expect(history.documents(in: secondWorkspace) == [secondDocument])
}
