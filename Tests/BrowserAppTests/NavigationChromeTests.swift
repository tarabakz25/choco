import CoreGraphics
import Testing
@testable import BrowserApp

@Suite struct NavigationChromeTests {
    @Test func inFlightURLReplacesThePreviousPage() {
        let shown = NavigationBarAddress.pageURL(
            provisional: "https://example.com/next",
            committed: "https://example.com/prev",
            stored: "https://example.com/prev"
        )
        #expect(shown == "https://example.com/next")
    }

    @Test func blankDocumentDoesNotHideAKnownPage() {
        #expect(NavigationBarAddress.pageURL(provisional: nil, committed: "about:blank", stored: "https://example.com/docs") == "https://example.com/docs")
        #expect(NavigationBarAddress.pageURL(provisional: nil, committed: nil, stored: "https://example.com/docs") == "https://example.com/docs")
        #expect(NavigationBarAddress.pageURL(provisional: "about:blank", committed: "about:blank", stored: "  https://example.com/docs  ") == "https://example.com/docs")
    }

    @Test func inFlightURLSurvivesAnIntermediateBlankCommit() {
        let shown = NavigationBarAddress.pageURL(
            provisional: "https://example.com/next",
            committed: "about:blank",
            stored: "https://example.com/prev"
        )
        #expect(shown == "https://example.com/next")
    }

    @Test func anEmptyTabStaysEmpty() {
        #expect(NavigationBarAddress.pageURL(provisional: nil, committed: "about:blank", stored: "about:blank") == nil)
        #expect(NavigationBarAddress.pageURL(provisional: "javascript:alert(1)", committed: nil, stored: "file:///tmp/x") == nil)
        #expect(NavigationBarAddress.pageURL(provisional: "http://", committed: nil, stored: nil) == nil)
    }

    @Test func labelIsHostAndPath() {
        #expect(NavigationBarAddress.label(for: "https://example.com/") == "example.com")
        #expect(NavigationBarAddress.label(for: "https://example.com/a/b") == "example.com/a/b")
        #expect(NavigationBarAddress.label(for: "https://example.com/a?q=1#here") == "example.com/a")
        #expect(NavigationBarAddress.label(for: "not a url") == "not a url")
    }

    @Test func navigationButtonsDoNotSlideWhenTheSidebarWidens() {
        func points(_ width: CGFloat) -> [Int] {
            NavigationChromeLayout.controlOrigins(sidebarWidth: width).map { Int($0.rounded()) }
        }
        let narrow = points(ChocoTheme.sidebarWidth)
        let wide = points(ChocoTheme.sidebarMaxWidth)
        let button = Int(ChocoSpace.u(28).rounded())
        // Toggle, back, forward, reload. The first sits just past the traffic lights (76pt).
        // Compare the whole list: a `#expect` that subscripts the array reported equal points as
        // unequal, then trapped with "Index out of range" and aborted the suite.
        let expected = (0..<4).map { Int(NavigationChromeLayout.trafficLightClearance.rounded()) + $0 * button }
        #expect(narrow == expected)
        #expect(wide == expected)
        let reloadEnd = (narrow.last ?? 0) + button
        #expect(reloadEnd <= Int(ChocoTheme.sidebarWidth.rounded()) - Int(ChocoSpace.u(8).rounded()))
    }
}

@Suite struct CommandSelectionTests {
    @Test func arrivingSuggestionsKeepTheHighlightedRow() {
        let rows = ["navigate", "suggestion-swift", "cmd-archive", "cmd-sidebar", "cmd-clear"]
        let index = CommandSelection.highlightedIndex(currentID: "cmd-archive", rowIDs: rows, preferredIndex: 0)
        #expect(index == 2)
        #expect(rows[index] == "cmd-archive")
    }

    @Test func aRowThatDisappearsFallsBackToThePreferredOne() {
        let rows = ["navigate", "cmd-archive"]
        #expect(CommandSelection.highlightedIndex(currentID: "suggestion-old", rowIDs: rows, preferredIndex: 0) == 0)
    }

    @Test func aNewQueryAdoptsThePreferredRow() {
        let rows = ["tab-1", "navigate", "cmd-archive"]
        #expect(CommandSelection.preferred(rows, preferredIndex: 1) == "navigate")
    }

    @Test func arrowKeysFollowTheRowAfterSuggestionsInsert() {
        let rows = ["navigate", "suggestion-swift", "cmd-archive"]
        #expect(CommandSelection.move("cmd-archive", rowIDs: rows, preferredIndex: 0, by: -1) == "suggestion-swift")
        #expect(CommandSelection.move("navigate", rowIDs: rows, preferredIndex: 0, by: -1) == "navigate")
        #expect(CommandSelection.move("cmd-archive", rowIDs: rows, preferredIndex: 0, by: 1) == "cmd-archive")
    }
}
