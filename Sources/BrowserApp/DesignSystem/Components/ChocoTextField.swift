import SwiftUI

/// Figma `Dialog Text Field` "Tone".
enum ChocoFieldTone {
    /// Dark grey field of the settings window: 36pt, and a 2pt accent border while focused.
    case settings
    /// Translucent field of Space-style sheets: 40pt, and a purple caret while focused.
    case space
}

/// `ChocoTextField("Untitled Space", text: $name, tone: .space)`. Width follows the parent, so
/// give it a `.frame(width:)` where the design fixes one (300pt in Figma). To drive focus from
/// outside pass a `FocusState` binding as `focus`; otherwise the field tracks it itself.
struct ChocoTextField: View {
    let placeholder: String
    @Binding var text: String
    var tone: ChocoFieldTone
    var focus: FocusState<Bool>.Binding?
    var onSubmit: (() -> Void)?
    @FocusState private var ownFocus: Bool

    init(_ placeholder: String, text: Binding<String>, tone: ChocoFieldTone = .settings,
         focus: FocusState<Bool>.Binding? = nil, onSubmit: (() -> Void)? = nil) {
        self.placeholder = placeholder; _text = text; self.tone = tone; self.focus = focus; self.onSubmit = onSubmit
    }

    var body: some View {
        let binding = focus ?? $ownFocus
        let focused = binding.wrappedValue
        let shape = RoundedRectangle(cornerRadius: ChocoTheme.fieldRadius)
        ZStack(alignment: .leading) {
            // Drawn here instead of through `prompt:`, which AppKit text fields don't colour.
            if text.isEmpty { Text(placeholder).foregroundStyle(placeholderColor).allowsHitTesting(false).accessibilityHidden(true) }
            TextField("", text: $text)
                .textFieldStyle(.plain).foregroundStyle(textColor).tint(caretColor)
                .focused(binding).onSubmit { onSubmit?() }.accessibilityLabel(placeholder)
        }
        .font(ChocoTheme.font(13))
        .padding(.horizontal, ChocoSpace.md).frame(height: tone == .settings ? 36 : 40)
        .background(background, in: shape)
        .overlay { shape.strokeBorder(border(focused: focused), lineWidth: borderWidth(focused: focused)) }
        .contentShape(shape)
        .onTapGesture { binding.wrappedValue = true }
    }

    private var background: Color { tone == .settings ? ChocoTheme.Settings.fieldBackground : ChocoTheme.Dialog.fieldBackground }
    private var textColor: Color { tone == .settings ? ChocoTheme.Settings.textPrimary : ChocoTheme.Dialog.text }
    private var placeholderColor: Color { tone == .settings ? ChocoTheme.Settings.textSecondary : ChocoTheme.Dialog.textMuted }
    private var caretColor: Color { tone == .settings ? ChocoTheme.Settings.accent : ChocoTheme.Dialog.caret }

    private func border(focused: Bool) -> Color {
        guard tone == .settings else { return ChocoTheme.Dialog.fieldBorder }
        return focused ? ChocoTheme.Settings.accent : ChocoTheme.Settings.cardBorder
    }

    private func borderWidth(focused: Bool) -> CGFloat { tone == .settings && focused ? 2 : 1 }
}
