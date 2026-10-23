import AppKit
import BrowserCore
import SwiftUI

struct CommandPalette: View {
    @Bindable var model: AppModel
    @FocusState private var focused: Bool
    @State private var selection = 0

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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.title3).foregroundStyle(.secondary)
                TextField("検索、URL、タブ、コマンド", text: $model.commandText)
                    .font(.system(size: 19)).textFieldStyle(.plain).focused($focused)
                    .accessibilityIdentifier("command-input")
                    .onSubmit { submitInput() }
                    .onKeyPress(.downArrow) {
                        guard !hasMarkedText else { return .ignored }
                        selection = min(results.count, selection + 1); return .handled
                    }
                    .onKeyPress(.upArrow) {
                        guard !hasMarkedText else { return .ignored }
                        selection = max(0, selection - 1); return .handled
                    }
                    .onKeyPress(.escape) {
                        guard !hasMarkedText else { return .ignored }
                        model.commandMode = nil; return .handled
                    }
                Button { model.commandMode = nil } label: { Text("esc").font(.caption).foregroundStyle(.secondary) }.buttonStyle(.plain)
            }.padding(22)
            if let error = model.commandError {
                Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red).padding(.horizontal, 22).padding(.bottom, 12)
            }
            Divider()
            VStack(spacing: 3) {
                Button { model.open(model.commandText, newTab: model.commandMode == .newTab) } label: {
                    resultRow(title: model.commandText.isEmpty ? "検索またはURLを入力" : model.commandText,
                              subtitle: model.commandMode == .newTab ? "新しいタブで開く" : "現在のタブで開く",
                              icon: "arrow.up.right", selected: selection == 0)
                }.buttonStyle(.plain).disabled(model.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    Button { activate(result) } label: {
                        switch result {
                        case .tab(let tab, let space):
                            resultRow(title: tab.displayTitle, subtitle: "開いているタブ · \(space)", icon: "rectangle.on.rectangle", selected: selection == index + 1)
                        case .command(let title, let icon, _):
                            resultRow(title: title, subtitle: "コマンド", icon: icon, selected: selection == index + 1)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(8)
            HStack {
                Text("↑↓ 選択   ↩ 実行").font(.caption2)
                Spacer()
                Text("\(model.selectedSpace?.icon ?? "") \(model.selectedSpace?.name ?? "")").font(.caption2)
            }.foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 10)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.18), radius: 28, y: 12)
        .onAppear {
            focused = true
            if model.commandMode == .navigate {
                Task { @MainActor in
                    await Task.yield()
                    (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
                }
            }
        }
        .onChange(of: model.commandText) { _, value in
            model.commandError = nil
            // Cmd+L edits this page in its current Profile; other tabs remain explicit suggestions.
            // Auto-selecting an identical URL in another Space would silently change login context.
            selection = model.commandMode == .newTab && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !results.isEmpty ? 1 : 0
        }
        .onChange(of: results.count) { _, count in selection = min(selection, count) }
    }

    private var hasMarkedText: Bool { (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() ?? false }

    private func resultRow(title: String, subtitle: String, icon: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).frame(width: 25).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if selected { Image(systemName: "return").font(.caption).foregroundStyle(.secondary) }
        }.padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? model.tint.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 9))
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
