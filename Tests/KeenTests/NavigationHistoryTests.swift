import Foundation
import Testing
@testable import Keen

@Test func navigatesBackwardAndForwardThroughLinkedDocuments() {
    let first = NavigationLocation(url: URL(fileURLWithPath: "/docs/first.md"), headingID: "intro", scrollY: 1840)
    let second = NavigationLocation(url: URL(fileURLWithPath: "/docs/second.md"), headingID: nil, scrollY: 260)
    let third = NavigationLocation(url: URL(fileURLWithPath: "/docs/third.md"), headingID: "result", scrollY: 930)
    var history = NavigationHistory()

    history.recordVisit(from: first)
    history.recordVisit(from: second)
    #expect(history.goBack(from: third) == second)
    #expect(history.goBack(from: second) == first)
    #expect(history.goForward(from: first) == second)
    #expect(history.goForward(from: second) == third)
    #expect(!history.canGoForward)
}
