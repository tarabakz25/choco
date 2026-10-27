import AppKit
import ObjectiveC

/// Moves the native close/minimise/zoom buttons down so they sit level with the enlarged toolbar row.
/// The titlebar re-lays them out on resize and full screen, so the offset is reapplied from the
/// titlebar's own geometry (no stored state) after every such event.
@MainActor final class TrafficLightInset {
    private static var key = 0
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    private let inset: CGFloat
    private let scale: CGFloat
    /// Distance between neighbouring buttons in the system titlebar.
    private static let nativePitch: CGFloat = 20

    /// `inset` is how far below their native position (centred in the 28pt titlebar) the buttons sit.
    static func install(on window: NSWindow, inset: CGFloat, scale: CGFloat) {
        if objc_getAssociatedObject(window, &key) != nil { return }
        let helper = TrafficLightInset(window: window, inset: inset, scale: scale)
        objc_setAssociatedObject(window, &key, helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private init(window: NSWindow, inset: CGFloat, scale: CGFloat) {
        self.inset = inset
        self.scale = scale
        let names: [Notification.Name] = [
            NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification, NSWindow.didExitFullScreenNotification,
            NSWindow.didBecomeKeyNotification, NSWindow.didChangeScreenNotification
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                MainActor.assumeIsolated { if let window { self?.apply(to: window) } }
            }
        }
        apply(to: window)
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    private func apply(to window: NSWindow) {
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        guard let close = window.standardWindowButton(.closeButton) else { return }
        // The close button keeps its native x; the others are laid out from it with the pitch scaled up.
        let originX = close.frame.origin.x
        for (index, type) in types.enumerated() {
            guard let button = window.standardWindowButton(type), let container = button.superview else { continue }
            let nativeY = (container.bounds.height - button.frame.height) / 2
            let y = container.isFlipped ? nativeY + inset : nativeY - inset
            let x = originX + CGFloat(index) * Self.nativePitch * scale
            if abs(button.frame.origin.y - y) > 0.5 || abs(button.frame.origin.x - x) > 0.5 {
                button.setFrameOrigin(NSPoint(x: x, y: y))
            }
            // Enlarge the drawing about its centre; the frame (hit area) stays native-sized.
            button.wantsLayer = true
            let cx = button.bounds.midX, cy = button.bounds.midY
            button.layer?.setAffineTransform(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: cx * (1 - scale), ty: cy * (1 - scale)))
        }
    }
}
