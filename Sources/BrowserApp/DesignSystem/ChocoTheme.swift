import SwiftUI

/// Tokens from the supplied Figma design. Browser pages keep their own appearance.
enum ChocoTheme {
    static let text = Color(hex: "EDEDED")
    static let secondary = Color(hex: "B9B8B8")
    static let tertiary = Color(hex: "8F8E8E")
    static let command = Color(hex: "1E1E1F")
    static let commandSelected = Color(hex: "565655")
    static let commandBorder = Color(hex: "4F4D4C")
    /// Figma `sidebar/hover`: the row/button fill while the pointer is over it.
    static let hover = Color.white.opacity(0.05)
    static let selected = Color.white.opacity(0.12)
    static let field = Color.white.opacity(0.07)
    static let tile = Color.white.opacity(0.06)
    static let divider = Color.white.opacity(0.15)
    static let content = Color(hex: "F4F4F5")
    /// 12.5rem, as measured in Figma (frame 19:1026): 3 favorite tiles (56pt) + 2 gaps (sm) + sm insets on both sides.
    static let sidebarWidth: CGFloat = ChocoSpace.rem(12.5)
    static let sidebarMaxWidth: CGFloat = ChocoSpace.rem(20)
    static let archiveWidth: CGFloat = ChocoSpace.u(362)
    /// 13.75rem, as measured in Figma (frame 20:1751): 204pt of content inside sm insets.
    static let siteControlsWidth: CGFloat = ChocoSpace.rem(13.75)
    static let rowHeight: CGFloat = ChocoSpace.u(32)
    static let contentInset: CGFloat = ChocoSpace.sm
    static let contentRadius: CGFloat = ChocoSpace.u(6)

    /// `size` is the Figma point size. The system font (SF Pro, with automatic Japanese fallback) stands in for
    /// Figma's Inter / Noto Sans JP (DESIGN.md §2).
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: (size * ChocoSpace.scale * 2).rounded() / 2, weight: weight)
    }
}
