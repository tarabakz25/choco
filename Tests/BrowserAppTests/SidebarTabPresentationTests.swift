@testable import BrowserApp
import BrowserCore
import Foundation
import Testing

@Suite(.serialized) @MainActor struct SidebarTabPresentationTests {
    @Test func closingKeepsOnlyVisualSnapshotThenRetiresWithoutTouchingSource() async throws {
        let space = UUID()
        let first = BrowserTab(spaceID: space, url: "https://example.invalid/first")
        let second = BrowserTab(spaceID: space, url: "https://example.invalid/second")
        let third = BrowserTab(spaceID: space, url: "https://example.invalid/third")
        let presenter = SidebarTabPresentation(tabs: [first, second, third])
        defer { presenter.cancelPending() }
        presenter.update(tabs: [first, third], reducedMotion: false)
        #expect(presenter.rows.map(\.id) == [first.id, second.id, third.id])
        let outgoing = try #require(presenter.rows.first { $0.id == second.id })
        #expect(outgoing.isRetiring && outgoing.progress == 0)
        try await Task.sleep(for: .milliseconds(250))
        #expect(presenter.rows.map(\.id) == [first.id, third.id])
    }

    @Test func restoringDuringExitCancelsOldRetirementAndAvoidsDuplicates() async throws {
        let tab = BrowserTab(spaceID: UUID(), url: "https://example.invalid/restore")
        let presenter = SidebarTabPresentation(tabs: [tab])
        defer { presenter.cancelPending() }
        presenter.update(tabs: [], reducedMotion: false)
        presenter.update(tabs: [tab], reducedMotion: false)
        try await Task.sleep(for: .milliseconds(250))
        #expect(presenter.rows.count == 1)
        #expect(presenter.rows.first?.id == tab.id)
        #expect(presenter.rows.first?.isRetiring == false)
        #expect(presenter.rows.first?.progress == 1)
    }

    @Test func reducedMotionAndMetadataUpdatesDoNotCreateExitSnapshots() {
        var tab = BrowserTab(spaceID: UUID(), url: "https://example.invalid/page")
        let presenter = SidebarTabPresentation(tabs: [tab])
        defer { presenter.cancelPending() }
        tab.customTitle = "Updated"
        tab.spaceID = UUID()
        presenter.update(tabs: [tab], reducedMotion: false)
        #expect(presenter.rows.first?.tab.customTitle == "Updated")
        #expect(presenter.rows.first?.tab.spaceID == tab.spaceID)
        #expect(presenter.rows.first?.progress == 1)
        presenter.update(tabs: [], reducedMotion: true)
        #expect(presenter.rows.isEmpty)
    }
}
