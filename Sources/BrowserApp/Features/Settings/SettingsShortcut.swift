import Foundation

struct SettingsShortcut: Identifiable {
    let title: String
    let keys: String
    var id: String { title }
    static let all: [SettingsShortcut] = [
        .init(title: "New Tab", keys: "⌘T"), .init(title: "Open Location", keys: "⌘L"),
        .init(title: "Archive Tab", keys: "⌘W"), .init(title: "Restore Last Tab", keys: "⇧⌘T"),
        .init(title: "Find in Page", keys: "⌘F"), .init(title: "Reload Page", keys: "⌘R"),
        .init(title: "Toggle Sidebar", keys: "⌘S"), .init(title: "Previous Page", keys: "⌘["),
        .init(title: "Next Page", keys: "⌘]"), .init(title: "Switch Tabs", keys: "⌃⇥"),
        .init(title: "Previous Tab", keys: "⌃⇧⇥"), .init(title: "Previous Space", keys: "⌃⌥←"),
        .init(title: "Next Space", keys: "⌃⌥→"), .init(title: "Settings", keys: "⌘,")
    ]
    static func matching(_ query: String) -> [SettingsShortcut] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? all : all.filter { $0.title.localizedCaseInsensitiveContains(text) || $0.keys.localizedCaseInsensitiveContains(text) }
    }
}
