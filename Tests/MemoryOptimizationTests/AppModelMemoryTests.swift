import BrowserCore
import Foundation
import Testing
@testable import BrowserApp

@Suite("Memory optimization app model", .serialized)
@MainActor
struct AppModelMemoryTests {
    @Test func switchingAwayRestartsTheIdleClock() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let current = try #require(model.state.selectedTabID)
        model.send(.newTab(url: "https://example.com/background"))
        let background = try #require(model.state.selectedTabID)
        model.noteInteraction(background, at: Date().addingTimeInterval(-3600))
        model.send(.selectTab(current))
        let snapshots = model.memorySnapshots(now: Date(), liveIDs: [background])
        let stamp = try #require(snapshots.first { $0.id == background }?.lastInteraction)
        #expect(Date().timeIntervalSince(stamp) < 30)
        let plan = TabHibernationPlanner.plan(
            tabs: snapshots,
            now: Date(),
            budget: HibernationBudget(idleInterval: 60, maxLiveWebViews: 6),
            pressure: .normal
        )
        #expect(!plan.hibernateIDs.contains(background))
        #expect(model.pool.residentIDs.isEmpty)
    }

    @Test func idleBackgroundTabIsMarkedHibernatedWithoutCreatingAWebView() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let current = try #require(model.state.selectedTabID)
        model.send(.newTab(url: "https://example.com/background"))
        let background = try #require(model.state.selectedTabID)
        model.send(.selectTab(current))
        let now = Date()
        model.noteInteraction(background, at: now.addingTimeInterval(-3600))
        let snapshots = model.memorySnapshots(now: now, liveIDs: [current, background])
        let plan = TabHibernationPlanner.plan(tabs: snapshots, now: now, budget: .standard, pressure: .normal)
        #expect(plan.hibernateIDs == [background])
        model.applyHibernationPlan(plan)
        #expect(model.hibernatedTabIDs == [background])
        model.applyHibernationPlan(HibernationPlan(hibernateIDs: [], wakeIDs: [background]))
        #expect(model.hibernatedTabIDs.isEmpty)
        #expect(model.pool.residentIDs.isEmpty)
        #expect(model.pool.existing(id: background) == nil)
    }

    @Test func appModelRefusesPinnedVisibleAudioAndFormEvenIfThePlanSaysHibernate() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let visible = try #require(model.state.selectedTabID)
        model.send(.newTab(url: "https://example.com/pinned"))
        let pinned = try #require(model.state.selectedTabID)
        model.send(.pinTab(pinned))
        model.send(.newTab(url: "https://example.com/audio"))
        let audio = try #require(model.state.selectedTabID)
        model.noteActivity(audio, isPlayingAudio: true, hasUnsavedFormInput: false)
        model.send(.newTab(url: "https://example.com/form"))
        let form = try #require(model.state.selectedTabID)
        model.noteActivity(form, isPlayingAudio: false, hasUnsavedFormInput: true)
        model.send(.selectTab(visible))
        model.applyHibernationPlan(HibernationPlan(hibernateIDs: [visible, pinned, audio, form], wakeIDs: []))
        #expect(model.hibernatedTabIDs.isEmpty)
        #expect(model.pool.residentIDs.isEmpty)
    }

    @Test func splitPanesAreBothVisibleToThePlanner() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try #require(model.state.tabs.first?.id)
        model.send(.newTab(url: "about:blank"))
        let second = try #require(model.state.selectedTabID)
        model.send(.setSplit(leading: first, trailing: second))
        let snapshots = model.memorySnapshots(now: Date(), liveIDs: [first, second])
        #expect(snapshots.first { $0.id == first }?.isVisible == true)
        #expect(snapshots.first { $0.id == second }?.isVisible == true)
        let plan = TabHibernationPlanner.plan(
            tabs: snapshots,
            now: Date(),
            budget: HibernationBudget(idleInterval: 1, maxLiveWebViews: 1),
            pressure: .critical
        )
        #expect(plan.hibernateIDs.isEmpty)
    }

    @Test func unselectedFavoriteUsesTheSameHibernationRules() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let tab = try #require(model.state.selectedTabID)
        model.send(.createFavorite(title: "Pinned link", url: "https://example.com/fav"))
        let favorite = try #require(model.state.favorites.first)
        model.send(.selectFavorite(favorite.id))
        let runtimeID = model.favoriteRuntimeID(for: favorite)
        let selected = model.memorySnapshots(now: Date(), liveIDs: [runtimeID])
        #expect(selected.first { $0.id == runtimeID }?.isVisible == true)
        #expect(selected.first { $0.id == runtimeID }?.isPinned == false)
        #expect(selected.first { $0.id == tab }?.isVisible == false)

        model.send(.selectTab(tab))
        let now = Date()
        model.noteInteraction(runtimeID, at: now.addingTimeInterval(-3600))
        let hidden = model.memorySnapshots(now: now, liveIDs: [runtimeID])
        let plan = TabHibernationPlanner.plan(tabs: hidden, now: now, budget: .standard, pressure: .normal)
        #expect(plan.hibernateIDs == [runtimeID])
        model.applyHibernationPlan(plan)
        #expect(model.hibernatedFavoriteSessionIDs.contains(runtimeID))
        #expect(!model.hibernatedTabIDs.contains(runtimeID))
        #expect(model.pool.existing(id: runtimeID) == nil)
    }

    @Test func applyingAPlanTrimsScrollAnchorsToTheBudget() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let limit = ScrollAnchorBudget.defaultMaxCount
        let now = Date()
        var oldest: UUID?
        var newest: UUID?
        for offset in 0..<(limit + 5) {
            let id = UUID()
            if offset == 0 { oldest = id }
            if offset == limit + 4 { newest = id }
            model.noteScroll(id, x: 0, y: Double(offset), at: now.addingTimeInterval(TimeInterval(offset)))
        }
        model.applyHibernationPlan(HibernationPlan(hibernateIDs: [], wakeIDs: []))
        let oldestID = try #require(oldest)
        let newestID = try #require(newest)
        #expect(model.scrollAnchors.count == limit)
        #expect(model.scrollAnchors[oldestID] == nil)
        #expect(model.scrollAnchors[newestID]?.y == Double(limit + 4))
    }

    private func makeModel() throws -> (AppModel, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("choco-memory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (AppModel(directory: directory), directory)
    }
}
