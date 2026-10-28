import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General", profiles = "Profiles", extensions = "Extensions", shortcuts = "Shortcuts", advanced = "Advanced"
    var id: String { rawValue }
    /// Pages without a Figma icon use an SF Symbol instead.
    var symbol: String? { self == .extensions ? "puzzlepiece.extension" : nil }
    var icon: String {
        switch self {
        case .general: "6b421"
        case .profiles: "4e8d0"
        case .extensions: ""
        case .shortcuts: "0d407"
        case .advanced: "29938"
        }
    }
    var selectedIcon: String {
        switch self {
        case .general: "d94bd"
        case .profiles: "dbf4c"
        case .extensions: ""
        case .shortcuts: "cf307"
        case .advanced: "b7973"
        }
    }
}

struct SettingsToolbar: View {
    @Binding var page: SettingsPage
    let titlebarHeight: CGFloat

    var body: some View {
        HStack(spacing: ChocoSpace.xs) {
            ForEach(SettingsPage.allCases) { item in
                Button { page = item } label: {
                    VStack(spacing: 3) {
                        if let symbol = item.symbol {
                            Image(systemName: symbol).font(.system(size: ChocoSpace.u(17)))
                                .foregroundStyle(page == item ? SettingsStyle.accentText : SettingsStyle.secondary)
                                .frame(width: ChocoSpace.u(22), height: ChocoSpace.u(22))
                        } else {
                            DesignIcon("settings-\(page == item ? item.selectedIcon : item.icon)", size: 22)
                        }
                        Text(item.rawValue)
                            .font(ChocoTheme.font(11, weight: .medium))
                            .foregroundStyle(page == item ? SettingsStyle.accentText : SettingsStyle.secondary)
                    }
                    .padding(.horizontal, ChocoSpace.u(8)).padding(.top, ChocoSpace.u(5)).padding(.bottom, ChocoSpace.u(4))
                    .frame(minWidth: ChocoSpace.u(50))
                    .background(page == item ? SettingsStyle.selected : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(page == item ? 0.08 : 0)) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-tab-\(item.id.lowercased())")
                .accessibilityAddTraits(page == item ? .isSelected : [])
            }
        }
        .padding(.bottom, ChocoSpace.u(7))
        .frame(maxWidth: .infinity).frame(height: ChocoSpace.u(88) - titlebarHeight, alignment: .bottom)
        .background(SettingsStyle.toolbar)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: "111214")).frame(height: 1) }
    }
}
