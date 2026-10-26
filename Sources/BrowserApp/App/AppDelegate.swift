import AppKit
import SwiftUI

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
                guard event.window === model.browserWindow, model.editor == nil else { return false }
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
        model.closeDetachedWindows()
        Task { await model.store.flush(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
