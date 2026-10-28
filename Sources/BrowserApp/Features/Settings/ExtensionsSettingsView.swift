import AppKit
import BrowserRuntime
import SwiftUI
import WebKit

struct ExtensionsSettingsView: View {
    @Bindable var model: AppModel
    @State private var storeReference = ""
    @State private var isWorking = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var pendingRemoval: InstalledExtension?

    private var manager: ExtensionManager { model.extensions }

    var body: some View {
        VStack(alignment: .leading, spacing: ChocoSpace.u(14)) {
            Text("Chrome拡張機能（Manifest V2 / V3）を追加できます。拡張機能はすべてのProfileで有効になり、ページの表示や通信に干渉できます。信頼できるものだけを追加してください。")
                .font(ChocoTheme.font(12)).foregroundStyle(SettingsStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            installedList
            HStack(spacing: ChocoSpace.u(6)) {
                Button("フォルダ・ZIP・CRXから追加…") { chooseFile() }.buttonStyle(SettingsButtonStyle())
                    .disabled(isWorking).accessibilityIdentifier("extensions-add-file")
                Spacer(minLength: 0)
            }
            HStack(spacing: ChocoSpace.u(6)) {
                TextField("ChromeウェブストアのURLまたは拡張機能ID", text: $storeReference)
                    .textFieldStyle(.plain).padding(.horizontal, ChocoSpace.u(8)).frame(height: ChocoSpace.u(24))
                    .background(SettingsStyle.field, in: RoundedRectangle(cornerRadius: 6))
                    .onSubmit { addFromStore() }
                    .accessibilityIdentifier("extensions-store-field")
                Button("ストアから追加") { addFromStore() }.buttonStyle(SettingsButtonStyle())
                    .disabled(isWorking || storeReference.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("extensions-add-store")
            }
            if isWorking { ProgressView().controlSize(.small) }
            if let message {
                Text(message).font(ChocoTheme.font(11))
                    .foregroundStyle(messageIsError ? Color(hex: "FF6B60") : SettingsStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            Text("ChromeウェブストアのCRXは署名を検証せずに読み込みます。WebKitが未対応のChrome APIを使う拡張機能は一部の機能が動かないことがあります。拡張機能のボタンは、サイトの操作パネルに表示されます。")
                .font(ChocoTheme.font(11)).foregroundStyle(SettingsStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, ChocoSpace.u(64)).padding(.top, ChocoSpace.u(20))
        .confirmationDialog("拡張機能を削除しますか？", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                            presenting: pendingRemoval) { item in
            Button("「\(item.name)」を削除", role: .destructive) { Task { await manager.remove(item.id) } }
        } message: { _ in Text("拡張機能が保存したデータも削除されます。") }
    }

    private var installedList: some View {
        VStack(spacing: 0) {
            if manager.installed.isEmpty {
                Text("追加された拡張機能はありません").foregroundStyle(SettingsStyle.secondary)
                    .frame(maxWidth: .infinity, minHeight: ChocoSpace.u(80))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(manager.installed) { item in
                            row(item, divider: item.id != manager.installed.last?.id)
                        }
                    }.padding(.horizontal, ChocoSpace.u(10))
                }.frame(maxHeight: ChocoSpace.u(300))
            }
        }
        .background(SettingsStyle.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
        .accessibilityIdentifier("extensions-list")
    }

    private func row(_ item: InstalledExtension, divider: Bool) -> some View {
        SettingsRow(item.name, divider: divider) {
            HStack(spacing: ChocoSpace.u(8)) {
                if let error = manager.loadErrors[item.id] {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(hex: "FFB340")).help(error)
                }
                Text(item.version).font(ChocoTheme.font(11)).foregroundStyle(SettingsStyle.secondary)
                Toggle(item.name, isOn: Binding(get: { item.isEnabled }, set: { manager.setEnabled(item.id, $0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                Button { pendingRemoval = item } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(SettingsStyle.secondary).help("削除")
                    .accessibilityLabel("\(item.name)を削除")
            }
        }
    }

    // MARK: Installing

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = "拡張機能のフォルダ（manifest.jsonがあるもの）、ZIP、またはCRXファイルを選びます。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        run { try await manager.stage(fileURL: url) }
    }

    private func addFromStore() {
        let reference = storeReference
        guard !reference.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        run { try await manager.stage(storeReference: reference) }
    }

    private func run(_ stage: @escaping @MainActor () async throws -> StagedExtension) {
        isWorking = true
        message = nil
        Task {
            defer { isWorking = false }
            do {
                let staged = try await stage()
                guard model.extensionHost.confirmInstall(staged) else { manager.discard(staged); return }
                let item = try await manager.commit(staged)
                storeReference = ""
                if let error = manager.loadErrors[item.id] {
                    show("「\(item.name)」を追加しましたが、読み込めませんでした。\(error)", isError: true)
                } else {
                    show("「\(item.name)」を追加しました。", isError: false)
                }
            } catch {
                show(error.localizedDescription, isError: true)
            }
        }
    }

    private func show(_ text: String, isError: Bool) { message = text; messageIsError = isError }
}
