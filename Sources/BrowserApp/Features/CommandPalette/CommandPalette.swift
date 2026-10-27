import AppKit
import BrowserCore
import BrowserRuntime
import SwiftUI

enum CommandMode { case newTab, navigate }

struct CommandPalette: View {
    @Bindable var model: AppModel
    @FocusState private var focused: Bool
    @State private var selection = 0
    @State private var showsInputHelp = false
    @State private var suggestions = SearchSuggestions.empty
    @State private var suggestionsQuery = ""

    private enum Row: Identifiable {
        case tab(BrowserTab, String), archived(ArchiveEntry, String), navigate
        case suggestion(String), link(SearchSuggestions.Link), command(String, String, Command)
        var id: String {
            switch self {
            case .tab(let tab, _): return tab.id.uuidString
            case .archived(let entry, _): return "archived-\(entry.id)"
            case .navigate: return "navigate"
            case .suggestion(let text): return "suggestion-\(text)"
            case .link(let link): return "link-\(link.url.absoluteString)"
            case .command(let title, _, _): return title
            }
        }
    }
    private enum Command { case newTab, archive, restore, sidebar, clear, folder, space }
    /// The Figma palette always shows five rows (`visibleRows`). With text the order is: tabs opened before
    /// (open tabs, then archived), the typed text and Google's related searches, then Google's top links, then
    /// matching commands. When fewer than five rows exist, the remaining slots are filled with other tabs, then other
    /// commands, so the list never collapses. `tabMatchCount` tells filler apart from real tab matches.
    private static let visibleRows = 5
    /// Keeps the typed text and Google's rows within reach of the five visible slots.
    private static let tabLimit = 3
    private var query: String { model.commandText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var rowSet: (rows: [Row], tabMatchCount: Int) {
        let query = query
        func matches(_ text: String) -> Bool { query.isEmpty || text.localizedCaseInsensitiveContains(query) }
        let ordered = model.state.tabs.sorted { lhs, rhs in
            let leftHere = lhs.spaceID == model.state.selectedSpaceID
            let rightHere = rhs.spaceID == model.state.selectedSpaceID
            return leftHere != rightHere ? leftHere : false
        }
        func spaceName(_ tab: BrowserTab) -> String { model.state.spaces.first(where: { $0.id == tab.spaceID })?.name ?? "" }
        let commands: [(String, String, Command)] = [
            ("新しいタブ", "plus", .newTab), ("アーカイブを開く", "archivebox", .archive),
            ("閉じたタブを復元", "arrow.uturn.backward", .restore), ("サイドバーを切り替える", "sidebar.left", .sidebar),
            ("Todayをすべて閉じる", "xmark", .clear), ("フォルダを作成", "folder.badge.plus", .folder),
            ("Spaceを作成", "plus.square", .space)
        ]
        let tabLimit = query.isEmpty ? 7 : Self.tabLimit
        let matchedTabs = ordered.filter { matches("\($0.displayTitle) \($0.url)") }.prefix(tabLimit)
        // Archived tabs are pages opened before; they only appear once the person types, and never twice.
        var seenURLs = Set(model.state.tabs.map(\.url))
        let matchedArchive = query.isEmpty ? [] : model.state.archive.filter { entry in
            matches("\(entry.tab.displayTitle) \(entry.tab.url)") && seenURLs.insert(entry.tab.url).inserted
        }.prefix(max(0, tabLimit - matchedTabs.count))
        let matchedCommands = commands.filter { matches($0.0) }.prefix(5)
        var rows = matchedTabs.map { Row.tab($0, spaceName($0)) }
            + matchedArchive.map { Row.archived($0, spaceName($0.tab)) }
        let tabMatchCount = rows.count
        if showsNavigationResult { rows.append(.navigate) }
        let suggestions = currentSuggestions
        rows += suggestions.queries.map { Row.suggestion($0) } + suggestions.links.map { Row.link($0) }
        rows += matchedCommands.map { Row.command($0.0, $0.1, $0.2) }
        var missing = Self.visibleRows - rows.count
        if missing > 0 {
            let used = Set(matchedTabs.map(\.id))
            let spareTabs = ordered.filter { !used.contains($0.id) }.prefix(missing)
            rows += spareTabs.map { Row.tab($0, spaceName($0)) }
            missing -= spareTabs.count
        }
        if missing > 0 {
            let used = Set(matchedCommands.map(\.0))
            rows += commands.filter { !used.contains($0.0) }.prefix(missing).map { Row.command($0.0, $0.1, $0.2) }
        }
        return (rows, tabMatchCount)
    }
    private var rows: [Row] { rowSet.rows }
    private var navigateIndex: Int { rows.firstIndex { if case .navigate = $0 { true } else { false } } ?? 0 }

    private var showsNavigationResult: Bool { model.commandMode == .navigate || !query.isEmpty }
    /// Cmd+L keeps navigating the typed text; otherwise the first real tab match wins. Filler rows are never
    /// preselected: with no real match, Return still searches or opens the typed text.
    private var preferredSelection: Int {
        guard showsNavigationResult else { return 0 }
        return model.commandMode == .navigate || rowSet.tabMatchCount == 0 ? navigateIndex : 0
    }

    private var currentSuggestions: SearchSuggestions { suggestionsQuery == query ? suggestions : .empty }

    var body: some View {
        VStack(spacing: 0) {
            input
            if let error = model.commandError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(ChocoTheme.font(11)).foregroundStyle(Color(red: 1, green: 0.67, blue: 0.63))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ChocoSpace.u(18)).padding(.bottom, ChocoSpace.u(10))
                    .accessibilityIdentifier("command-error")
            }
            Rectangle().fill(Color(hex: "353535")).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            rowButton(row, index: index)
                                .id(index)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(height: CGFloat(Self.visibleRows) * (ChocoSpace.u(42) + 1) - 1)
                .onChange(of: selection) { _, value in proxy.scrollTo(value, anchor: .center) }
            }
            .padding(.horizontal, ChocoSpace.u(6)).padding(.top, ChocoSpace.u(6)).padding(.bottom, ChocoSpace.u(8))
        }
        .padding(1)
        .frame(width: ChocoSpace.u(668))
        .foregroundStyle(ChocoTheme.text)
        .background(ChocoTheme.command, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ChocoTheme.commandBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("command-palette")
        .onAppear {
            selection = preferredSelection
        }
        .task(id: model.commandMode == .navigate) { await focusCommandInput() }
        .onChange(of: model.commandText) { _, value in
            model.commandError = nil
            // Cmd+L keeps navigation in the current Profile; switching to a
            // suggestion in another Space always requires an explicit choice.
            selection = preferredSelection
        }
        .onChange(of: rows.count) { _, count in selection = min(selection, max(0, count - 1)) }
        .task(id: query) { await loadSuggestions(for: query) }
        .onChange(of: model.commandMode == .navigate) { _, _ in selection = preferredSelection }
    }

    private var input: some View {
        HStack(spacing: ChocoSpace.u(10)) {
            DesignIcon("9d9ff", size: 14).opacity(0.8)
            TextField("検索、またはURLを入力…", text: $model.commandText,
                      prompt: Text("検索、またはURLを入力…").foregroundStyle(Color(hex: "8C8C8C")))
                .font(ChocoTheme.font(17, weight: .medium))
                .textFieldStyle(.plain).focused($focused)
                .foregroundStyle(Color(hex: "F2F2F2"))
                .tint(.white)
                .accessibilityIdentifier("command-input")
                .onSubmit { submitInput() }
                .onKeyPress(.downArrow) {
                    guard !hasMarkedText else { return .ignored }
                    selection = min(max(0, rows.count - 1), selection + 1); return .handled
                }
                .onKeyPress(.upArrow) {
                    guard !hasMarkedText else { return .ignored }
                    selection = max(0, selection - 1); return .handled
                }
                .onKeyPress(.escape) {
                    guard !hasMarkedText else { return .ignored }
                    model.commandMode = nil; return .handled
                }
            Button { showsInputHelp.toggle() } label: {
                DesignIcon("832a0", size: 16).opacity(0.85)
                    .frame(width: ChocoSpace.u(22), height: ChocoSpace.u(22)).background(.black, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("コマンドバーの使い方")
            .popover(isPresented: $showsInputHelp, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: ChocoSpace.sm) {
                    Text("URL・検索・タブ・コマンド").font(ChocoTheme.font(13, weight: .semibold))
                    Text("↑↓で選択、Returnで実行、Escapeで閉じます。")
                    Text("⌘Lは現在のページを開き、⌘Tは新しいタブを作成します。")
                    Text("別のSpaceのタブへの切り替えは、候補から選択してください。")
                }.font(ChocoTheme.font(11)).padding(ChocoSpace.lg).frame(width: ChocoSpace.u(300), alignment: .leading)
            }
        }
        .padding(.leading, ChocoSpace.u(18)).padding(.trailing, ChocoSpace.u(14)).frame(height: ChocoSpace.u(52))
    }

    @ViewBuilder private func rowButton(_ row: Row, index: Int) -> some View {
        Button { activate(row) } label: {
            switch row {
            case .tab(let tab, let space):
                resultRow(title: tab.displayTitle,
                          action: tab.spaceID == model.state.selectedSpaceID ? "タブに切り替え" : nil,
                          selected: selection == index) {
                    SiteIcon(url: tab.url, size: 16)
                }
                .help("開いているタブ · \(space)\n\(tab.url)")
            case .archived(let entry, let space):
                resultRow(title: entry.tab.displayTitle, action: nil, selected: selection == index) {
                    SiteIcon(url: entry.tab.url, size: 16)
                }
                .help("アーカイブ · \(space)\n\(entry.tab.url)")
            case .navigate:
                resultRow(
                    title: model.commandText.isEmpty ? "検索またはURLを入力" : model.commandText,
                    action: nil,
                    selected: selection == index
                ) { DesignIcon("9d9ff", size: 16) }
                .accessibilityIdentifier("command-navigate")
            case .suggestion(let text):
                resultRow(title: text, action: nil, selected: selection == index) {
                    Image(systemName: "magnifyingglass").font(.system(size: ChocoSpace.u(13), weight: .medium))
                        .frame(width: ChocoSpace.u(16), height: ChocoSpace.u(16))
                }
            case .link(let link):
                resultRow(title: link.title, action: nil, selected: selection == index) {
                    SiteIcon(url: link.url.absoluteString, size: 16)
                }
                .help(link.url.absoluteString)
            case .command(let title, let icon, _):
                resultRow(title: title, action: "実行", selected: selection == index) {
                    commandIcon(icon)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled({ if case .navigate = row { return query.isEmpty } else { return false } }())
    }

    @ViewBuilder private func commandIcon(_ symbol: String) -> some View {
        switch symbol {
        case "plus", "plus.square": DesignIcon("77a3c", size: 16)
        case "archivebox": DesignIcon("61b66", size: 16)
        case "sidebar.left": DesignIcon("de36e", size: 16)
        default: Image(systemName: symbol).font(.system(size: ChocoSpace.u(14))).frame(width: ChocoSpace.u(16), height: ChocoSpace.u(16))
        }
    }

    /// `action` is the right-hand label and Return badge; only current-Space tabs and commands show it.
    private func resultRow<Icon: View>(title: String, action: String?, selected: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: ChocoSpace.u(10)) {
            icon().frame(width: ChocoSpace.u(16), height: ChocoSpace.u(16))
            Text(title).font(ChocoTheme.font(13, weight: .semibold)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                HStack(spacing: ChocoSpace.sm) {
                    Text(action).font(ChocoTheme.font(12, weight: .semibold))
                        .foregroundStyle(selected ? Color(hex: "F2F2F2") : Color(hex: "6E6E6E"))
                        .lineLimit(1).frame(maxWidth: ChocoSpace.u(180), alignment: .trailing)
                    DesignIcon(selected ? "85a6a" : "caa3a", size: 14)
                        .opacity(selected ? 1 : 0.6)
                        .frame(width: ChocoSpace.u(22), height: ChocoSpace.u(22))
                        .background(selected ? .white : Color(hex: "2E2E2F"), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.leading, ChocoSpace.u(10)).padding(.trailing, ChocoSpace.u(6)).frame(height: ChocoSpace.u(42))
        .foregroundStyle(Color(hex: "F2F2F2"))
        .background(selected ? ChocoTheme.commandSelected : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var hasMarkedText: Bool { (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() ?? false }

    @MainActor private func focusCommandInput() async {
        let initialText = model.commandText
        let selectsAddress = model.commandMode == .navigate
        // Menu key equivalents restore their previous responder after onAppear.
        // Wait until the overlay is mounted before requesting its field editor.
        await Task.yield()
        do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
        guard model.commandMode != nil, !Task.isCancelled, !showsInputHelp else { return }
        focused = true
        // FocusState applies on the next SwiftUI update. Select the URL only
        // after an actual native field editor becomes first responder, and never
        // replace input the person has already started typing or composing.
        for _ in 0..<5 {
            await Task.yield()
            guard model.commandMode != nil, !Task.isCancelled, !showsInputHelp else { return }
            if let editor = (model.browserWindow ?? NSApp.keyWindow)?.firstResponder as? NSTextView,
               editor.isFieldEditor {
                if selectsAddress, model.commandText == initialText, !editor.hasMarkedText() {
                    editor.selectAll(nil)
                }
                return
            }
            do { try await Task.sleep(for: .milliseconds(10)) } catch { return }
        }
    }

    /// Debounced so each keystroke does not hit the network; only plain search text is ever sent (`isSearchText`).
    @MainActor private func loadSuggestions(for query: String) async {
        guard SearchSuggestionService.isSearchText(query) else { suggestions = .empty; suggestionsQuery = ""; return }
        do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
        let result = await model.suggestionService.suggestions(for: query)
        guard !Task.isCancelled else { return }
        suggestions = result
        suggestionsQuery = query
    }

    private func submitInput() {
        guard !hasMarkedText else { return }
        if rows.indices.contains(selection) { activate(rows[selection]) }
        else { model.open(model.commandText, newTab: model.commandMode == .newTab) }
    }

    private func activate(_ row: Row) {
        let newTab = model.commandMode == .newTab
        switch row {
        case .tab(let tab, _): model.select(tab)
        case .archived(let entry, _):
            model.commandMode = nil
            model.send(.restoreArchive(entry.id))
        case .navigate: model.open(model.commandText, newTab: newTab)
        case .suggestion(let text):
            if let url = AddressResolver.searchURL(for: text) { model.open(url, newTab: newTab) }
        case .link(let link): model.open(link.url, newTab: newTab)
        case .command(_, _, let command):
            model.commandMode = nil
            switch command {
            case .newTab: model.showCommand(.newTab)
            case .archive: model.showsArchive = true
            case .restore: model.send(.restoreLatestArchive)
            case .sidebar: model.send(.toggleSidebar)
            case .clear: model.send(.clearToday)
            case .folder: model.editor = .folder(nil)
            case .space: model.editor = .space(nil)
            }
        }
    }
}
