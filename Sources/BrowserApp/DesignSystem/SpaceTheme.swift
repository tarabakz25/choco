import AppKit
import SwiftUI

/// The window colours of a Space (DESIGN.md §7 `Arc Tokens`). Figma defines `Dark`, `Space – Indigo` and `Space – Teal`;
/// a Space stores a free colour, so its palette is generated from that colour's hue. At the Indigo and Teal hues the
/// generated palette is exactly Figma's token set, so those two modes are unchanged. A palette can be mixed with another,
/// which is how the window colour follows a Space switch or a swipe between Spaces.
struct SpaceTheme: Equatable {
    fileprivate var sidebarColor: RGB
    fileprivate var labelColor: RGB
    fileprivate var windowStart: RGB
    fileprivate var windowEnd: RGB
    fileprivate var favoritesBase: RGB
    fileprivate var favoritesHover: RGB
    fileprivate var fieldOpacity: Double

    static let dark = SpaceTheme(
        sidebarColor: RGB(hex: "5E5C5C"), labelColor: RGB(hex: "99999E"),
        windowStart: RGB(hex: "5E5C5C"), windowEnd: RGB(hex: "5E5C5C"),
        favoritesBase: RGB(hex: "000000"), favoritesHover: RGB(hex: "000000"), fieldOpacity: 0.07)
    static let indigo = SpaceTheme.tinted(hue: Ramps.indigoHue)
    static let teal = SpaceTheme.tinted(hue: Ramps.tealHue)

    /// The palette for a Space colour. Grey and very dark colours stay `Dark`; the tint fades in with saturation.
    init(colorHex: String?) {
        guard let colorHex, let color = NSColor(Color(hex: colorHex)).usingColorSpace(.sRGB) else { self = .dark; return }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let strength = Self.clamp01((Double(saturation) - 0.1) / 0.25) * Self.clamp01((Double(brightness) - 0.15) / 0.1)
        self = SpaceTheme.dark.mixed(with: .tinted(hue: Double(hue) * 360), t: strength)
    }

    private init(sidebarColor: RGB, labelColor: RGB, windowStart: RGB, windowEnd: RGB,
                 favoritesBase: RGB, favoritesHover: RGB, fieldOpacity: Double) {
        self.sidebarColor = sidebarColor; self.labelColor = labelColor
        self.windowStart = windowStart; self.windowEnd = windowEnd
        self.favoritesBase = favoritesBase; self.favoritesHover = favoritesHover; self.fieldOpacity = fieldOpacity
    }

    private static func tinted(hue: Double) -> SpaceTheme {
        SpaceTheme(
            sidebarColor: Ramps.sidebar.value(at: hue), labelColor: Ramps.label.value(at: hue),
            windowStart: Ramps.windowStart.value(at: hue), windowEnd: Ramps.windowEnd.value(at: hue),
            favoritesBase: Ramps.favoritesBase.value(at: hue), favoritesHover: Ramps.favoritesHover.value(at: hue),
            fieldOpacity: 0.09)
    }

    private static func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }

    /// `self` at `t` = 0, `other` at `t` = 1.
    func mixed(with other: SpaceTheme, t: Double) -> SpaceTheme {
        let t = Self.clamp01(t)
        guard t > 0 else { return self }
        guard t < 1 else { return other }
        return SpaceTheme(
            sidebarColor: sidebarColor.mixed(other.sidebarColor, t), labelColor: labelColor.mixed(other.labelColor, t),
            windowStart: windowStart.mixed(other.windowStart, t), windowEnd: windowEnd.mixed(other.windowEnd, t),
            favoritesBase: favoritesBase.mixed(other.favoritesBase, t), favoritesHover: favoritesHover.mixed(other.favoritesHover, t),
            fieldOpacity: fieldOpacity + (other.fieldOpacity - fieldOpacity) * t)
    }

    /// `sidebar/bg`: the window background that shows around the page.
    var sidebar: Color { sidebarColor.color }

    /// `sidebar/field`: URL field, update pill, library search.
    var field: Color { Color.white.opacity(fieldOpacity) }

    /// `favempty/bg`, used at 12% (20% on hover or while a tab is dragged over it).
    func favoritesEmpty(highlighted: Bool) -> Color {
        (highlighted ? favoritesHover : favoritesBase).color.opacity(highlighted ? 0.2 : 0.12)
    }

    /// `space/label`: the Space name above the tab list.
    var label: Color { labelColor.color }

    /// `space/window-a` → `space/window-b`: the page area while a Space has no tab open.
    var emptyContentStart: Color { windowStart.color }
    var emptyContentEnd: Color { windowEnd.color }
}

/// The page area of a Space with no tab: `space/window-a` → `space/window-b` on Figma's 122° diagonal. The end colour is
/// laid over the start colour through a gradient mask, so both colours stay plain `Color`s that animate and mix.
struct SpaceEmptyContent: View {
    let theme: SpaceTheme

    var body: some View {
        theme.emptyContentStart.overlay {
            theme.emptyContentEnd.mask(LinearGradient(
                stops: [.init(color: .clear, location: 0.11), .init(color: .black, location: 0.89)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

/// One colour token across hues: a generator in HSB, pulled onto Figma's Indigo and Teal values around their hues.
private struct Ramp: Sendable {
    let generate: @Sendable (Double) -> RGB
    let indigo: RGB
    let teal: RGB

    init(indigo: String, teal: String, _ generate: @escaping @Sendable (Double) -> RGB) {
        self.generate = generate; self.indigo = RGB(hex: indigo); self.teal = RGB(hex: teal)
    }

    func value(at hue: Double) -> RGB {
        var result = generate(hue)
        for (anchorHue, token) in [(Ramps.indigoHue, indigo), (Ramps.tealHue, teal)] {
            // Fully Figma's value at the anchor hue, gone 40° away.
            let weight = max(0, 1 - RGB.hueDistance(hue, anchorHue) / 40)
            result = result + (token - generate(anchorHue)) * weight
        }
        return result.clamped
    }
}

private enum Ramps {
    static let indigoHue = RGB(hex: "262538").hue
    static let tealHue = RGB(hex: "213A3A").hue

    static let sidebar = Ramp(indigo: "262538", teal: "213A3A") { RGB(hue: $0, saturation: 0.38, brightness: 0.225) }
    static let label = Ramp(indigo: "9A99A8", teal: "9AB3AD") { RGB(hue: $0, saturation: 0.11, brightness: 0.68) }
    static let windowStart = Ramp(indigo: "393A4C", teal: "2F4D49") { RGB(hue: $0, saturation: 0.32, brightness: 0.30) }
    static let windowEnd = Ramp(indigo: "48394C", teal: "3F4D3B") { RGB(hue: $0 + 45, saturation: 0.26, brightness: 0.30) }
    static let favoritesBase = Ramp(indigo: "1F2035", teal: "1A2D2D") { RGB(hue: $0, saturation: 0.41, brightness: 0.19) }
    static let favoritesHover = Ramp(indigo: "25263F", teal: "203636") { RGB(hue: $0, saturation: 0.41, brightness: 0.23) }
}

fileprivate struct RGB: Equatable, Sendable {
    var r: Double, g: Double, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    init(hex: String) {
        let value = UInt32(hex, radix: 16) ?? 0
        self.init(Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// `hue` in degrees (wraps), `saturation` and `brightness` in 0…1.
    init(hue: Double, saturation: Double, brightness: Double) {
        let sector = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let chroma = brightness * saturation
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - chroma
        let (r, g, b): (Double, Double, Double)
        switch Int(sector) {
        case 0: (r, g, b) = (chroma, x, 0)
        case 1: (r, g, b) = (x, chroma, 0)
        case 2: (r, g, b) = (0, chroma, x)
        case 3: (r, g, b) = (0, x, chroma)
        case 4: (r, g, b) = (x, 0, chroma)
        default: (r, g, b) = (chroma, 0, x)
        }
        self.init(r + m, g + m, b + m)
    }

    /// In degrees, 0…360.
    var hue: Double {
        let high = max(r, g, b), low = min(r, g, b), delta = high - low
        guard delta > 0 else { return 0 }
        let sector: Double
        if high == r { sector = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
        else if high == g { sector = (b - r) / delta + 2 }
        else { sector = (r - g) / delta + 4 }
        return (sector * 60 + 360).truncatingRemainder(dividingBy: 360)
    }

    static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let difference = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }

    static func + (lhs: RGB, rhs: RGB) -> RGB { RGB(lhs.r + rhs.r, lhs.g + rhs.g, lhs.b + rhs.b) }
    static func - (lhs: RGB, rhs: RGB) -> RGB { RGB(lhs.r - rhs.r, lhs.g - rhs.g, lhs.b - rhs.b) }
    static func * (lhs: RGB, rhs: Double) -> RGB { RGB(lhs.r * rhs, lhs.g * rhs, lhs.b * rhs) }

    var clamped: RGB { RGB(min(1, max(0, r)), min(1, max(0, g)), min(1, max(0, b))) }
    func mixed(_ other: RGB, _ t: Double) -> RGB { self + (other - self) * t }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
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
