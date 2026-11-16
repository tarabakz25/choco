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
        let narrow = NavigationChromeLayout.controlOrigins(sidebarWidth: ChocoTheme.sidebarWidth)
        let wide = NavigationChromeLayout.controlOrigins(sidebarWidth: ChocoTheme.sidebarMaxWidth)
        #expect(narrow == wide)
        #expect(narrow.count == 4)
        #expect(narrow[0] >= NavigationChromeLayout.trafficLightClearance)
        let button = ChocoSpace.u(28)
        #expect(narrow[3] + button <= ChocoTheme.sidebarWidth - ChocoSpace.u(8))
        #expect(narrow[1] == narrow[0] + button)
        #expect(narrow[2] == narrow[1] + button)
        #expect(narrow[3] == narrow[2] + button)
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
