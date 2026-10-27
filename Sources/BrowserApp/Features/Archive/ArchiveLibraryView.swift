import AppKit
import BrowserCore
import SwiftUI

/// Library chrome stays beside the live page; entries are restored only by an
/// explicit restore action, never by selecting a search result.
struct ArchiveLibraryView: View {
    @Bindable var model: AppModel
    @Environment(\.spaceTheme) private var theme
    @State private var search = ""
    @State private var scope = ArchiveScope.allSpaces
    @State private var selectedEntryID: UUID?
    @State private var page = LibraryPage.archive
    @State private var pageSearch = ""
    @FocusState private var searchFocused: Bool
    @FocusState private var focusedEntryID: UUID?

    private enum ArchiveScope: String, CaseIterable, Identifiable {
        case allSpaces, currentSpace
        var id: Self { self }
        var label: String { self == .allSpaces ? "すべてのSpace" : "現在のSpace" }
    }

    /// Figma's rail pages. Only the Archive is backed by data; the others show the design's empty state.
    private enum LibraryPage: String, CaseIterable, Identifiable {
        case media, downloads, easels, boosts, archive
        var id: Self { self }
        var feature: String {
            switch self {
            case .media: "メディア"
            case .downloads: "ダウンロード"
            case .easels: "Easel"
            case .boosts: "Boost"
            case .archive: "アーカイブ"
            }
        }
        var icon: String {
            switch self {
            case .media: "5de62"
            case .downloads: "0b3d0"
            case .easels: "cf6cb"
            case .boosts: "c571a"
            case .archive: "61b66"
            }
        }
        var searchPrompt: String { "\(feature)を検索" }
        var emptyDescription: String {
            switch self {
            case .media: "ドキュメント、デスクトップ、ダウンロードフォルダに保存したメディアが、キャプチャと一緒にここに表示されます。"
            case .downloads: "ダウンロードしたファイルが、ここに表示されます。"
            case .easels: "作成したEaselが、ここに表示されます。"
            case .boosts: "サイトごとのBoostが、ここに表示されます。"
            case .archive: ""
            }
        }
        /// Figma's Downloads header pairs a 180pt search field with a filter button.
        var hasFilter: Bool { self == .downloads }
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
            libraryRail.frame(width: ChocoSpace.u(96))
            libraryPanel.frame(width: ChocoSpace.u(266))
        }
        .frame(width: ChocoTheme.archiveWidth)
        .frame(maxHeight: .infinity)
        .background(theme.sidebar)
        .foregroundStyle(ChocoTheme.text)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library-sidebar")
        .task { await focusSearchAfterMount() }
        .onChange(of: search) { _, _ in clearSelection() }
        .onChange(of: scope) { _, _ in clearSelection() }
        .onChange(of: page) { _, new in
            clearSelection(); pageSearch = ""
            if new == .archive { Task { await focusSearchAfterMount() } }
        }
        .onChange(of: model.state.archive) { _, entries in
            if let selectedEntryID, !entries.contains(where: { $0.id == selectedEntryID }) { clearSelection() }
        }
    }

    private var libraryRail: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 650
            let height: CGFloat = compact ? 44 : 56
            VStack(spacing: compact ? 10 : 18) {
                pageButton(.media, height: height)
                pageButton(.downloads, height: height)
                pageButton(.easels, height: height)
                Button { model.showsArchive = false } label: {
                    railLabel("Space", icon: "e2dfa", height: height)
                }
                .buttonStyle(.plain)
                .help("現在のSpaceに戻る")
                .accessibilityIdentifier("library-spaces")
                pageButton(.boosts, height: height)
                pageButton(.archive, height: height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, ChocoSpace.u(52))
            .padding(.bottom, ChocoSpace.u(125))
            .overlay(alignment: .bottom) {
                HStack(spacing: 0) {
                    Button { model.showsArchive = false } label: {
                        DesignIcon("687ab", size: 16).opacity(0.7).frame(width: ChocoSpace.u(26), height: ChocoSpace.u(26))
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
                        SpaceIcon(model.selectedSpace?.icon ?? "", size: 16).opacity(0.7).frame(width: ChocoSpace.u(26), height: ChocoSpace.u(26))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Spaceを選んで戻る")
                    .accessibilityLabel("Spaceを選択")
                    .accessibilityIdentifier("library-space-picker")
                }
                .padding(.horizontal, ChocoSpace.md)
                .padding(.bottom, ChocoSpace.u(10))
            }
        }
    }

    private func pageButton(_ target: LibraryPage, height: CGFloat) -> some View {
        Button {
            if page == target, target == .archive { searchFocused = true } else { page = target }
        } label: {
            railLabel(target.feature, icon: target.icon, active: page == target, height: height)
        }
        .buttonStyle(.plain)
        .help(target == .archive ? "閉じたタブを検索" : target.feature)
        .accessibilityAddTraits(page == target ? .isSelected : [])
        .accessibilityIdentifier("library-\(target.rawValue)")
    }

    private func railLabel(_ title: String, icon: String, active: Bool = false, height: CGFloat) -> some View {
        VStack(spacing: ChocoSpace.u(5)) {
            DesignIcon(icon, size: 20).opacity(active ? 0.95 : 0.7)
            Text(title)
                .font(ChocoTheme.font(10, weight: .semibold))
                .foregroundStyle(active ? ChocoTheme.text : ChocoTheme.secondary)
                .lineLimit(1)
        }
        .frame(width: ChocoSpace.u(70), height: height)
        .background(active ? ChocoTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var libraryPanel: some View {
        if page == .archive { archivePanel } else { placeholderPanel(page) }
    }

    /// Figma Media / Downloads / Easels: header row, then the 220pt empty state at 53% of the panel height.
    private func placeholderPanel(_ target: LibraryPage) -> some View {
        VStack(spacing: ChocoSpace.xs) {
            HStack(spacing: ChocoSpace.u(6)) {
                searchField(prompt: target.searchPrompt, text: $pageSearch, identifier: "library-search")
                if target.hasFilter {
                    Button { UnsupportedNotice.shared.show(target.feature) } label: {
                        HStack(spacing: ChocoSpace.xs) {
                            DesignIcon("03c3d", size: 14).opacity(0.7)
                            Text("絞込").font(ChocoTheme.font(13, weight: .medium)).foregroundStyle(ChocoTheme.secondary)
                        }
                        .padding(.leading, ChocoSpace.u(6)).padding(.trailing, ChocoSpace.u(8))
                        .frame(height: ChocoSpace.u(26))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(ChocoPressStyle(radius: 6))
                    .accessibilityIdentifier("library-filter")
                }
            }
            GeometryReader { geometry in
                VStack(spacing: ChocoSpace.u(8)) {
                    DesignIcon(target.icon, size: 32).opacity(0.55)
                    Text("まだ何もありません").font(ChocoTheme.font(13, weight: .semibold))
                    Text(target.emptyDescription).font(ChocoTheme.font(11)).foregroundStyle(ChocoTheme.secondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    Button { UnsupportedNotice.shared.show(target.feature) } label: {
                        Text("詳しく見る").font(ChocoTheme.font(11, weight: .semibold))
                            .padding(.horizontal, ChocoSpace.u(10)).padding(.vertical, ChocoSpace.u(4))
                            .background(theme.field, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(ChocoPressStyle(radius: 6))
                    .accessibilityIdentifier("library-learn-more")
                }
                .frame(width: ChocoSpace.u(220))
                .frame(maxWidth: .infinity)
                // Figma 20:2192 sits at y=600 of a 1127pt panel (header already consumed above).
                .padding(.top, max(ChocoSpace.u(24), geometry.size.height * 0.532 - ChocoSpace.u(54)) )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("library-empty-\(target.rawValue)")
        }
        .padding(.horizontal, ChocoSpace.u(8))
        .padding(.top, ChocoSpace.u(10))
        .padding(.bottom, ChocoSpace.u(8))
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var archivePanel: some View {
        VStack(spacing: ChocoSpace.xs) {
            searchHeader
            if visibleEntries.isEmpty {
                emptyState
            } else {
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ChocoSpace.xs) {
                            ForEach(dayGroups) { group in
                                Text(dayLabel(group.day))
                                    .font(ChocoTheme.font(11, weight: .semibold))
                                    .foregroundStyle(ChocoTheme.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, ChocoSpace.u(8))
                                    .frame(height: ChocoSpace.u(24))
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
                        }.padding(.top, ChocoSpace.u(8))
                    }
                    .scrollIndicators(.never)
                    .onChange(of: selectedEntryID) { _, id in
                        if let id { reader.scrollTo(id) }
                    }
                }
            }
        }
        .padding(.horizontal, ChocoSpace.u(8))
        .padding(.top, ChocoSpace.u(10))
        .padding(.bottom, ChocoSpace.u(8))
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var searchHeader: some View {
        HStack(spacing: ChocoSpace.u(6)) {
            searchField(prompt: "アーカイブを検索", text: $search, identifier: "library-search", archive: true)
            Menu {
                Picker("表示するSpace", selection: $scope) {
                    ForEach(ArchiveScope.allCases) { item in Text(item.label).tag(item) }
                }
            } label: {
                HStack(spacing: ChocoSpace.xs) {
                    DesignIcon("03c3d", size: 14).opacity(0.7)
                    Text("絞込").font(ChocoTheme.font(13, weight: .medium))
                        .foregroundStyle(ChocoTheme.secondary)
                }
                .padding(.leading, ChocoSpace.u(6)).padding(.trailing, ChocoSpace.u(8))
                .frame(height: ChocoSpace.u(26))
                .background(scope == .currentSpace ? theme.field : Color.clear, in: RoundedRectangle(cornerRadius: 6))
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

    private func searchField(prompt: String, text: Binding<String>, identifier: String, archive: Bool = false) -> some View {
        HStack(spacing: ChocoSpace.u(6)) {
            DesignIcon("9d9ff", size: 13).opacity(0.6)
            TextField(prompt, text: text, prompt: Text(prompt).foregroundStyle(ChocoTheme.tertiary))
                .font(ChocoTheme.font(13))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .accessibilityIdentifier(identifier)
                .onKeyPress(.downArrow) {
                    guard archive, !hasMarkedText, let first = visibleEntries.first else { return .ignored }
                    selectedEntryID = first.id; focusedEntryID = first.id; return .handled
                }
                .onKeyPress(.escape) {
                    guard !hasMarkedText else { return .ignored }
                    if text.wrappedValue.isEmpty { model.showsArchive = false } else { text.wrappedValue = "" }
                    return .handled
                }
        }
        .padding(.horizontal, ChocoSpace.u(8))
        .frame(height: ChocoSpace.u(26))
        .background(theme.field, in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(spacing: ChocoSpace.u(10)) {
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
        .padding(.horizontal, ChocoSpace.md).padding(.top, ChocoSpace.u(36))
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
        HStack(spacing: ChocoSpace.u(10)) {
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
                    .padding(.horizontal, ChocoSpace.xs).frame(height: ChocoSpace.u(24))
                    .background(hovering || selected ? ChocoTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .opacity(hovering || selected ? 1 : 0.65)
            .help("このタブを復元")
            .accessibilityLabel("\(entry.tab.displayTitle)を復元")
            .accessibilityIdentifier("restore-archive-\(entry.id)")
        }
        .padding(.leading, ChocoSpace.u(8)).padding(.trailing, ChocoSpace.u(6))
        .frame(height: ChocoSpace.u(44))
        .background(hovering || selected ? ChocoTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
        .help(entry.tab.url)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(entry.tab.displayTitle)、\(displayAddress)")
        .accessibilityIdentifier("archive-row-\(entry.id)")
    }
}
