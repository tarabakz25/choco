import SwiftUI

/// Tokens behind the base controls in `DesignSystem/Components`. Names follow the Figma
/// variables of the "Dialog Controls" frame (184:1422): `settings/*`, `dialog/*`, `radius/field`.
extension ChocoTheme {
    static let fieldRadius: CGFloat = 8
    /// Opacity of a disabled Primary/Secondary button; the other disabled controls follow it.
    static let disabledOpacity = 0.45

    /// `settings/*`: the dark grey surface used by the settings window and its controls.
    enum Settings {
        static let fieldBackground = Color(hex: "2B2D30")
        static let cardBorder = Color(hex: "2F3134")
        static let accent = Color(hex: "A553A7")
        static let textPrimary = Color(hex: "E5E5E6")
        static let textSecondary = Color(hex: "9FA0A3")
        static let buttonBackground = Color(hex: "36383B")
        static let buttonHover = Color(hex: "414346")
        static let buttonPressed = Color(hex: "4B4D50")
    }

    /// `dialog/*`: the indigo surface used by sheets that sit on top of a Space.
    enum Dialog {
        /// `dialog/bg` and `dialog/border`: the card of the extension install dialogs (8b, 8d, 8e).
        static let surface = Color(hex: "151B30")
        static let surfaceBorder = Color(hex: "2C3350")
        static let fieldBackground = Color.white.opacity(0.03)
        static let fieldBorder = Color.white.opacity(0.09)
        static let text = Color.white
        static let textMuted = Color(hex: "B9BDD4")
        static let caret = Color(hex: "C04AD8")
        static let primary = Color(hex: "3843FC")
        static let primaryMuted = Color(hex: "1E258A")
        static let primaryMutedText = Color(hex: "4D54A6")
        static let secondary = Color(hex: "30305F")
        static let secondaryBorder = Color(hex: "5A58A8")
        static let chip = Color.white.opacity(0.22)
    }
}
