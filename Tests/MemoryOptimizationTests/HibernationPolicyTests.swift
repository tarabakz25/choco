import Foundation
import Testing
@testable import BrowserCore
@testable import BrowserRuntime

@Suite("Memory optimization policy")
struct HibernationPolicyTests {
    enum HibernationProtection: String, CaseIterable, Sendable {
        case pinned, audio, downloading, form, visible
    }

    @Test func standardBudgetKeepsASmallWorkingSet() {
        #expect(HibernationBudget.standard.idleInterval == 5 * 60)
        #expect(HibernationBudget.standard.maxLiveWebViews == 6)
        #expect(ScrollAnchorBudget.defaultMaxCount == 40)
    }

    @Test func idleUnprotectedTabIsHibernated() {
        let now = Date()
        let id = UUID()
        let plan = TabHibernationPlanner.plan(
            tabs: [snapshot(id: id, now: now, age: 400)],
            now: now,
            budget: .standard,
            pressure: .normal
        )
        #expect(plan.hibernateIDs == [id])
        #expect(plan.wakeIDs.isEmpty)
    }

    @Test func recentlyUsedTabStaysResident() {
        let now = Date()
        let plan = TabHibernationPlanner.plan(
            tabs: [snapshot(now: now, age: 10)],
            now: now,
            budget: .standard,
            pressure: .normal
        )
        #expect(plan.hibernateIDs.isEmpty)
        #expect(plan.wakeIDs.isEmpty)
    }

    @Test func idleBoundaryIsInclusive() {
        let now = Date()
        let idle = snapshot(now: now, age: 60)
        let fresh = snapshot(now: now, age: 59)
        let plan = TabHibernationPlanner.plan(
            tabs: [fresh, idle],
            now: now,
            budget: HibernationBudget(idleInterval: 60, maxLiveWebViews: 10),
            pressure: .normal
        )
        #expect(plan.hibernateIDs == [idle.id])
    }

    @Test(arguments: HibernationProtection.allCases)
    func protectedTabStaysResidentUnderCriticalPressure(_ protection: HibernationProtection) {
        let now = Date()
        var tab = snapshot(now: now, age: 10_000)
        switch protection {
        case .pinned: tab.isPinned = true
        case .audio: tab.isPlayingAudio = true
        case .downloading: tab.isDownloading = true
        case .form: tab.hasUnsavedFormInput = true
        case .visible: tab.isVisible = true
        }
        let plan = TabHibernationPlanner.plan(
            tabs: [tab],
            now: now,
            budget: HibernationBudget(idleInterval: 30, maxLiveWebViews: 1),
            pressure: .critical
        )
        #expect(plan.hibernateIDs.isEmpty)
    }

    @Test func criticalPressureDiscardsEligibleTabsOldestFirst() {
        let now = Date()
        let visible = snapshot(now: now, age: 9, visible: true)
        let pinned = snapshot(now: now, age: 8, pinned: true)
        let audio = snapshot(now: now, age: 7, audio: true)
        let downloading = snapshot(now: now, age: 6, downloading: true)
        let form = snapshot(now: now, age: 5, form: true)
        let oldest = snapshot(now: now, age: 4)
        let middle = snapshot(now: now, age: 3)
        let newest = snapshot(now: now, age: 1)
        let plan = TabHibernationPlanner.plan(
            tabs: [newest, pinned, oldest, visible, middle, audio, downloading, form],
            now: now,
            budget: HibernationBudget(idleInterval: 10_000, maxLiveWebViews: 100),
            pressure: .critical
        )
        #expect(plan.hibernateIDs == [oldest.id, middle.id, newest.id])
        #expect(plan.wakeIDs.isEmpty)
    }

    @Test func normalCapDiscardsOldestEligibleBeforeTheyAreIdle() {
        let now = Date()
        let visible = snapshot(now: now, visible: true)
        let newest = snapshot(now: now, age: 10)
        let middle = snapshot(now: now, age: 20)
        let oldest = snapshot(now: now, age: 30)
        let plan = TabHibernationPlanner.plan(
            tabs: [newest, visible, oldest, middle],
            now: now,
            budget: HibernationBudget(idleInterval: 1_000, maxLiveWebViews: 2),
            pressure: .normal
        )
        #expect(plan.hibernateIDs == [oldest.id, middle.id])
        #expect(!plan.hibernateIDs.contains(newest.id))
        #expect(!plan.hibernateIDs.contains(visible.id))
    }

    @Test func protectedTabsMayExceedTheLiveCap() {
        let now = Date()
        let visible = snapshot(now: now, visible: true)
        let pinned = snapshot(now: now, pinned: true)
        let extra = snapshot(now: now, age: 5)
        let plan = TabHibernationPlanner.plan(
            tabs: [visible, pinned, extra],
            now: now,
            budget: HibernationBudget(idleInterval: 1_000, maxLiveWebViews: 1),
            pressure: .normal
        )
        #expect(plan.hibernateIDs == [extra.id])
    }

    @Test func warningPressureShortensTheIdleInterval() {
        let now = Date()
        let id = UUID()
        let tab = snapshot(id: id, now: now, age: 60)
        let budget = HibernationBudget(idleInterval: 100, maxLiveWebViews: 10)
        let normal = TabHibernationPlanner.plan(tabs: [tab], now: now, budget: budget, pressure: .normal)
        let warning = TabHibernationPlanner.plan(tabs: [tab], now: now, budget: budget, pressure: .warning)
        #expect(normal.hibernateIDs.isEmpty)
        #expect(warning.hibernateIDs == [id])
    }

    @Test func warningPressureDiscardsTheOldestTabPastTheTighterCap() {
        let now = Date()
        let oldest = snapshot(now: now, age: 40)
        let tabs = [
            snapshot(now: now, age: 10),
            snapshot(now: now, age: 20),
            snapshot(now: now, age: 30),
            oldest
        ]
        let budget = HibernationBudget(idleInterval: 1_000, maxLiveWebViews: 6)
        let normal = TabHibernationPlanner.plan(tabs: tabs, now: now, budget: budget, pressure: .normal)
        let warning = TabHibernationPlanner.plan(tabs: tabs, now: now, budget: budget, pressure: .warning)
        #expect(normal.hibernateIDs.isEmpty)
        #expect(warning.hibernateIDs == [oldest.id])
    }

    @Test func visibleTabWithoutAWebViewIsWokenAndNotHibernated() {
        let now = Date()
        let id = UUID()
        let plan = TabHibernationPlanner.plan(
            tabs: [snapshot(id: id, now: now, age: 10_000, visible: true, live: false)],
            now: now,
            budget: HibernationBudget(idleInterval: 30, maxLiveWebViews: 1),
            pressure: .critical
        )
        #expect(plan.hibernateIDs.isEmpty)
        #expect(plan.wakeIDs == [id])
    }

    @Test func wakingAVisibleTabCountsTowardTheLiveCap() {
        let now = Date()
        let visible = snapshot(now: now, visible: true, live: false)
        let background = snapshot(now: now, age: 5)
        let plan = TabHibernationPlanner.plan(
            tabs: [visible, background],
            now: now,
            budget: HibernationBudget(idleInterval: 1_000, maxLiveWebViews: 1),
            pressure: .normal
        )
        #expect(plan.wakeIDs == [visible.id])
        #expect(plan.hibernateIDs == [background.id])
        #expect(Set(plan.hibernateIDs).isDisjoint(with: plan.wakeIDs))
    }

    @Test func tabsThatWereNeverLiveAreNotHibernated() {
        let now = Date()
        let plan = TabHibernationPlanner.plan(
            tabs: [snapshot(now: now, age: 10_000, live: false)],
            now: now,
            budget: .standard,
            pressure: .critical
        )
        #expect(plan.hibernateIDs.isEmpty)
        #expect(plan.wakeIDs.isEmpty)
    }

    @Test func equalTimestampsBreakTiesByIdentifier() {
        let now = Date()
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let plan = TabHibernationPlanner.plan(
            tabs: [snapshot(id: second, now: now), snapshot(id: first, now: now)],
            now: now,
            budget: HibernationBudget(idleInterval: 100, maxLiveWebViews: 1),
            pressure: .normal
        )
        #expect(plan.hibernateIDs == [first])
    }

    @Test func duplicateSnapshotsUseTheLatestDescription() {
        let now = Date()
        let id = UUID()
        let hidden = snapshot(id: id, now: now, age: 5_000, visible: false)
        let shown = snapshot(id: id, now: now, age: 5_000, visible: true)
        let plan = TabHibernationPlanner.plan(
            tabs: [hidden, shown],
            now: now,
            budget: .standard,
            pressure: .critical
        )
        #expect(plan.hibernateIDs.isEmpty)
        #expect(plan.wakeIDs.isEmpty)
    }

    @Test func emptyInputProducesAnEmptyPlan() {
        let plan = TabHibernationPlanner.plan(tabs: [], now: Date(), budget: .standard, pressure: .critical)
        #expect(plan == HibernationPlan(hibernateIDs: [], wakeIDs: []))
    }

    @Test func scrollAnchorsKeepTheNewestAndDropTheOldest() {
        let now = Date()
        let ids = (0..<5).map { _ in UUID() }
        var anchors: [UUID: ScrollAnchor] = [:]
        for (offset, id) in ids.enumerated() {
            anchors[id] = ScrollAnchor(x: 0, y: Double(offset), savedAt: now.addingTimeInterval(TimeInterval(offset)))
        }
        let kept = ScrollAnchorBudget.trimmed(anchors, maxCount: 3)
        #expect(Set(kept.keys) == Set(ids.suffix(3)))
        #expect(ScrollAnchorBudget.trimmed(anchors, maxCount: 10) == anchors)
        #expect(ScrollAnchorBudget.trimmed(anchors, maxCount: 0).isEmpty)
        #expect(ScrollAnchorBudget.trimmed(anchors, maxCount: -2).isEmpty)
    }

    @Test func equalScrollTimestampsKeepTheSmallerIdentifier() {
        let now = Date()
        let low = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let high = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let anchors = [
            high: ScrollAnchor(x: 0, y: 2, savedAt: now),
            low: ScrollAnchor(x: 0, y: 1, savedAt: now)
        ]
        let kept = ScrollAnchorBudget.trimmed(anchors, maxCount: 1)
        #expect(kept[low]?.y == 1)
        #expect(kept[high] == nil)
    }

    @Test func scrollAnchorRejectsNonFiniteAndNegativeOffsets() {
        let anchor = ScrollAnchor(x: .nan, y: -.infinity, savedAt: Date())
        #expect(anchor.x == 0)
        #expect(anchor.y == 0)
        let kept = ScrollAnchor(x: -4, y: 12.5, savedAt: Date())
        #expect(kept.x == 0)
        #expect(kept.y == 12.5)
    }

    @Test func profileDataStoreCacheReusesOneInstancePerIdentifier() {
        final class Token { let name: String; init(_ name: String) { self.name = name } }
        var cache = SharedObjectCache<Token>()
        let profile = UUID()
        let other = UUID()
        var makes = 0
        let first = cache.value(for: profile) { makes += 1; return Token("a") }
        let second = cache.value(for: profile) { makes += 1; return Token("b") }
        let foreign = cache.value(for: other) { Token("c") }
        #expect(first === second)
        #expect(first !== foreign)
        #expect(makes == 1)
        cache.remove(profile)
        let recreated = cache.value(for: profile) { Token("d") }
        #expect(recreated !== first)
        #expect(recreated.name == "d")
    }
}

private func snapshot(
    id: UUID = UUID(),
    now: Date,
    age: TimeInterval = 0,
    visible: Bool = false,
    pinned: Bool = false,
    audio: Bool = false,
    downloading: Bool = false,
    form: Bool = false,
    live: Bool = true
) -> TabMemorySnapshot {
    TabMemorySnapshot(
        id: id,
        lastInteraction: now.addingTimeInterval(-age),
        isVisible: visible,
        isPinned: pinned,
        isPlayingAudio: audio,
        isDownloading: downloading,
        hasUnsavedFormInput: form,
        isLive: live
    )
}
