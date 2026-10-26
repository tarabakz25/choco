import SwiftUI

enum ChocoControlState: Equatable { case normal, hover, pressed, disabled }

/// Figma `Dialog Button` "Type" (184:1422).
enum ChocoButtonKind: CaseIterable {
    /// Settings accent: the confirming action in settings-style windows.
    case primary
    /// Grey: cancel and other secondary actions in settings-style windows.
    case secondary
    /// Dialog blue: the confirming action in Space-style sheets.
    case blue
    /// Dialog indigo: the secondary action in Space-style sheets.
    case indigo
}

struct ChocoButtonPalette: Equatable {
    var background: Color
    var foreground: Color
    var border: Color?
    var opacity: Double = 1
}

extension ChocoButtonKind {
    /// The colours of each Type × State cell of the Figma component. Figma gives Primary, Blue and
    /// Indigo no separate hover/pressed fill, so only Secondary changes under the cursor; change a
    /// cell here if the design gains one.
    func palette(for state: ChocoControlState) -> ChocoButtonPalette {
        switch self {
        case .primary:
            return ChocoButtonPalette(background: ChocoTheme.Settings.accent, foreground: .white,
                               opacity: state == .disabled ? ChocoTheme.disabledOpacity : 1)
        case .secondary:
            let background = switch state {
            case .normal, .disabled: ChocoTheme.Settings.buttonBackground
            case .hover: ChocoTheme.Settings.buttonHover
            case .pressed: ChocoTheme.Settings.buttonPressed
            }
            return ChocoButtonPalette(background: background, foreground: ChocoTheme.Settings.textPrimary,
                                      opacity: state == .disabled ? ChocoTheme.disabledOpacity : 1)
        case .blue:
            return state == .disabled
                ? ChocoButtonPalette(background: ChocoTheme.Dialog.primaryMuted, foreground: ChocoTheme.Dialog.primaryMutedText)
                : ChocoButtonPalette(background: ChocoTheme.Dialog.primary, foreground: ChocoTheme.Dialog.text)
        case .indigo:
            return ChocoButtonPalette(background: ChocoTheme.Dialog.secondary, foreground: ChocoTheme.Dialog.text,
                               border: ChocoTheme.Dialog.secondaryBorder)
        }
    }
}

/// Styles any `Button` as a Figma `Dialog Button`. Hover, pressed and disabled come from the
/// environment, so callers only choose the `kind` and an optional `keyHint` chip such as "ESC".
struct ChocoButtonStyle: ButtonStyle {
    var kind: ChocoButtonKind = .primary
    var keyHint: String?

    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, kind: kind, keyHint: keyHint)
    }

    struct Surface: View {
        let configuration: Configuration
        let kind: ChocoButtonKind
        let keyHint: String?
        @Environment(\.isEnabled) private var isEnabled
        @ChocoReducedMotion private var reduceMotion: Bool
        @State private var hovering = false

        private var state: ChocoControlState {
            if !isEnabled { .disabled } else if configuration.isPressed { .pressed } else if hovering { .hover } else { .normal }
        }

        var body: some View {
            let palette = kind.palette(for: state)
            let shape = RoundedRectangle(cornerRadius: ChocoTheme.fieldRadius)
            HStack(spacing: ChocoSpace.sm) {
                configuration.label.font(ChocoTheme.font(13, weight: .medium)).lineLimit(1)
                if let keyHint { KeyChip(text: keyHint) }
            }
            .foregroundStyle(palette.foreground)
            .padding(.horizontal, ChocoSpace.lg).frame(height: 32)
            .background(palette.background, in: shape)
            .overlay { if let border = palette.border { shape.strokeBorder(border, lineWidth: 1) } }
            .opacity(palette.opacity)
            .contentShape(shape)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: state)
        }
    }

    /// Figma `Key Chip`: a small keycap showing the shortcut that triggers the button.
    private struct KeyChip: View {
        let text: String
        var body: some View {
            Text(text).font(ChocoTheme.font(9, weight: .bold)).foregroundStyle(ChocoTheme.Dialog.text).opacity(0.85)
                .padding(.horizontal, 6).padding(.vertical, ChocoSpace.xxs)
                .background(ChocoTheme.Dialog.chip, in: RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)
        }
    }
}

extension ButtonStyle where Self == ChocoButtonStyle {
    static func choco(_ kind: ChocoButtonKind = .primary, keyHint: String? = nil) -> ChocoButtonStyle {
        ChocoButtonStyle(kind: kind, keyHint: keyHint)
    }
}

/// `ChocoButton("Save", kind: .blue, keyHint: "⏎") { save() }`. Use `.disabled(_:)` for the disabled state.
struct ChocoButton: View {
    let label: String
    var kind: ChocoButtonKind
    var keyHint: String?
    let action: () -> Void

    init(_ label: String, kind: ChocoButtonKind = .primary, keyHint: String? = nil, action: @escaping () -> Void) {
        self.label = label; self.kind = kind; self.keyHint = keyHint; self.action = action
    }

    var body: some View {
        Button(action: action) { Text(label) }.buttonStyle(.choco(kind, keyHint: keyHint))
    }
}
