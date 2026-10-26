import AppKit
import BrowserCore
import SwiftUI

@main @MainActor struct ChocoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    @AppStorage("appearance") private var appearance = "system"

    init() {
        ChocoTheme.registerFonts()
        if let preference = MotionPreference.requested(in: ProcessInfo.processInfo.arguments) {
            UserDefaults.standard.set(preference.rawValue, forKey: MotionPreference.storageKey)
        }
    }

    var body: some Scene {
        Window("choco", id: "browser") {
            BrowserWindow(model: model)
                .modifier(AppMotionPreference())
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
                Button("再読み込み") { model.keySession?.reload() }.keyboardShortcut("r")
                Button("前のページ") { model.keySession?.goBack() }.keyboardShortcut("[", modifiers: .command)
                Button("次のページ") { model.keySession?.goForward() }.keyboardShortcut("]", modifiers: .command)
                Button("ページ内を検索") { model.showMainWindow(); model.showsFind.toggle() }.keyboardShortcut("f")
                Button("閉じたタブを復元") { model.send(.restoreLatestArchive) }.keyboardShortcut("t", modifiers: [.command, .shift])
                Button("アーカイブ") { model.showsArchive = true }
            }
            CommandGroup(replacing: .windowArrangement) {
                Button("現在のタブを閉じる") {
                    if let window = NSApp.keyWindow, window !== model.browserWindow {
                        window.performClose(nil)
                    } else {
                        model.closeActive()
                    }
                }.keyboardShortcut("w")
            }
        }
        Settings { BrowserSettings(model: model) }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentSize)
    }
}
