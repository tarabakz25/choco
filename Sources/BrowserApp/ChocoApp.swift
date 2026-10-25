import BrowserLocalization
import AppKit
import BrowserCore
import SwiftUI

@main @MainActor struct ChocoApp: App {
    @AppStorage(AppLanguage.storageKey, store: AppLanguage.defaults) private var language = AppLanguage.current.rawValue
    private var l10n: Localizer { Localizer(language: AppLanguage(rawValue: language) ?? .current) }
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel
    @AppStorage("appearance") private var appearance = "system"

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--app-language"), arguments.indices.contains(index + 1),
           let language = AppLanguage(rawValue: arguments[index + 1]) {
            AppLanguage.defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        }
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        Window("choco", id: "browser") {
            BrowserWindow(model: model)
                .environment(\.locale, l10n.language.locale)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .onAppear { delegate.model = model; delegate.installKeyboardRouting(); NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(l10n.text("New Tab")) { model.showCommand(.newTab) }.keyboardShortcut("t")
                Button(l10n.text("Enter Address")) { model.showCommand(.navigate) }.keyboardShortcut("l")
            }
            CommandGroup(replacing: .saveItem) {
                Button(l10n.text("Toggle Sidebar")) { model.send(.toggleSidebar) }.keyboardShortcut("s")
            }
            CommandGroup(after: .toolbar) {
                Button(l10n.text("Reload")) { model.activeSession?.reload() }.keyboardShortcut("r")
                Button(l10n.text("Back")) { model.activeSession?.goBack() }.keyboardShortcut("[", modifiers: .command)
                Button(l10n.text("Forward")) { model.activeSession?.goForward() }.keyboardShortcut("]", modifiers: .command)
                Button(l10n.text("Find in Page")) { model.showsFind.toggle() }.keyboardShortcut("f")
                Button(l10n.text("Restore Closed Tab")) { model.send(.restoreLatestArchive) }.keyboardShortcut("t", modifiers: [.command, .shift])
                Button(l10n.text("Archive")) { model.showsArchive = true }
            }
            CommandGroup(replacing: .windowArrangement) {
                Button(l10n.text("Close Current Tab")) { model.closeActive() }.keyboardShortcut("w")
            }
        }
        Settings { BrowserSettings(model: model).environment(\.locale, l10n.language.locale) }
    }
}

struct BrowserSettings: View {
    @AppStorage(AppLanguage.storageKey, store: AppLanguage.defaults) private var language = AppLanguage.current.rawValue
    private var l10n: Localizer { Localizer(language: AppLanguage(rawValue: language) ?? .current) }
    @Bindable var model: AppModel
    @AppStorage("appearance") private var appearance = "system"
    var body: some View {
        Form {
            Section(l10n.text("Language")) {
                Picker(l10n.text("Language"), selection: $language) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { option in
                        Text(verbatim: option.nativeName).tag(option.rawValue)
                    }
                }.pickerStyle(.segmented).accessibilityIdentifier("settings-language")
            }
            Section(l10n.text("Appearance")) {
                Picker(l10n.text("Theme"), selection: $appearance) {
                    Text(l10n.text("System")).tag("system")
                    Text(l10n.text("Light")).tag("light")
                    Text(l10n.text("Dark")).tag("dark")
                }
            }
            Section(l10n.text("Profiles")) {
                ForEach(model.state.profiles) { profile in
                    Label(profile.name, systemImage: "person.crop.circle")
                }
                Button(l10n.text("Add Profile…")) { model.editor = .profile; NSApp.keyWindow?.close(); NSApp.activate(ignoringOtherApps: true) }
            }
            Section {
                Text(l10n.text("macOS 15.4 or later · SwiftUI + WebKit · MIT"))
                Text(l10n.text("Data stays on this Mac. No sync, AI, or usage data is sent."))
                    .foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 480, height: 450)
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
