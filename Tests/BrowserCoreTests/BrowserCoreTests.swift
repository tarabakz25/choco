import Foundation
import Testing
@testable import BrowserCore

@Suite @MainActor struct BrowserCoreTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OssArcCoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func pinnedCloseKeepsRegistrationButTodayCloseArchives() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let pinnedID = try #require(store.state.selectedTabID)
        store.updatePage(tabID: pinnedID, url: "https://example.com/start", title: "Original")
        store.send(.pinTab(pinnedID))
        store.send(.renameTab(pinnedID, "My page"))
        store.updatePage(tabID: pinnedID, url: "https://example.com/next", title: "Next")
        store.send(.resetPinnedTab(pinnedID))
        #expect(store.state.tabs[0].url == "https://example.com/start")
        #expect(store.state.tabs[0].displayTitle == "My page")
        store.send(.closeTab(pinnedID))
        #expect(store.state.tabs.map(\.id) == [pinnedID])
        #expect(store.state.selectedTabID == nil)
        #expect(store.state.archive.isEmpty)
        store.send(.newTab(url: "https://other.example"))
        let todayID = try #require(store.state.selectedTabID)
        store.send(.closeTab(todayID))
        #expect(store.state.tabs.map(\.id) == [pinnedID])
        #expect(store.state.archive.first?.tab.id == todayID)
        store.send(.restoreLatestArchive)
        #expect(store.state.selectedTabID == todayID)
        #expect(store.state.archive.isEmpty)
        await store.flush()
    }

    @Test func deletingPinnedTabAndFolderPreservesRestorableMetadata() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let tabID = try #require(store.state.selectedTabID)
        store.send(.createFolder(name: "Parent", parentID: nil))
        let parentID = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Child", parentID: parentID))
        let childID = try #require(store.state.folders.last?.id)
        store.send(.moveTab(tabID, spaceID: store.state.selectedSpaceID, folderID: childID))
        #expect(store.state.tabs[0].isPinned)
        store.send(.deleteTab(tabID))
        #expect(store.state.tabs.isEmpty)
        store.send(.deleteFolder(childID))
        #expect(store.state.archive[0].tab.folderID == parentID)
        store.send(.restoreLatestArchive)
        #expect(store.state.tabs[0].id == tabID)
        #expect(store.state.tabs[0].folderID == parentID)
        store.send(.unpinTab(tabID))
        #expect(store.state.tabs[0].folderID == nil)
        #expect(!store.state.tabs[0].isPinned)
        await store.flush()
    }

    @Test func clearTodayOnlyAffectsCurrentSpaceAndNeverPinnedTabs() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let firstSpace = store.state.selectedSpaceID
        let pinnedID = try #require(store.state.selectedTabID)
        store.send(.pinTab(pinnedID))
        store.send(.newTab(url: "https://first.example"))
        let firstToday = try #require(store.state.selectedTabID)
        store.send(.createSpace(name: "Second", icon: "2", colorHex: "123456", profileID: store.state.profiles[0].id))
        store.send(.newTab(url: "https://second.example"))
        let secondToday = try #require(store.state.selectedTabID)
        store.send(.selectSpace(firstSpace)); store.send(.clearToday)
        #expect(Set(store.state.tabs.map(\.id)) == Set([pinnedID, secondToday]))
        #expect(store.state.archive.map(\.tab.id) == [firstToday])
        await store.flush()
    }

    @Test func favoritesAreGlobalDefinitionsWithLimitAndExclusiveSelection() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        for i in 0..<14 { store.send(.createFavorite(title: "Favorite \(i)", url: "https://example.com/\(i)")) }
        #expect(store.state.favorites.count == 12)
        let favoriteID = store.state.favorites[0].id
        let initialCount = store.state.tabs.count
        store.send(.selectFavorite(favoriteID))
        #expect(store.state.selectedTabID == nil)
        store.send(.createProfile(name: "Work"))
        let profileID = try #require(store.state.profiles.last?.id)
        store.send(.createSpace(name: "Work", icon: "💼", colorHex: "#123456", profileID: profileID))
        #expect(store.state.selectedProfile?.id == profileID)
        #expect(store.state.selectedFavoriteID == favoriteID)
        #expect(store.state.tabs.count == initialCount)
        #expect(store.state.favorites[0].id == favoriteID)
        await store.flush()
    }

    @Test func splitReferencesExistingTabsAndCollapsesOnMoveOrArchive() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let firstID = try #require(store.state.selectedTabID)
        store.send(.newTab(url: "https://second.example"))
        let secondID = try #require(store.state.selectedTabID)
        store.send(.setSplit(leading: firstID, trailing: secondID))
        #expect(store.state.tabs.count == 2)
        store.send(.setSplitFraction(0.7)); store.send(.swapSplit)
        #expect(store.state.split?.leadingTabID == secondID)
        #expect(abs((store.state.split?.fraction ?? 0) - 0.3) < 0.001)
        store.send(.closeTab(firstID))
        #expect(store.state.split == nil)
        #expect(store.state.selectedTabID == secondID)
        store.send(.restoreLatestArchive)
        store.send(.createSpace(name: "Elsewhere", icon: "X", colorHex: "000000", profileID: store.state.profiles[0].id))
        let otherSpaceID = store.state.selectedSpaceID
        store.send(.moveTab(firstID, spaceID: otherSpaceID, folderID: nil))
        store.send(.setSplit(leading: firstID, trailing: secondID))
        #expect(store.state.split == nil)
        #expect(store.state.tabs.count == 2)
        await store.flush()
    }

    @Test func nestedFolderDeletionReparentsChildrenAndKeepsTabOrder() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        store.send(.createFolder(name: "Root", parentID: nil))
        let root = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Middle", parentID: root))
        let middle = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Leaf", parentID: middle))
        let leaf = try #require(store.state.folders.last?.id)
        let tabID = try #require(store.state.selectedTabID)
        store.send(.moveTab(tabID, spaceID: store.state.selectedSpaceID, folderID: middle))
        store.send(.deleteFolder(middle))
        #expect(store.state.folders.first(where: { $0.id == leaf })?.parentID == root)
        #expect(store.state.tabs.first?.folderID == root)
        store.send(.newTab(url: "https://a.example"))
        let first = try #require(store.state.selectedTabID)
        store.send(.duplicateTab(first))
        let second = try #require(store.state.selectedTabID)
        store.send(.moveTabBefore(second, beforeID: first))
        #expect(store.state.tabs.map(\.id) == [tabID, second, first])
        await store.flush()
    }

    @Test func persistenceRoundTripKeepsIdentityLayoutAndLatestSnapshot() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let first = try #require(store.state.selectedTabID)
        store.send(.pinTab(first)); store.send(.renameTab(first, "Pinned"))
        store.send(.newTab(url: "https://second.example"))
        let second = try #require(store.state.selectedTabID)
        store.send(.setSplit(leading: first, trailing: second))
        store.send(.setSplitFraction(0.63))
        for i in 0..<50 { store.updatePage(tabID: second, url: "https://second.example/\(i)", title: "Page \(i)") }
        store.send(.toggleSidebar)
        await store.flush()
        #expect(store.persistenceError == nil)
        let restored = BrowserStore(directory: directory)
        #expect(restored.state == store.state)
        #expect(restored.state.tabs.last?.url == "https://second.example/49")
        #expect(restored.state.split?.fraction == 0.63)
        #expect(restored.state.selectedProfile?.id == store.state.profiles[0].id)
        #expect(!restored.state.sidebarVisible)
    }

    @Test func corruptAndUnsupportedFilesArePreservedBeforeNewStateIsSaved() async throws {
        for original in [Data("{ broken".utf8), Data("{\"schemaVersion\":999}".utf8)] {
            let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
            let file = directory.appendingPathComponent("state.json")
            try original.write(to: file)
            let store = BrowserStore(directory: directory)
            #expect(store.persistenceError != nil)
            let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("state.recovery-") }
            #expect(backups.count == 1)
            #expect(try Data(contentsOf: #require(backups.first)) == original)
            store.send(.newTab(url: "https://recovery.example")); await store.flush()
            #expect(store.persistenceError != nil)
            let restored = BrowserStore(directory: directory)
            #expect(restored.persistenceError == nil)
            #expect(restored.state.tabs.count == 2)
            #expect(try Data(contentsOf: #require(backups.first)) == original)
        }
    }

    @Test func structuralRecoveryBreaksCyclesRepairsReferencesAndBacksUpOriginal() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let profile = BrowserProfile(name: "Profile")
        let space = BrowserSpace(name: "Space", profileID: UUID())
        let a = UUID(), b = UUID()
        let tab = BrowserTab(spaceID: UUID(), folderID: a)
        let folders = [BrowserFolder(id: a, spaceID: space.id, parentID: b, name: "A"), BrowserFolder(id: b, spaceID: space.id, parentID: a, name: "B")]
        let broken = BrowserState(profiles: [profile, profile], spaces: [space], tabs: [tab, tab], folders: folders, selectedSpaceID: UUID(), selectedTabID: UUID(), split: SplitState(leadingTabID: tab.id, trailingTabID: UUID()))
        let data = try JSONEncoder().encode(broken)
        try data.write(to: directory.appendingPathComponent("state.json"))
        let store = BrowserStore(directory: directory)
        #expect(store.persistenceError != nil)
        #expect(store.state.profiles.count == 3)
        #expect(store.state.tabs.count == 1)
        #expect(store.state.tabs[0].spaceID == tab.spaceID)
        #expect(store.state.tabs[0].folderID == nil)
        #expect(store.state.selectedProfile?.id == space.profileID)
        #expect(store.state.selectedProfile?.id != profile.id)
        #expect(store.state.selectedTabID == nil)
        #expect(store.state.split == nil)
        #expect(store.state.folders.contains(where: { $0.parentID == nil }))
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("state.recovery-") }
        #expect(try Data(contentsOf: #require(backups.first)) == data)
        await store.flush()
        #expect(BrowserStore(directory: directory).persistenceError == nil)
    }

    @Test func invalidCommandsDoNotCreateDanglingReferencesOrChangeLayout() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let initial = store.state
        let tabID = try #require(initial.selectedTabID)
        store.send(.selectSpace(UUID()))
        store.send(.selectTab(UUID()))
        store.send(.moveTab(tabID, spaceID: UUID(), folderID: nil))
        store.send(.moveTab(tabID, spaceID: initial.selectedSpaceID, folderID: UUID()))
        store.send(.createFolder(name: "Invalid", parentID: UUID()))
        store.send(.createSpace(name: "Invalid", icon: "", colorHex: "", profileID: UUID()))
        store.send(.setSplit(leading: tabID, trailing: tabID))
        store.send(.setSplitFraction(.nan))
        #expect(store.state == initial)
        await store.flush()
    }

    @Test func persistenceFailureIsVisibleAndCanBeRetried() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data("blocker".utf8).write(to: blocker)
        let store = BrowserStore(directory: blocker)
        store.send(.newTab(url: "https://unsaved.example")); await store.flush()
        #expect(store.persistenceError != nil)
        #expect(try Data(contentsOf: blocker) == Data("blocker".utf8))
        try FileManager.default.removeItem(at: blocker)
        await store.flush()
        #expect(store.persistenceError == nil)
        #expect(BrowserStore(directory: blocker).state == store.state)
    }

    @Test func profileChangesAndCrossSpaceMovesKeepTabIdentityWithoutForeignFolders() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let firstSpace = store.state.selectedSpaceID
        let tabID = try #require(store.state.selectedTabID)
        store.send(.createFolder(name: "Personal", parentID: nil))
        let folder = try #require(store.state.folders.first?.id)
        store.send(.moveTab(tabID, spaceID: firstSpace, folderID: folder))
        store.send(.createProfile(name: "Work"))
        let secondProfile = try #require(store.state.profiles.last?.id)
        store.send(.createSpace(name: "Work", icon: "💼", colorHex: "123456", profileID: secondProfile))
        let secondSpace = store.state.selectedSpaceID
        let beforeInvalidMove = store.state
        store.send(.moveTab(tabID, spaceID: secondSpace, folderID: folder))
        #expect(store.state == beforeInvalidMove)
        store.send(.moveTab(tabID, spaceID: secondSpace, folderID: nil))
        store.send(.selectTab(tabID))
        #expect(store.state.selectedProfile?.id == secondProfile)
        #expect(store.state.tabs[0].id == tabID)
        #expect(store.state.tabs[0].folderID == nil)
        #expect(store.state.tabs[0].isPinned)
        store.send(.updateSpace(secondSpace, name: "Work", icon: "💼", colorHex: "123456", profileID: store.state.profiles[0].id))
        #expect(store.state.selectedProfile?.id == store.state.profiles[0].id)
        #expect(store.state.tabs[0].id == tabID)
        await store.flush()
    }

    @Test func obsoletePersistenceSnapshotCannotOverwriteLatestRevision() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let older = BrowserState.initial()
        var newer = older
        newer.sidebarVisible = false
        let writer = StateWriter(directory: directory, canSave: true)
        try await writer.write(newer, revision: 2)
        try await writer.write(older, revision: 1)
        #expect(BrowserStore(directory: directory).state == newer)
    }

    @Test func reservedZeroProfileIdentifierIsReplacedWithoutBreakingSpaceAssignments() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        let zeroProfile = BrowserProfile(id: zero, name: "Imported profile")
        let first = BrowserSpace(name: "First", profileID: zero)
        let second = BrowserSpace(name: "Second", profileID: zero)
        let unaffected = BrowserProfile(name: "Unaffected")
        let third = BrowserSpace(name: "Third", profileID: unaffected.id)
        let original = BrowserState(profiles: [zeroProfile, unaffected], spaces: [first, second, third], selectedSpaceID: second.id)
        let data = try JSONEncoder().encode(original)
        try data.write(to: directory.appendingPathComponent("state.json"))
        let store = BrowserStore(directory: directory)
        let replacement = try #require(store.state.profiles.first?.id)
        #expect(replacement != zero)
        #expect(store.state.spaces[0].profileID == replacement)
        #expect(store.state.spaces[1].profileID == replacement)
        #expect(store.state.spaces[2].profileID == unaffected.id)
        #expect(store.state.selectedProfile?.id == replacement)
        #expect(store.state.selectedProfile?.name == zeroProfile.name)
        #expect(store.persistenceError != nil)
        await store.flush()
        #expect(BrowserStore(directory: directory).state == store.state)
    }

    @Test func missingProfileRecordsRestoreOriginalIsolationRatherThanUsingPersonalProfile() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let personal = BrowserProfile(name: "Personal")
        let missingWorkID = UUID()
        let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        let personalSpace = BrowserSpace(name: "Personal", profileID: personal.id)
        let workSpace = BrowserSpace(name: "Work", profileID: missingWorkID)
        let relatedWorkSpace = BrowserSpace(name: "Related work", profileID: missingWorkID)
        let invalidSpace = BrowserSpace(name: "Invalid zero", profileID: zero)
        let original = BrowserState(profiles: [personal], spaces: [personalSpace, workSpace, relatedWorkSpace, invalidSpace], selectedSpaceID: workSpace.id)
        try JSONEncoder().encode(original).write(to: directory.appendingPathComponent("state.json"))
        let store = BrowserStore(directory: directory)
        #expect(store.state.selectedProfile?.id == missingWorkID)
        #expect(store.state.spaces[0].profileID == personal.id)
        #expect(store.state.spaces[1].profileID == missingWorkID)
        #expect(store.state.spaces[2].profileID == missingWorkID)
        let zeroReplacement = store.state.spaces[3].profileID
        #expect(zeroReplacement != zero)
        #expect(zeroReplacement != personal.id)
        #expect(zeroReplacement != missingWorkID)
        #expect(store.state.profiles.count == 3)
        #expect(store.state.profiles.contains(where: { $0.id == missingWorkID }))
        #expect(store.persistenceError != nil)
        await store.flush()
        #expect(BrowserStore(directory: directory).state == store.state)
    }

    @Test func missingSpaceRecordsRecoverUnderAnIsolatedProfile() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let personal = BrowserProfile(name: "Personal")
        let personalSpace = BrowserSpace(name: "Personal", profileID: personal.id)
        let missingSpaceID = UUID()
        let tab = BrowserTab(spaceID: missingSpaceID, url: "https://work.example")
        let archive = ArchiveEntry(tab: BrowserTab(spaceID: missingSpaceID, url: "https://archived.work.example"))
        let original = BrowserState(profiles: [personal], spaces: [personalSpace], tabs: [tab], archive: [archive], selectedSpaceID: missingSpaceID, selectedTabID: tab.id)
        try JSONEncoder().encode(original).write(to: directory.appendingPathComponent("state.json"))
        let store = BrowserStore(directory: directory)
        #expect(store.state.selectedSpaceID == missingSpaceID)
        #expect(store.state.selectedTabID == tab.id)
        #expect(store.state.selectedProfile?.id != personal.id)
        #expect(store.state.tabs[0].spaceID == missingSpaceID)
        #expect(store.state.archive[0].tab.spaceID == missingSpaceID)
        #expect(store.state.spaces.count == 2)
        #expect(store.state.profiles.count == 2)
        await store.flush()
        #expect(BrowserStore(directory: directory).state == store.state)
    }

    @Test func atomicPopupInsertionUsesProvidedIdentityAndTargetSpace() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let originSpace = store.state.selectedSpaceID
        store.send(.createSpace(name: "Other", icon: "2", colorHex: "123456", profileID: store.state.profiles[0].id))
        let popupID = UUID()
        store.send(.newTabWithID(id: popupID, spaceID: originSpace, url: "https://popup.example"))
        #expect(store.state.selectedTabID == popupID)
        #expect(store.state.selectedSpaceID == originSpace)
        #expect(store.state.tabs.last?.spaceID == originSpace)
        let snapshot = store.state
        store.send(.newTabWithID(id: popupID, spaceID: originSpace, url: "https://duplicate.example"))
        store.send(.newTabWithID(id: UUID(), spaceID: UUID(), url: "https://unknown-space.example"))
        #expect(store.state == snapshot)
        await store.flush()
    }

    @Test func folderSiblingOrderCanMoveBeforeOrToEndAndSurvivesRestart() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        for name in ["A", "B", "C"] { store.send(.createFolder(name: name, parentID: nil)) }
        let a = store.state.folders[0].id, b = store.state.folders[1].id, c = store.state.folders[2].id
        store.send(.moveFolder(c, parentID: nil, beforeID: a))
        #expect(store.state.folders.map(\.id) == [c, a, b])
        store.send(.moveFolder(c, parentID: nil, beforeID: nil))
        #expect(store.state.folders.map(\.id) == [a, b, c])
        store.send(.moveFolder(b, parentID: nil, beforeID: a))
        #expect(store.state.folders.map(\.id) == [b, a, c])
        await store.flush()
        #expect(BrowserStore(directory: directory).state.folders.map(\.id) == [b, a, c])
    }

    @Test func folderReparentingPreservesSubfoldersTabsAndArchiveAssociations() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        store.send(.createFolder(name: "First root", parentID: nil))
        let firstRoot = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Second root", parentID: nil))
        let secondRoot = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Moving child", parentID: firstRoot))
        let moving = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Grandchild", parentID: moving))
        let grandchild = try #require(store.state.folders.last?.id)
        let tab = try #require(store.state.selectedTabID)
        store.send(.moveTab(tab, spaceID: store.state.selectedSpaceID, folderID: moving))
        store.send(.newTab(url: "https://nested.example"))
        let nestedTab = try #require(store.state.selectedTabID)
        store.send(.moveTab(nestedTab, spaceID: store.state.selectedSpaceID, folderID: grandchild))
        store.send(.duplicateTab(nestedTab))
        let archivedTab = try #require(store.state.selectedTabID)
        store.send(.deleteTab(archivedTab))
        let tabsBefore = store.state.tabs, archiveBefore = store.state.archive
        store.send(.moveFolder(moving, parentID: secondRoot, beforeID: nil))
        #expect(store.state.folders.first(where: { $0.id == moving })?.parentID == secondRoot)
        #expect(store.state.folders.first(where: { $0.id == grandchild })?.parentID == moving)
        #expect(store.state.tabs == tabsBefore)
        #expect(store.state.archive == archiveBefore)
        store.send(.moveFolder(moving, parentID: nil, beforeID: firstRoot))
        #expect(store.state.folders.filter { $0.parentID == nil }.map(\.id) == [moving, firstRoot, secondRoot])
        #expect(store.state.tabs == tabsBefore)
        #expect(store.state.archive == archiveBefore)
        await store.flush()
        #expect(BrowserStore(directory: directory).state == store.state)
    }

    @Test func folderMovesRejectCyclesForeignParentsAndInvalidSiblingTargetsAtomically() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = BrowserStore(directory: directory)
        let firstSpace = store.state.selectedSpaceID
        store.send(.createFolder(name: "Root", parentID: nil))
        let root = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Child", parentID: root))
        let child = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Grandchild", parentID: child))
        let grandchild = try #require(store.state.folders.last?.id)
        store.send(.createFolder(name: "Other root", parentID: nil))
        let otherRoot = try #require(store.state.folders.last?.id)
        store.send(.createSpace(name: "Foreign", icon: "2", colorHex: "123456", profileID: store.state.profiles[0].id))
        store.send(.createFolder(name: "Foreign root", parentID: nil))
        let foreign = try #require(store.state.folders.last?.id)
        store.send(.selectSpace(firstSpace))
        let snapshot = store.state
        let invalidActions: [BrowserAction] = [
            .moveFolder(root, parentID: root, beforeID: nil),
            .moveFolder(root, parentID: grandchild, beforeID: nil),
            .moveFolder(child, parentID: grandchild, beforeID: nil),
            .moveFolder(root, parentID: foreign, beforeID: nil),
            .moveFolder(root, parentID: nil, beforeID: foreign),
            .moveFolder(otherRoot, parentID: nil, beforeID: child),
            .moveFolder(otherRoot, parentID: root, beforeID: grandchild),
            .moveFolder(root, parentID: nil, beforeID: root),
            .moveFolder(root, parentID: UUID(), beforeID: nil),
            .moveFolder(UUID(), parentID: nil, beforeID: nil)
        ]
        for action in invalidActions { store.send(action); #expect(store.state == snapshot) }
        await store.flush()
    }
}
