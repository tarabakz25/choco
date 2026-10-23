@testable import BrowserApp
import BrowserCore
import Foundation
import Testing
import WebKit

@Suite(.serialized) @MainActor struct AppModelTests {
    private func makeModel() -> (AppModel, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ossarc-model-\(UUID())")
        return (AppModel(directory: directory), directory)
    }

    @Test func splitFocusPersistsAndIgnoresHiddenTabs() async throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try #require(model.state.tabs.first?.id)
        model.send(.newTab(url: "about:blank"))
        let second = try #require(model.state.selectedTabID)
        model.send(.newTab(url: "about:blank"))
        let hidden = try #require(model.state.selectedTabID)
        model.send(.setSplit(leading: first, trailing: second))
        model.focusTab(second)
        #expect(model.navigationTabID == second)
        #expect(model.state.selectedTabID == second)
        #expect(model.state.split != nil)
        model.focusedPaneID = hidden
        #expect(model.navigationTabID == second)
        await model.store.flush()
        let restored = AppModel(directory: directory)
        #expect(restored.navigationTabID == second)
        #expect(restored.state.split == model.state.split)
    }

    @Test func controlTabUsesFrozenRecentOrder() async throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try #require(model.state.tabs.first?.id)
        model.send(.newTab(url: "about:blank"))
        let second = try #require(model.state.selectedTabID)
        model.send(.newTab(url: "about:blank"))
        let third = try #require(model.state.selectedTabID)
        model.send(.selectTab(first))
        #expect(model.recentTabIDs == [first, third, second])
        model.cycleTabs(backwards: false)
        #expect(model.state.selectedTabID == third)
        model.cycleTabs(backwards: false)
        #expect(model.state.selectedTabID == second)
        model.finishTabCycle()
        #expect(model.recentTabIDs == [second, first, third])
        model.cycleTabs(backwards: false)
        #expect(model.state.selectedTabID == first)
        model.finishTabCycle()
        await model.store.flush()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["OSS_ARC_WEBKIT_TESTS"] == "1"))
    func staleFavoritePopupCannotCrossProfiles() async throws {
        let (model, directory) = makeModel()
        defer { model.pool.retainOnly([]); try? FileManager.default.removeItem(at: directory) }
        model.send(.createFavorite(title: "Fixture", url: "about:blank"))
        let favorite = try #require(model.state.favorites.first)
        model.send(.selectFavorite(favorite.id))
        let original = model.session(for: favorite)
        let configuration = original.webView.configuration
        let space = try #require(model.selectedSpace)
        model.send(.createProfile(name: "Other"))
        let other = try #require(model.state.profiles.last)
        model.send(.updateSpace(space.id, name: space.name, icon: space.icon, colorHex: space.colorHex, profileID: other.id))
        let count = model.state.tabs.count
        let result = original.onOpenWindow?(configuration, URL(string: "about:blank"))
        #expect(result == nil)
        #expect(model.state.tabs.count == count)
        #expect(model.state.selectedProfile?.id == other.id)
        await model.store.flush()
    }
}
