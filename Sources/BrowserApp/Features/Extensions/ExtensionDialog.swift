import SwiftUI

/// Where an extension dialog appears: over the page of the browser window, or over the settings window
/// when the install started from the Extensions tab.
enum ExtensionDialogSurface { case browser, settings }

/// What an extension dialog says (Figma 8b / 8d / 8e). Installing succeeds silently, so there is no success case.
enum ExtensionDialogContent: Equatable {
    /// 8b: asks whether to add `name`. Permissions are not shown: the design retired that UI.
    case confirm(name: String, version: String)
    /// 8d / 8e: an error with a single OK button.
    case notice(title: String, lines: [String])
}

struct ExtensionDialogRequest: Identifiable, Equatable {
    let id = UUID()
    let content: ExtensionDialogContent
    let surface: ExtensionDialogSurface
}

/// Figma "Extension Confirm A – Dialog" and "Extension Result A – Dialog" (388:3664): a 380pt card on `dialog/bg`.
struct ExtensionDialog: View {
    let content: ExtensionDialogContent
    let onResolve: (Bool) -> Void

    static let width: CGFloat = 380

    private var title: String {
        switch content {
        case .confirm(let name, _): "「\(name)」を追加しますか？"
        case .notice(let title, _): title
        }
    }

    private var lines: [String] {
        switch content {
        case .confirm(_, let version): version.isEmpty ? [] : ["バージョン \(version)"]
        case .notice(_, let lines): lines
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ChocoSpace.xl) {
            HStack(spacing: ChocoSpace.md) {
                // Figma `Extension Icon`: a 40pt tile on `text/primary` with a 2pt white border.
                DesignIcon("68396", size: 22)
                    .frame(width: ChocoSpace.u(40), height: ChocoSpace.u(40))
                    .background(ChocoTheme.text, in: RoundedRectangle(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.white, lineWidth: 2) }
                VStack(alignment: .leading, spacing: ChocoSpace.xxs) {
                    Text(title)
                        .font(ChocoTheme.font(15, weight: .bold)).foregroundStyle(ChocoTheme.Dialog.text)
                        .accessibilityIdentifier("extension-dialog-title")
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(ChocoTheme.font(11.5)).foregroundStyle(ChocoTheme.Dialog.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: ChocoSpace.sm) {
                Spacer(minLength: 0)
                switch content {
                case .confirm:
                    Button("キャンセル") { onResolve(false) }
                        .buttonStyle(.choco(.secondary)).keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("extension-dialog-cancel")
                    Button("追加") { onResolve(true) }
                        .buttonStyle(.choco(.blue)).keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("extension-dialog-confirm")
                case .notice:
                    Button("OK") { onResolve(true) }
                        .buttonStyle(.choco(.blue)).keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("extension-dialog-ok")
                }
            }
        }
        .padding(.horizontal, ChocoSpace.xl).padding(.top, ChocoSpace.xl).padding(.bottom, ChocoSpace.u(20))
        .frame(width: ChocoSpace.u(Self.width))
        .background(ChocoTheme.Dialog.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(ChocoTheme.Dialog.surfaceBorder, lineWidth: 1) }
        // Figma drop shadows (0, 2, blur 3 and 0, 16, blur 20 at 35% and 50% black); SwiftUI's radius is the CSS blur.
        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        .shadow(color: .black.opacity(0.5), radius: 20, y: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("extension-dialog")
    }
}

/// Shows the first pending extension dialog of `surface`, centred in the view it covers.
/// The caller supplies the dim, so the browser window can reuse the one the command bar already has.
struct ExtensionDialogLayer: View {
    @Bindable var model: AppModel
    let surface: ExtensionDialogSurface
    /// Dims the whole layer; the browser window dims its page itself.
    var dims = false
    @ChocoReducedMotion private var reduceMotion: Bool

    private var request: ExtensionDialogRequest? {
        model.extensionDialog.flatMap { $0.surface == surface ? $0 : nil }
    }

    var body: some View {
        ZStack {
            if let request {
                Color.black.opacity(dims ? 0.55 : 0.001)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
                    .transition(.opacity)
                ExtensionDialog(content: request.content) { model.resolveExtensionDialog($0) }
                    .id(request.id)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(reduceMotion ? nil : ChocoMotion.command(presented: request != nil), value: request?.id)
        .allowsHitTesting(request != nil)
    }
}
