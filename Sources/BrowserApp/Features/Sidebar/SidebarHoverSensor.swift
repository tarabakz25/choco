import AppKit
import SwiftUI

/// A native tracking area detects the narrow reveal edge without taking clicks
/// or keyboard focus away from the underlying web page.
struct SidebarHoverSensor: NSViewRepresentable {
    let enabled: Bool
    let onEntered: () -> Void
    let onExited: () -> Void

    func makeNSView(context: Context) -> SidebarTrackingView {
        let view = SidebarTrackingView()
        view.setAccessibilityElement(false)
        view.configure(enabled: enabled, onEntered: onEntered, onExited: onExited)
        return view
    }

    func updateNSView(_ nsView: SidebarTrackingView, context: Context) {
        nsView.configure(enabled: enabled, onEntered: onEntered, onExited: onExited)
    }

    static func dismantleNSView(_ nsView: SidebarTrackingView, coordinator: ()) {
        nsView.configure(enabled: false, onEntered: {}, onExited: {})
    }
}

final class SidebarTrackingView: NSView {
    private var revealEnabled = false
    private var area: NSTrackingArea?
    private var onEntered: (() -> Void)?
    private var onExited: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(enabled: Bool, onEntered: @escaping () -> Void, onExited: @escaping () -> Void) {
        self.onEntered = onEntered
        self.onExited = onExited
        guard revealEnabled != enabled else { return }
        revealEnabled = enabled
        updateTrackingAreas()
        if enabled { synchronizePointerOnNextRunLoop() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // NSTrackingArea.mouseMoved supplies a second chance when the pointer was
        // already in the edge as it became enabled (e.g. hiding with the keyboard).
        if revealEnabled { window?.acceptsMouseMovedEvents = true }
        updateTrackingAreas()
        if revealEnabled { synchronizePointerOnNextRunLoop() }
    }

    private func synchronizePointerOnNextRunLoop() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.revealEnabled, let window = self.window, window.isKeyWindow else { return }
            let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            if self.bounds.contains(point) { self.onEntered?() } else { self.onExited?() }
        }
    }

    override func updateTrackingAreas() {
        if let area { removeTrackingArea(area); self.area = nil }
        super.updateTrackingAreas()
        guard revealEnabled, window != nil else { return }
        window?.acceptsMouseMovedEvents = true
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.area = area
    }

    override func mouseEntered(with event: NSEvent) {
        if revealEnabled { onEntered?() }
    }
    override func mouseMoved(with event: NSEvent) {
        if revealEnabled { onEntered?() }
    }
    override func mouseExited(with event: NSEvent) {
        if revealEnabled { onExited?() }
    }
}
