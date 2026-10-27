import AppKit
import SwiftUI

/// The `Arc Tokens` variable modes (DESIGN.md §7): `Dark`, `Space – Indigo` and `Space – Teal`.
/// A Space stores a free colour rather than a mode, so the mode is derived from that colour's hue.
enum SpaceTheme: Equatable {
    case dark, indigo, teal

    init(colorHex: String?) {
        guard let colorHex, let color = NSColor(Color(hex: colorHex)).usingColorSpace(.sRGB) else { self = .dark; return }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let degrees = hue * 360
        if saturation < 0.15 || brightness < 0.2 { self = .dark }
        else if (150..<200).contains(degrees) { self = .teal }
        else if (200..<300).contains(degrees) { self = .indigo }
        else { self = .dark }
    }

    /// `sidebar/bg`: the window background that shows around the page.
    var sidebar: Color {
        switch self {
        case .dark: Color(hex: "5E5C5C")
        case .indigo: Color(hex: "262538")
        case .teal: Color(hex: "213A3A")
        }
    }

    /// `sidebar/field`: URL field, update pill, library search.
    var field: Color { Color.white.opacity(self == .dark ? 0.07 : 0.09) }

    /// `favempty/bg`, used at 12% (20% on hover or while a tab is dragged over it).
    func favoritesEmpty(highlighted: Bool) -> Color {
        let base: Color
        switch self {
        case .dark: base = .black
        case .indigo: base = highlighted ? Color(hex: "25263F") : Color(hex: "1F2035")
        case .teal: base = highlighted ? Color(hex: "203636") : Color(hex: "1A2D2D")
        }
        return base.opacity(highlighted ? 0.2 : 0.12)
    }

    /// `space/window-a` → `space/window-b`: the page area while a Space has no tab open.
    var emptyContent: LinearGradient {
        let colors: [Color]
        switch self {
        case .dark: colors = [Color(hex: "5E5C5C"), Color(hex: "5E5C5C")]
        case .indigo: colors = [Color(hex: "393A4C"), Color(hex: "48394C")]
        case .teal: colors = [Color(hex: "2F4D49"), Color(hex: "3F4D3B")]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// `space/label`: the Space name above the tab list.
    var label: Color {
        switch self {
        case .dark: Color(hex: "99999E")
        case .indigo: Color(hex: "9A99A8")
        case .teal: Color(hex: "9AB3AD")
        }
    }
}

private struct SpaceThemeKey: EnvironmentKey {
    static let defaultValue = SpaceTheme.dark
}

extension EnvironmentValues {
    var spaceTheme: SpaceTheme {
        get { self[SpaceThemeKey.self] }
        set { self[SpaceThemeKey.self] = newValue }
    }
}
