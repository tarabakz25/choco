import Foundation

// MARK: - Hibernation policy

/// Coarse memory pressure. The app maps Dispatch memory warnings onto these cases.
public enum MemoryPressureLevel: Equatable, Sendable {
    case normal
    case warning
    case critical
}

/// Facts the hibernation planner needs. WebKit types stay out of this value so tests can build it directly.
public struct TabMemorySnapshot: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var lastInteraction: Date
    public var isVisible: Bool
    public var isPinned: Bool
    public var isPlayingAudio: Bool
    public var isDownloading: Bool
    public var hasUnsavedFormInput: Bool
    public var isLive: Bool

    public init(id: UUID, lastInteraction: Date, isVisible: Bool, isPinned: Bool, isPlayingAudio: Bool, isDownloading: Bool, hasUnsavedFormInput: Bool, isLive: Bool) {
        self.id = id
        self.lastInteraction = lastInteraction
        self.isVisible = isVisible
        self.isPinned = isPinned
        self.isPlayingAudio = isPlayingAudio
        self.isDownloading = isDownloading
        self.hasUnsavedFormInput = hasUnsavedFormInput
        self.isLive = isLive
    }

    /// Visible, pinned, audible, downloading, or mid-edit pages keep their web view.
    public var isProtectedFromHibernation: Bool {
        isVisible || isPinned || isPlayingAudio || isDownloading || hasUnsavedFormInput
    }
}

/// How long an idle page may stay resident, and how many web views may stay resident at once.
public struct HibernationBudget: Equatable, Sendable {
    public var idleInterval: TimeInterval
    public var maxLiveWebViews: Int

    /// Five quiet minutes, then at most six resident web views (the visible page counts).
    public static let standard = HibernationBudget(idleInterval: 5 * 60, maxLiveWebViews: 6)

    public init(idleInterval: TimeInterval, maxLiveWebViews: Int) {
        self.idleInterval = idleInterval.isFinite && idleInterval > 0 ? idleInterval : 0
        self.maxLiveWebViews = max(0, maxLiveWebViews)
    }
}

public struct HibernationPlan: Equatable, Sendable {
    /// Oldest eligible tab first. The caller discards these web views.
    public var hibernateIDs: [UUID]
    /// Visible tabs that have no web view. The caller clears hibernation; the view creates the web view.
    public var wakeIDs: [UUID]

    public init(hibernateIDs: [UUID], wakeIDs: [UUID]) {
        self.hibernateIDs = hibernateIDs
        self.wakeIDs = wakeIDs
    }
}

/// Decides which resident web views to discard. It does not touch WebKit.
public enum TabHibernationPlanner {
    public static func plan(tabs: [TabMemorySnapshot], now: Date, budget: HibernationBudget, pressure: MemoryPressureLevel) -> HibernationPlan {
        var byID: [UUID: TabMemorySnapshot] = [:]
        for tab in tabs { byID[tab.id] = tab }
        let unique = Array(byID.values)

        var live = Set(unique.filter(\.isLive).map(\.id))
        let wake = unique.filter { $0.isVisible && !$0.isLive }.sorted { olderFirst($0, $1) }
        for tab in wake { live.insert(tab.id) }

        let idleLimit = idleThreshold(budget: budget, pressure: pressure)
        let cap = liveCap(budget: budget, pressure: pressure)
        var hibernate: [UUID] = []

        func hibernateIfEligible(_ tab: TabMemorySnapshot) {
            guard live.contains(tab.id), !tab.isProtectedFromHibernation else { return }
            live.remove(tab.id)
            hibernate.append(tab.id)
        }

        let oldestFirst = unique.sorted { olderFirst($0, $1) }
        for tab in oldestFirst where live.contains(tab.id) && !tab.isProtectedFromHibernation {
            let age = now.timeIntervalSince(tab.lastInteraction)
            if age >= idleLimit { hibernateIfEligible(tab) }
        }

        var overflow = live.count - cap
        if overflow > 0 {
            for tab in oldestFirst where overflow > 0 && live.contains(tab.id) && !tab.isProtectedFromHibernation {
                hibernateIfEligible(tab)
                overflow -= 1
            }
        }

        return HibernationPlan(hibernateIDs: hibernate, wakeIDs: wake.map(\.id))
    }

    /// Warning uses half the idle interval and half the live cap (at least one when the normal cap is positive).
    /// Critical treats every eligible resident tab as idle and sets the cap to zero.
    static func idleThreshold(budget: HibernationBudget, pressure: MemoryPressureLevel) -> TimeInterval {
        switch pressure {
        case .normal: return budget.idleInterval
        case .warning: return budget.idleInterval / 2
        case .critical: return 0
        }
    }

    static func liveCap(budget: HibernationBudget, pressure: MemoryPressureLevel) -> Int {
        switch pressure {
        case .normal:
            return budget.maxLiveWebViews
        case .warning:
            guard budget.maxLiveWebViews > 0 else { return 0 }
            return max(1, budget.maxLiveWebViews / 2)
        case .critical:
            return 0
        }
    }

    private static func olderFirst(_ lhs: TabMemorySnapshot, _ rhs: TabMemorySnapshot) -> Bool {
        if lhs.lastInteraction != rhs.lastInteraction { return lhs.lastInteraction < rhs.lastInteraction }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

// MARK: - Scroll anchors kept after a web view is discarded

public struct ScrollAnchor: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var savedAt: Date

    public init(x: Double, y: Double, savedAt: Date) {
        self.x = x.isFinite ? max(0, x) : 0
        self.y = y.isFinite ? max(0, y) : 0
        self.savedAt = savedAt
    }
}

public enum ScrollAnchorBudget {
    /// Enough for a working set of hibernated tabs. Older anchors reload at the top of the page.
    public static let defaultMaxCount = 40

    /// Keeps the newest anchors. Equal timestamps keep the lexicographically smaller id.
    public static func trimmed(_ anchors: [UUID: ScrollAnchor], maxCount: Int) -> [UUID: ScrollAnchor] {
        let limit = max(0, maxCount)
        guard anchors.count > limit else { return anchors }
        guard limit > 0 else { return [:] }
        let newestFirst = anchors.sorted { lhs, rhs in
            if lhs.value.savedAt != rhs.value.savedAt { return lhs.value.savedAt > rhs.value.savedAt }
            return lhs.key.uuidString < rhs.key.uuidString
        }
        return Dictionary(uniqueKeysWithValues: newestFirst.prefix(limit).map { ($0.key, $0.value) })
    }
}
