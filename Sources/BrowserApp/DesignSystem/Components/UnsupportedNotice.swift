import Observation
import SwiftUI

/// Figma shows Boost, Easel, Media and friends as live controls. Until they exist they look exactly like the
/// design and, when used, say so here instead of pretending to work or being greyed out.
@MainActor @Observable final class UnsupportedNotice {
    static let shared = UnsupportedNotice()
    private(set) var message: String?
    private var dismissal: Task<Void, Never>?

    func show(_ feature: String) {
        message = "「\(feature)」はこのバージョンでは未対応です"
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}

private struct UnsupportedNoticeOverlay: ViewModifier {
    @State private var notice = UnsupportedNotice.shared
    @ChocoReducedMotion private var reduceMotion: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = notice.message {
                Text(message)
                    .font(ChocoTheme.font(12, weight: .semibold)).foregroundStyle(ChocoTheme.text)
                    .padding(.horizontal, ChocoSpace.u(14)).frame(height: ChocoSpace.u(32))
                    .background(ChocoTheme.command, in: Capsule())
                    .overlay(Capsule().strokeBorder(ChocoTheme.commandBorder, lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                    .padding(.bottom, ChocoSpace.u(24))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("unsupported-notice")
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: notice.message)
    }
}

extension View {
    /// Shows `UnsupportedNotice` messages at the bottom of this view.
    func unsupportedNoticeOverlay() -> some View { modifier(UnsupportedNoticeOverlay()) }
}
