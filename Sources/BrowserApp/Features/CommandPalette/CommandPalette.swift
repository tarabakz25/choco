import AppKit
import BrowserCore
import SwiftUI

enum CommandMode { case newTab, navigate }

struct CommandPalette: View {
    @Bindable var model: AppModel
    @FocusState private var focused: Bool
    @State private var selection = 0
    @State private var showsInputHelp = false

    private enum Result: Identifiable {
        case tab(BrowserTab, String), command(String, String, Command)
        var id: String {
            switch self { case .tab(let tab, _): return tab.id.uuidString; case .command(let title, _, _): return title }
        }
    }
    private enum Command { case newTab, archive, restore, sidebar, clear, folder, space }
    private var results: [Result] {
        let query = model.commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tabs = model.state.tabs.filter {
            query.isEmpty || "\($0.displayTitle) \($0.url)".localizedCaseInsensitiveContains(query)
        }.sorted { lhs, rhs in
            let leftHere = lhs.spaceID == model.state.selectedSpaceID
            let rightHere = rhs.spaceID == model.state.selectedSpaceID
            return leftHere != rightHere ? leftHere : false
        }.prefix(7).map { tab in
            Result.tab(tab, model.state.spaces.first(where: { $0.id == tab.spaceID })?.name ?? "")
        }
        let commands: [(String, String, Command)] = [
            ("新しいタブ", "plus", .newTab), ("アーカイブを開く", "archivebox", .archive),
            ("閉じたタブを復元", "arrow.uturn.backward", .restore), ("サイドバーを切り替える", "sidebar.left", .sidebar),
            ("Todayをすべて閉じる", "xmark", .clear), ("フォルダを作成", "folder.badge.plus", .folder),
            ("Spaceを作成", "plus.square", .space)
        ]
        return tabs + commands.filter { query.isEmpty || $0.0.localizedCaseInsensitiveContains(query) }.prefix(5).map { .command($0.0, $0.1, $0.2) }
    }

    private var showsNavigationResult: Bool {
        model.commandMode == .navigate || !model.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var firstSelection: Int { showsNavigationResult || results.isEmpty ? 0 : 1 }
    private var preferredSelection: Int { model.commandMode == .navigate || results.isEmpty ? 0 : 1 }
    private var renderedResultCount: Int { results.count + (showsNavigationResult ? 1 : 0) }

    var body: some View {
        VStack(spacing: 0) {
            input
            if let error = model.commandError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(ChocoTheme.font(11)).foregroundStyle(Color(red: 1, green: 0.67, blue: 0.63))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.bottom, 10)
                    .accessibilityIdentifier("command-error")
            }
            Rectangle().fill(Color(hex: "353535")).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 1) {
                        if showsNavigationResult {
                            Button { model.open(model.commandText, newTab: model.commandMode == .newTab) } label: {
                                resultRow(
                                    title: model.commandText.isEmpty ? "検索またはURLを入力" : model.commandText,
                                    action: model.commandMode == .newTab ? "新しいタブで開く" : "現在のタブで開く",
                                    selected: selection == 0
                                ) { DesignIcon("9d9ff", size: 16) }
                            }
                            .buttonStyle(.plain)
                            .disabled(model.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("command-navigate")
                            .id(0)
                        }
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            resultButton(result, index: index)
                                .id(index + 1)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(height: min(max(0, CGFloat(renderedResultCount) * 43 - 1), 214))
                .onChange(of: selection) { _, value in proxy.scrollTo(value, anchor: .center) }
            }
            .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 8)
        }
        .padding(1)
        .frame(width: 668)
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
        .onChange(of: results.count) { _, count in selection = min(max(firstSelection, selection), count) }
        .onChange(of: model.commandMode == .navigate) { _, _ in selection = preferredSelection }
    }

    private var input: some View {
        HStack(spacing: 10) {
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
                    selection = min(results.count, selection + 1); return .handled
                }
                .onKeyPress(.upArrow) {
                    guard !hasMarkedText else { return .ignored }
                    selection = max(firstSelection, selection - 1); return .handled
                }
                .onKeyPress(.escape) {
                    guard !hasMarkedText else { return .ignored }
                    model.commandMode = nil; return .handled
                }
            Button { showsInputHelp.toggle() } label: {
                DesignIcon("832a0", size: 16).opacity(0.85)
                    .frame(width: 22, height: 22).background(.black, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("コマンドバーの使い方")
            .popover(isPresented: $showsInputHelp, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: ChocoSpace.sm) {
                    Text("URL・検索・タブ・コマンド").font(ChocoTheme.font(13, weight: .semibold))
                    Text("↑↓で選択、Returnで実行、Escapeで閉じます。")
                    Text("⌘Lは現在のページを開き、⌘Tは新しいタブを作成します。")
                    Text("別のSpaceのタブへの切り替えは、候補から選択してください。")
                }.font(ChocoTheme.font(11)).padding(ChocoSpace.lg).frame(width: 300, alignment: .leading)
            }
        }
        .padding(.leading, 18).padding(.trailing, 14).frame(height: 52)
    }

    @ViewBuilder private func resultButton(_ result: Result, index: Int) -> some View {
        Button { activate(result) } label: {
            switch result {
            case .tab(let tab, let space):
                resultRow(title: tab.displayTitle,
                          action: tab.spaceID == model.state.selectedSpaceID ? "タブに切り替え" : "切り替え · \(space)",
                          selected: selection == index + 1) {
                    SiteIcon(url: tab.url, size: 16)
                }
                .help("開いているタブ · \(space)\n\(tab.url)")
            case .command(let title, let icon, _):
                resultRow(title: title, action: "実行", selected: selection == index + 1) {
                    commandIcon(icon)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func commandIcon(_ symbol: String) -> some View {
        switch symbol {
        case "plus", "plus.square": DesignIcon("77a3c", size: 16)
        case "archivebox": DesignIcon("61b66", size: 16)
        case "sidebar.left": DesignIcon("de36e", size: 16)
        default: Image(systemName: symbol).font(.system(size: 14)).frame(width: 16, height: 16)
        }
    }

    private func resultRow<Icon: View>(title: String, action: String, selected: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 10) {
            icon().frame(width: 16, height: 16)
            Text(title).font(ChocoTheme.font(13, weight: .semibold)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: ChocoSpace.sm) {
                Text(action).font(ChocoTheme.font(12, weight: .semibold))
                    .foregroundStyle(selected ? Color(hex: "F2F2F2") : Color(hex: "6E6E6E"))
                    .lineLimit(1).frame(maxWidth: 180, alignment: .trailing)
                DesignIcon(selected ? "85a6a" : "caa3a", size: 14)
                    .opacity(selected ? 1 : 0.6)
                    .frame(width: 22, height: 22)
                    .background(selected ? .white : Color(hex: "2E2E2F"), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.leading, 10).padding(.trailing, 6).frame(height: 42)
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

    private func submitInput() {
        guard !hasMarkedText else { return }
        if selection > 0, results.indices.contains(selection - 1) { activate(results[selection - 1]) }
        else { model.open(model.commandText, newTab: model.commandMode == .newTab) }
    }

    private func activate(_ result: Result) {
        switch result {
        case .tab(let tab, _): model.select(tab)
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
