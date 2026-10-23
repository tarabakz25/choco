import AppKit
import BrowserCore
import SwiftUI

@main @MainActor struct ChocoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        Window("choco", id: "browser") {
            BrowserWindow(model: model)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .onAppear { delegate.model = model; delegate.installKeyboardRouting(); NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新しいタブ") { model.showCommand(.newTab) }.keyboardShortcut("t")
                Button("アドレスを入力") { model.showCommand(.navigate) }.keyboardShortcut("l")
            }
            CommandGroup(replacing: .saveItem) {
                Button("サイドバーを切り替える") { model.send(.toggleSidebar) }.keyboardShortcut("s")
            }
            CommandGroup(after: .toolbar) {
                Button("再読み込み") { model.activeSession?.reload() }.keyboardShortcut("r")
                Button("前のページ") { model.activeSession?.goBack() }.keyboardShortcut("[", modifiers: .command)
                Button("次のページ") { model.activeSession?.goForward() }.keyboardShortcut("]", modifiers: .command)
                Button("ページ内を検索") { model.showsFind.toggle() }.keyboardShortcut("f")
                Button("閉じたタブを復元") { model.send(.restoreLatestArchive) }.keyboardShortcut("t", modifiers: [.command, .shift])
                Button("アーカイブ") { model.showsArchive = true }
            }
            CommandGroup(replacing: .windowArrangement) {
                Button("現在のタブを閉じる") { model.closeActive() }.keyboardShortcut("w")
            }
        }
        Settings { BrowserSettings(model: model) }
    }
}

struct BrowserSettings: View {
    @Bindable var model: AppModel
    @AppStorage("appearance") private var appearance = "system"
    var body: some View {
        Form {
            Section("外観") {
                Picker("表示", selection: $appearance) {
                    Text("システムに合わせる").tag("system")
                    Text("ライト").tag("light")
                    Text("ダーク").tag("dark")
                }
            }
            Section("プロファイル") {
                ForEach(model.state.profiles) { profile in
                    Label(profile.name, systemImage: "person.crop.circle")
                }
                Button("プロファイルを追加…") { model.editor = .profile; NSApp.keyWindow?.close(); NSApp.activate(ignoringOtherApps: true) }
            }
            Section {
                Text("macOS 15.4以上 · SwiftUI + WebKit · MIT")
                Text("データはこのMacに保存されます。同期・AI・利用状況の送信はありません。")
                    .foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 480, height: 370)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private var keyboardMonitor: Any?
    func installKeyboardRouting() {
        guard keyboardMonitor == nil else { return }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let model = self?.model else { return false }
                if event.type == .flagsChanged {
                    if !event.modifierFlags.contains(.control) { model.finishTabCycle() }
                    return false
                }
                guard event.window === model.browserWindow, model.editor == nil, !model.showsArchive else { return false }
                let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
                if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "w" {
                    model.closeActive(); return true
                }
                if event.keyCode == 48 && (modifiers == .control || modifiers == [.control, .shift]) {
                    model.cycleTabs(backwards: modifiers.contains(.shift)); return true
                }
                if modifiers == [.control, .option] && [123, 124].contains(event.keyCode) {
                    model.cycleSpaces(backwards: event.keyCode == 123); return true
                }
                return false
            }
            return handled ? nil : event
        }
    }
    func applicationDidResignActive(_ notification: Notification) { model?.finishTabCycle() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        Task { await model.store.flush(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
