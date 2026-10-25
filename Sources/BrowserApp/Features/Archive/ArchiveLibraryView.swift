import AppKit
import BrowserCore
import SwiftUI

/// Library chrome stays beside the live page; entries are restored only by an
/// explicit restore action, never by selecting a search result.
struct ArchiveLibraryView: View {
    @Bindable var model: AppModel
    @State private var search = ""
    @State private var scope = ArchiveScope.allSpaces
    @State private var selectedEntryID: UUID?
    @FocusState private var searchFocused: Bool
    @FocusState private var focusedEntryID: UUID?

    private enum ArchiveScope: String, CaseIterable, Identifiable {
        case allSpaces, currentSpace
        var id: Self { self }
        var label: String { self == .allSpaces ? "すべてのSpace" : "現在のSpace" }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let entries: [ArchiveEntry]
        var id: Date { day }
    }

    private var visibleEntries: [ArchiveEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.state.archive.filter { entry in
            (scope == .allSpaces || entry.tab.spaceID == model.state.selectedSpaceID) &&
            (query.isEmpty || "\(entry.tab.displayTitle) \(entry.tab.url)".localizedCaseInsensitiveContains(query))
        }.sorted { $0.archivedAt > $1.archivedAt }
    }

    private var dayGroups: [DayGroup] {
        let grouped = Dictionary(grouping: visibleEntries) { Calendar.current.startOfDay(for: $0.archivedAt) }
        return grouped.keys.sorted(by: >).map { DayGroup(day: $0, entries: grouped[$0] ?? []) }
    }

    var body: some View {
        HStack(spacing: 0) {
            libraryRail.frame(width: 96)
            archivePanel.frame(width: 266)
        }
        .frame(width: 362)
        .frame(maxHeight: .infinity)
        .background(ChocoTheme.sidebar)
        .foregroundStyle(ChocoTheme.text)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library-sidebar")
        .task { await focusSearchAfterMount() }
        .onChange(of: search) { _, _ in clearSelection() }
        .onChange(of: scope) { _, _ in clearSelection() }
        .onChange(of: model.state.archive) { _, entries in
            if let selectedEntryID, !entries.contains(where: { $0.id == selectedEntryID }) { clearSelection() }
        }
    }

    private var libraryRail: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 650
            VStack(spacing: compact ? 10 : 18) {
                unavailableRailItem("メディア", icon: "5de62", reason: "メディアライブラリは未対応です。", height: compact ? 44 : 56)
                unavailableRailItem("ダウンロード", icon: "0b3d0", reason: "ダウンロード履歴の一覧は未対応です。ファイルの保存はWebページから行えます。", height: compact ? 44 : 56)
                unavailableRailItem("Easel", icon: "cf6cb", reason: "Easelは未対応です。", height: compact ? 44 : 56)
                Button { model.showsArchive = false } label: {
                    railLabel("Space", icon: "e2dfa", height: compact ? 44 : 56)
                }
                .buttonStyle(.plain)
                .help("現在のSpaceに戻る")
                .accessibilityIdentifier("library-spaces")
                unavailableRailItem("Boost", icon: "c571a", reason: "サイトのBoost編集は未対応です。", height: compact ? 44 : 56)
                Button { searchFocused = true } label: {
                    railLabel("アーカイブ", icon: "61b66", active: true, height: compact ? 44 : 56)
                }
                .buttonStyle(.plain)
                .help("閉じたタブを検索")
                .accessibilityAddTraits(.isSelected)
                .accessibilityIdentifier("library-archive")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 52)
            .padding(.bottom, 125)
            .overlay(alignment: .bottom) {
                HStack(spacing: 0) {
                    Button { model.showsArchive = false } label: {
                        DesignIcon("687ab", size: 16).opacity(0.7).frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .help("サイドバーに戻る")
                    .accessibilityLabel("サイドバーに戻る")
                    .accessibilityIdentifier("library-back")
                    Spacer(minLength: 0)
                    Menu {
                        ForEach(model.state.spaces) { space in
                            Button("\(space.icon) \(space.name)") {
                                model.send(.selectSpace(space.id))
                                model.showsArchive = false
                            }
                        }
                    } label: {
                        SpaceIcon(model.selectedSpace?.icon ?? "", size: 16).opacity(0.7).frame(width: 26, height: 26)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Spaceを選んで戻る")
                    .accessibilityLabel("Spaceを選択")
                    .accessibilityIdentifier("library-space-picker")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    private func railLabel(_ title: String, icon: String, active: Bool = false, height: CGFloat) -> some View {
        VStack(spacing: 5) {
            DesignIcon(icon, size: 20).opacity(active ? 0.95 : 0.7)
            Text(title)
                .font(ChocoTheme.font(10, weight: .semibold))
                .foregroundStyle(active ? ChocoTheme.text : ChocoTheme.secondary)
                .lineLimit(1)
        }
        .frame(width: 70, height: height)
        .background(active ? ChocoTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private func unavailableRailItem(_ title: String, icon: String, reason: String, height: CGFloat) -> some View {
        Button {} label: { railLabel(title, icon: icon, height: height) }
            .buttonStyle(.plain)
            .disabled(true)
            .help(reason)
            .accessibilityHint(reason)
    }

    private var archivePanel: some View {
        VStack(spacing: 4) {
            searchHeader
            if visibleEntries.isEmpty {
                emptyState
            } else {
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(dayGroups) { group in
                                Text(dayLabel(group.day))
                                    .font(ChocoTheme.font(11, weight: .semibold))
                                    .foregroundStyle(ChocoTheme.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 8)
                                    .frame(height: 24)
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(group.entries) { entry in
                                    ArchiveLibraryRow(entry: entry, selected: selectedEntryID == entry.id) { restore(entry.id) }
                                        .id(entry.id)
                                        .focusable()
                                        .focused($focusedEntryID, equals: entry.id)
                                        .onTapGesture(count: 2) { restore(entry.id) }
                                        .onTapGesture { selectedEntryID = entry.id; focusedEntryID = entry.id }
                                        .onKeyPress(.return) { restore(entry.id); return .handled }
                                        .onKeyPress(.downArrow) { moveSelection(from: entry.id, backwards: false); return .handled }
                                        .onKeyPress(.upArrow) { moveSelection(from: entry.id, backwards: true); return .handled }
                                }
                            }
                        }.padding(.top, 8)
                    }
                    .scrollIndicators(.never)
                    .onChange(of: selectedEntryID) { _, id in
                        if let id { reader.scrollTo(id) }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var searchHeader: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                DesignIcon("9d9ff", size: 13).opacity(0.6)
                TextField("アーカイブを検索", text: $search, prompt: Text("アーカイブを検索").foregroundStyle(ChocoTheme.tertiary))
                    .font(ChocoTheme.font(13))
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .accessibilityIdentifier("library-search")
                    .onKeyPress(.downArrow) {
                        guard !hasMarkedText, let first = visibleEntries.first else { return .ignored }
                        selectedEntryID = first.id; focusedEntryID = first.id; return .handled
                    }
                    .onKeyPress(.escape) {
                        guard !hasMarkedText else { return .ignored }
                        if search.isEmpty { model.showsArchive = false } else { search = "" }
                        return .handled
                    }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(ChocoTheme.field, in: RoundedRectangle(cornerRadius: 8))
            Menu {
                Picker("表示するSpace", selection: $scope) {
                    ForEach(ArchiveScope.allCases) { item in Text(item.label).tag(item) }
                }
            } label: {
                HStack(spacing: 4) {
                    DesignIcon("03c3d", size: 14).opacity(0.7)
                    Text("絞込").font(ChocoTheme.font(13, weight: .medium))
                        .foregroundStyle(ChocoTheme.secondary)
                }
                .padding(.leading, 6).padding(.trailing, 8)
                .frame(height: 26)
                .background(scope == .currentSpace ? ChocoTheme.field : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(scope.label)
            .accessibilityLabel("アーカイブの表示範囲")
            .accessibilityValue(scope.label)
            .accessibilityIdentifier("library-filter")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            DesignIcon("61b66", size: 24).opacity(0.65)
            Text(emptyTitle).font(ChocoTheme.font(13, weight: .medium))
                .foregroundStyle(ChocoTheme.text)
            Text(emptyDescription).font(ChocoTheme.font(11))
                .foregroundStyle(ChocoTheme.secondary)
                .multilineTextAlignment(.center)
            if scope == .currentSpace && !model.state.archive.isEmpty && search.isEmpty {
                Button("すべてのSpaceを表示") { scope = .allSpaces }
                    .font(ChocoTheme.font(11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(ChocoTheme.text)
            }
        }
        .padding(.horizontal, 12).padding(.top, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var emptyTitle: String {
        if model.state.archive.isEmpty { return "アーカイブは空です" }
        return search.isEmpty ? "このSpaceのタブはありません" : "一致するタブがありません"
    }

    private var emptyDescription: String {
        if model.state.archive.isEmpty { return "Todayで閉じたタブを、ここから復元できます。" }
        return search.isEmpty ? "表示範囲を切り替えると、ほかのSpaceのタブも確認できます。" : "名前やURLを変えて検索してください。"
    }

    private var hasMarkedText: Bool { (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() ?? false }

    private func focusSearchAfterMount() async {
        let initialSearch = search
        focusedEntryID = nil
        searchFocused = false
        // The field must be attached to its native window before requesting
        // focus; otherwise macOS chooses the first focusable archive row.
        await Task.yield()
        do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
        guard !Task.isCancelled, model.showsArchive, model.commandMode == nil,
              model.editor == nil, selectedEntryID == nil, search == initialSearch,
              !hasMarkedText else { return }
        focusedEntryID = nil
        searchFocused = true
    }

    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今日" }
        if calendar.isDateInYesterday(date) { return "昨日" }
        return date.formatted(.dateTime.year().month().day())
    }

    private func clearSelection() { selectedEntryID = nil; focusedEntryID = nil }

    private func moveSelection(from id: UUID, backwards: Bool) {
        let entries = visibleEntries
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + (backwards ? -1 : 1)
        guard entries.indices.contains(destination) else {
            if backwards { searchFocused = true }
            return
        }
        selectedEntryID = entries[destination].id
        focusedEntryID = entries[destination].id
    }

    private func restore(_ id: UUID) {
        guard model.state.archive.contains(where: { $0.id == id }) else { return }
        model.send(.restoreArchive(id))
        model.showsArchive = false
    }
}

private struct ArchiveLibraryRow: View {
    let entry: ArchiveEntry
    let selected: Bool
    let restore: () -> Void
    @State private var hovering = false

    private var displayAddress: String {
        guard let url = URL(string: entry.tab.url), let host = url.host else { return entry.tab.url }
        return host + (url.path == "/" ? "" : url.path.removingPercentEncoding ?? url.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            SiteIcon(url: entry.tab.url, size: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.tab.displayTitle).font(ChocoTheme.font(13, weight: .medium))
                    .foregroundStyle(ChocoTheme.text).lineLimit(1).truncationMode(.tail)
                Text(displayAddress).font(ChocoTheme.font(11))
                    .foregroundStyle(ChocoTheme.secondary).lineLimit(1).truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: restore) {
                Text("復元").font(ChocoTheme.font(10, weight: .medium))
                    .foregroundStyle(ChocoTheme.text)
                    .padding(.horizontal, 4).frame(height: 24)
                    .background(hovering || selected ? ChocoTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .opacity(hovering || selected ? 1 : 0.65)
            .help("このタブを復元")
            .accessibilityLabel("\(entry.tab.displayTitle)を復元")
            .accessibilityIdentifier("restore-archive-\(entry.id)")
        }
        .padding(.leading, 8).padding(.trailing, 6)
        .frame(height: 44)
        .background(hovering || selected ? ChocoTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
        .help(entry.tab.url)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(entry.tab.displayTitle)、\(displayAddress)")
        .accessibilityIdentifier("archive-row-\(entry.id)")
    }
}
