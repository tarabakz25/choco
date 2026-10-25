import SwiftUI

/// Shows the Figma `sidebar/selected` tint while the button is pressed (or while `isActive`,
/// e.g. its popover is open), so every control gives feedback instead of staying inert.
struct ChocoPressStyle: ButtonStyle {
    var radius: CGFloat = 6
    var isActive = false
    var tint: Color = ChocoTheme.selected
    @Environment(\.isEnabled) private var isEnabled
    @ChocoReducedMotion private var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let lit = isEnabled && (configuration.isPressed || isActive)
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius).fill(tint).opacity(lit ? 1 : 0).allowsHitTesting(false)
            }
            .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: lit ? 0.07 : 0.23), value: lit)
    }
}
