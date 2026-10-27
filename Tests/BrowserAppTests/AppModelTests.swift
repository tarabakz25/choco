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

@Suite struct SpaceSwipeRecognizerTests {
    private let travel: CGFloat = 184

    @Test func sidewaysMovementLocksAndTracksTheFingers() {
        var recognizer = SpaceSwipeRecognizer()
        recognizer.add(dx: -2, dy: 0.5)
        #expect(!recognizer.isHorizontal)
        recognizer.add(dx: -10, dy: 1)
        #expect(recognizer.isHorizontal)
        recognizer.add(dx: -30, dy: 2)
        #expect(recognizer.offset == -42)
    }

    @Test func verticalMovementNeverLocksAndStaysVertical() {
        var recognizer = SpaceSwipeRecognizer()
        recognizer.add(dx: 1, dy: 10)
        recognizer.add(dx: -60, dy: 2)
        #expect(recognizer.isVertical && !recognizer.isHorizontal)
        recognizer.reset()
        #expect(recognizer.offset == 0)
    }

    @Test func verticalDriftDuringASidewaysSwipeIsIgnored() {
        var recognizer = SpaceSwipeRecognizer()
        recognizer.add(dx: -12, dy: 1)
        recognizer.add(dx: -4, dy: 90)
        #expect(recognizer.isHorizontal)
        #expect(recognizer.offset == -16)
    }

    @Test func listsNeverMoveFasterThanTheSpeedLimit() {
        let frame = 1.0 / 60
        let step = SpaceSwipeRecognizer.maxSpeed * CGFloat(frame)
        // A hard flick puts the fingers 500pt away in one frame; the lists get there one capped step at a time.
        var shown: CGFloat = 0
        shown = SpaceSwipeRecognizer.follow(shown: shown, target: -500, elapsed: frame)
        #expect(shown == -step)
        for _ in 0..<20 { shown = SpaceSwipeRecognizer.follow(shown: shown, target: -500, elapsed: frame) }
        #expect(shown == -500, "and they do arrive")
        // A short way is covered in one step without overshooting, either direction.
        #expect(SpaceSwipeRecognizer.follow(shown: 0, target: 10, elapsed: frame) == 10)
        #expect(SpaceSwipeRecognizer.follow(shown: 100, target: 60, elapsed: frame) == 60)
        #expect(SpaceSwipeRecognizer.follow(shown: 0, target: 500, elapsed: frame) == step)
    }

    @Test func releaseCommitsPastAThirdOrOnAFlick() {
        #expect(SpaceSwipeRecognizer.commits(offset: -80, velocity: 0, travel: travel))
        #expect(!SpaceSwipeRecognizer.commits(offset: -40, velocity: 0, travel: travel))
        #expect(SpaceSwipeRecognizer.commits(offset: -20, velocity: -12, travel: travel))
        #expect(!SpaceSwipeRecognizer.commits(offset: -20, velocity: 12, travel: travel), "a flick back the other way cancels")
        #expect(!SpaceSwipeRecognizer.commits(offset: -5, velocity: -12, travel: travel), "too small to be a switch")
    }

    @Test func pausingBeforeReleaseBleedsOffTheFlickSpeed() {
        var recognizer = SpaceSwipeRecognizer()
        recognizer.add(dx: -20, dy: 0)
        recognizer.add(dx: -20, dy: 0)
        let moving = abs(recognizer.velocity)
        for _ in 0..<4 { recognizer.add(dx: 0, dy: 0) }
        #expect(abs(recognizer.velocity) < moving / 8)
    }

    @Test func rubberBandResistsAndIsBounded() {
        let small = SpaceSwipeRecognizer.rubberBand(-40, travel: travel)
        let large = SpaceSwipeRecognizer.rubberBand(-4000, travel: travel)
        #expect(small < 0 && small > -40)
        #expect(large >= -travel * 0.25 - 0.001)
        #expect(SpaceSwipeRecognizer.rubberBand(40, travel: travel) == -small)
    }
}
