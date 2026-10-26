import SwiftUI

/// Gives a button visible state: a faint `hoverTint` under the cursor, and the stronger
/// `tint` (Figma `sidebar/selected`) while pressed or while `isActive`, e.g. its popover is open.
struct ChocoPressStyle: ButtonStyle {
    var radius: CGFloat = 6
    var isActive = false
    var tint: Color = ChocoTheme.selected
    var hoverTint: Color = ChocoTheme.tile

    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, style: self)
    }

    private struct PressBody: View {
        let configuration: Configuration
        let style: ChocoPressStyle
        @Environment(\.isEnabled) private var isEnabled
        @ChocoReducedMotion private var reduceMotion: Bool
        @State private var hovering = false

        var body: some View {
            let lit = isEnabled && (configuration.isPressed || style.isActive)
            let hovered = isEnabled && hovering && !lit
            configuration.label
                .contentShape(RoundedRectangle(cornerRadius: style.radius))
                // Behind the label: an opaque tint (the New menu's) would otherwise cover its text and icon.
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: style.radius).fill(style.hoverTint).opacity(hovered ? 1 : 0)
                        RoundedRectangle(cornerRadius: style.radius).fill(style.tint).opacity(lit ? 1 : 0)
                    }.allowsHitTesting(false)
                }
                .onHover { hovering = $0 }
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: lit ? 0.07 : 0.23), value: lit)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
        }
    }
}
