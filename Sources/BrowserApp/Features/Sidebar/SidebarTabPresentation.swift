import BrowserCore
import Observation
import SwiftUI

struct SidebarPresentedTab: Identifiable {
    var tab: BrowserTab
    var progress: CGFloat = 1
    var isRetiring = false
    var id: UUID { tab.id }
}

/// Sidebar-only presentation snapshots. Core tab/archive state changes
/// immediately; disappearing rows survive just long enough to collapse their
/// real layout height. This avoids OS transition suppression without changing
/// the user's system accessibility preference or animating the browser window.
@MainActor @Observable final class SidebarTabPresentation {
    private(set) var rows: [SidebarPresentedTab]
    @ObservationIgnored private var sourceTabs: [BrowserTab]
    @ObservationIgnored private var entryTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var retirementTasks: [UUID: Task<Void, Never>] = [:]

    init(tabs: [BrowserTab]) {
        sourceTabs = tabs
        rows = tabs.map { SidebarPresentedTab(tab: $0) }
    }

    func update(tabs: [BrowserTab], reducedMotion: Bool) {
        let oldIDs = sourceTabs.map(\.id)
        let newIDs = tabs.map(\.id)
        sourceTabs = tabs
        if reducedMotion {
            cancelPending()
            withoutAnimation { rows = tabs.map { SidebarPresentedTab(tab: $0) } }
            return
        }

        let liveIDs = Set(newIDs)
        let newByID = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        if oldIDs == newIDs {
            // Page titles/URLs and Space/folder moves are not lifecycle events.
            // Keep an existing entry/exit running, but never animate a move.
            withoutAnimation {
                for index in rows.indices {
                    guard let updated = newByID[rows[index].id] else { continue }
                    let previous = rows[index].tab
                    if previous.spaceID != updated.spaceID || previous.folderID != updated.folderID || previous.isPinned != updated.isPinned {
                        entryTasks.removeValue(forKey: updated.id)?.cancel()
                        rows[index].progress = 1
                    }
                    rows[index].tab = updated
                }
            }
            for row in rows {
                if row.isRetiring { scheduleRetirement(row.id) }
                else if row.progress == 0 { scheduleEntry(row.id) }
            }
            return
        }

        let previousRows = rows
        let previousByID = Dictionary(uniqueKeysWithValues: previousRows.map { ($0.id, $0) })
        var restoredIDs: Set<UUID> = []
        var nextRows = tabs.map { tab -> SidebarPresentedTab in
            if var previous = previousByID[tab.id] {
                if previous.isRetiring {
                    retirementTasks.removeValue(forKey: tab.id)?.cancel()
                    restoredIDs.insert(tab.id)
                }
                previous.tab = tab
                previous.isRetiring = false
                return previous
            }
            return SidebarPresentedTab(tab: tab, progress: 0)
        }

        // Keep outgoing snapshots at their former neighbor, including multiple
        // removals in Clear Today, so the remaining rows reflow continuously.
        for (index, previous) in previousRows.enumerated() where !liveIDs.contains(previous.id) {
            var retiring = previous
            retiring.isRetiring = true
            let followingID = previousRows.dropFirst(index + 1).first { liveIDs.contains($0.id) }?.id
            if let followingID, let insertion = nextRows.firstIndex(where: { $0.id == followingID }) {
                nextRows.insert(retiring, at: insertion)
            } else { nextRows.append(retiring) }
            entryTasks.removeValue(forKey: previous.id)?.cancel()
        }

        rows = nextRows
        withAnimation(ChocoMotion.tabLifecycle) {
            for index in rows.indices {
                if rows[index].isRetiring { rows[index].progress = 0 }
                else if restoredIDs.contains(rows[index].id) { rows[index].progress = 1 }
            }
        }
        for row in rows {
            if row.isRetiring { scheduleRetirement(row.id) }
            else if row.progress == 0 { scheduleEntry(row.id) }
        }
    }

    func cancelPending() {
        for task in entryTasks.values { task.cancel() }
        for task in retirementTasks.values { task.cancel() }
        entryTasks.removeAll()
        retirementTasks.removeAll()
    }

    private func scheduleEntry(_ id: UUID) {
        guard entryTasks[id] == nil else { return }
        entryTasks[id] = Task { @MainActor [weak self] in
            // Mount the actual zero-height row first. Updating both endpoints in
            // one SwiftUI transaction would skip all intermediate presentation.
            await Task.yield()
            do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            guard let self, !Task.isCancelled,
                  self.sourceTabs.contains(where: { $0.id == id }),
                  let index = self.rows.firstIndex(where: { $0.id == id && !$0.isRetiring }) else { return }
            withAnimation(ChocoMotion.tabLifecycle) { self.rows[index].progress = 1 }
            self.entryTasks[id] = nil
        }
    }

    private func scheduleRetirement(_ id: UUID) {
        guard retirementTasks[id] == nil else { return }
        retirementTasks[id] = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            guard let self, !Task.isCancelled, !self.sourceTabs.contains(where: { $0.id == id }) else { return }
            self.withoutAnimation { self.rows.removeAll { $0.id == id } }
            self.retirementTasks[id] = nil
        }
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }
}
