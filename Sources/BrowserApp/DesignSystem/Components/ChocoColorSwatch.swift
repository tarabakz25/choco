import SwiftUI

/// Figma `Color Swatch`: a 24pt dot in a 32pt hit area; the selected one gains a 2pt ring.
/// `label` is what VoiceOver reads (the swatch itself has no text).
struct ChocoColorSwatch: View {
    let color: Color
    var isSelected: Bool
    let label: String
    let action: () -> Void

    init(_ color: Color, isSelected: Bool = false, label: String, action: @escaping () -> Void) {
        self.color = color; self.isSelected = isSelected; self.label = label; self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color).frame(width: 24, height: 24)
                if isSelected { Circle().strokeBorder(ChocoTheme.Settings.textPrimary, lineWidth: 2) }
            }.frame(width: 32, height: 32).contentShape(Circle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
