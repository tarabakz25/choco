import AppKit
import CoreText
import SwiftUI

/// Tokens from the supplied Figma design. Browser pages keep their own appearance.
enum ChocoTheme {
    static let sidebar = Color(hex: "5E5C5C")
    static let text = Color(hex: "EDEDED")
    static let secondary = Color(hex: "B9B8B8")
    static let tertiary = Color(hex: "8F8E8E")
    static let command = Color(hex: "1E1E1F")
    static let commandSelected = Color(hex: "565655")
    static let commandBorder = Color(hex: "4F4D4C")
    static let selected = Color.white.opacity(0.12)
    static let field = Color.white.opacity(0.07)
    static let tile = Color.white.opacity(0.06)
    static let divider = Color.white.opacity(0.15)
    static let content = Color(hex: "F4F4F5")
    /// Page area while no tab is open: slate at the top left shading to mauve at the bottom right.
    static let emptyContent = LinearGradient(
        colors: [Color(hex: "3A394C"), Color(hex: "413A4C"), Color(hex: "49394C")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    /// 12.5rem, as measured in Figma (frame 19:1026): 3 favorite tiles (56pt) + 2 gaps (sm) + sm insets on both sides.
    static let sidebarWidth: CGFloat = ChocoSpace.rem(12.5)
    static let sidebarMaxWidth: CGFloat = ChocoSpace.rem(20)
    static let archiveWidth: CGFloat = 362
    /// 13.75rem, as measured in Figma (frame 20:1751): 204pt of content inside sm insets.
    static let siteControlsWidth: CGFloat = ChocoSpace.rem(13.75)
    static let rowHeight: CGFloat = 32
    static let contentInset: CGFloat = ChocoSpace.sm
    static let contentRadius: CGFloat = 6

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let nativeWeight: NSFont.Weight
        switch weight {
        case .bold: nativeWeight = .bold
        case .semibold: nativeWeight = .semibold
        case .medium: nativeWeight = .medium
        case .light: nativeWeight = .light
        default: nativeWeight = .regular
        }
        let japanese = NSFontDescriptor(fontAttributes: [.family: "Noto Sans JP", .traits: [NSFontDescriptor.TraitKey.weight: nativeWeight.rawValue]])
        let descriptor = NSFontDescriptor(fontAttributes: [.family: "Inter", .traits: [NSFontDescriptor.TraitKey.weight: nativeWeight.rawValue], .cascadeList: [japanese]])
        return Font(NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size, weight: nativeWeight))
    }

    static func registerFonts() {
        for name in ["Inter", "NotoSansJP"] {
            guard let url = DesignResources.bundle.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
