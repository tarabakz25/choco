import AppKit
import BrowserCore
import SwiftUI

/// Sits over a sidebar tab row and owns its left mouse button: a click selects the tab, a drag lifts it.
/// SwiftUI's own drag can't change the drag image once the drag has begun, and the image has to shrink
/// to a Favorites tile as it enters that grid, so the drag session is driven from AppKit here.
struct TabDragSource: NSViewRepresentable {
    let model: AppModel
    let tab: BrowserTab
    let onPress: (Bool) -> Void
    let onClick: () -> Void

    func makeNSView(context: Context) -> TabDragSourceView {
        let view = TabDragSourceView()
        configure(view)
        return view
    }

    func updateNSView(_ view: TabDragSourceView, context: Context) { configure(view) }

    private func configure(_ view: TabDragSourceView) {
        view.model = model; view.tab = tab; view.onPress = onPress; view.onClick = onClick
    }
}

@MainActor final class TabDragSourceView: NSView, @preconcurrency NSDraggingSource {
    weak var model: AppModel?
    var tab: BrowserTab?
    var onPress: (Bool) -> Void = { _ in }
    var onClick: () -> Void = {}
    private var mouseDownEvent: NSEvent?
    private var morph: DragImageMorph?

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func isAccessibilityElement() -> Bool { false }

    /// Only the plain left button belongs to this view; right-click and hover reach the SwiftUI row beneath
    /// (its context menu and highlight).
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent,
              [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type),
              !event.modifierFlags.contains(.control) else { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        onPress(true)
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDownEvent != nil else { return }
        mouseDownEvent = nil
        onPress(false)
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDownEvent, let tab, let model else { return }
        let distance = hypot(event.locationInWindow.x - down.locationInWindow.x, event.locationInWindow.y - down.locationInWindow.y)
        guard distance > 4 else { return }
        mouseDownEvent = nil
        onPress(false)

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(tab.id.uuidString, forType: .string)
        let item = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let morph = DragImageMorph(tab: tab, rowSize: bounds.size)
        self.morph = morph
        // The lifted row starts exactly over the row it came from.
        let image = morph.image(progress: 0, lift: 0)
        item.setDraggingFrame(bounds.insetBy(dx: -DragImageMorph.padding, dy: -DragImageMorph.padding), contents: image)
        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .none
        let grab = convert(event.locationInWindow, from: nil)
        morph.begin(session: session, grabInRow: NSPoint(x: grab.x, y: bounds.height - grab.y), model: model)
        model.beginTabDrag(tab.id)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Drops are moves; letting go outside the app is handled by `endTabDrag`.
        context == .withinApplication ? .move : []
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        morph?.pointerMoved(to: screenPoint)
        // Letting go outside the app opens a window there, so the image must not fly back first.
        session.animatesToStartingPositionsOnCancelOrFail = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain && $0.frame.contains(screenPoint) }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        morph?.finish()
        morph = nil
        // Escape cancels with the button still down; a real release outside every window detaches the tab.
        let cancelled = NSEvent.pressedMouseButtons & 1 != 0
        model?.endTabDrag(operation: operation, cancelled: cancelled, at: screenPoint)
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}

/// Draws the dragged tab and animates it: it lifts off the row as a shadowed pill, then shrinks to a
/// favorite-sized tile while the pointer is over the Favorites grid (and grows back when it leaves).
@MainActor final class DragImageMorph {
    static let padding: CGFloat = 12
    private static let tileSize = NSSize(width: 56, height: 38)
    private static let liftDuration = 0.12
    private static let morphDuration = 0.18

    private let tab: BrowserTab
    private let pillSize: NSSize
    private let icon: NSImage?
    private weak var session: NSDraggingSession?
    private weak var model: AppModel?
    private var grabInRow = NSPoint.zero
    private var progress: CGFloat = 0     // 0 = pill, 1 = tile
    private var lift: CGFloat = 0
    private var progressFrom: CGFloat = 0
    private var progressTarget: CGFloat = 0
    private var morphStart = Date()
    private var liftStart = Date()
    private var timer: Timer?
    private var pointer = NSPoint.zero

    init(tab: BrowserTab, rowSize: NSSize) {
        self.tab = tab
        pillSize = rowSize
        icon = DesignIcon.image(named: SiteIcon.asset(for: tab.url))
    }

    func begin(session: NSDraggingSession, grabInRow: NSPoint, model: AppModel) {
        self.session = session; self.grabInRow = grabInRow; self.model = model
        pointer = NSEvent.mouseLocation
        liftStart = Date()
        startTimer()
    }

    func pointerMoved(to point: NSPoint) {
        pointer = point
        let target: CGFloat = (model?.dragOverFavorites ?? false) ? 1 : 0
        if target != progressTarget {
            progressFrom = progress; progressTarget = target; morphStart = Date()
            startTimer()
        } else if timer == nil { apply() }
    }

    func finish() { timer?.invalidate(); timer = nil }

    private func startTimer() {
        guard timer == nil else { return }
        // Common modes: the drag session runs the loop in event-tracking mode.
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = Date()
        lift = min(1, CGFloat(now.timeIntervalSince(liftStart) / Self.liftDuration))
        let t = min(1, CGFloat(now.timeIntervalSince(morphStart) / Self.morphDuration))
        progress = progressFrom + (progressTarget - progressFrom) * Self.ease(t)
        apply()
        if lift >= 1 && t >= 1 { timer?.invalidate(); timer = nil }
    }

    private static func ease(_ t: CGFloat) -> CGFloat { 1 - pow(1 - t, 3) }

    private func apply() {
        guard let session else { return }
        let size = currentSize
        let imageSize = NSSize(width: size.width + 2 * Self.padding, height: size.height + 2 * Self.padding)
        // Where the pointer sits inside the image: where it grabbed the row, drifting to the tile's centre.
        let pillGrab = NSPoint(x: grabInRow.x + Self.padding, y: grabInRow.y + Self.padding)
        let tileGrab = NSPoint(x: imageSize.width / 2, y: imageSize.height / 2)
        let grab = NSPoint(x: pillGrab.x + (tileGrab.x - pillGrab.x) * progress, y: pillGrab.y + (tileGrab.y - pillGrab.y) * progress)
        // Screen coordinates are y-up; `grab` is measured from the image's top edge.
        let origin = NSPoint(x: pointer.x - grab.x, y: pointer.y - (imageSize.height - grab.y))
        let image = self.image(progress: progress, lift: lift)
        session.enumerateDraggingItems(options: [], for: nil, classes: [NSPasteboardItem.self], searchOptions: [:]) { item, _, _ in
            item.setDraggingFrame(NSRect(origin: origin, size: imageSize), contents: image)
        }
    }

    private var currentSize: NSSize {
        NSSize(width: pillSize.width + (Self.tileSize.width - pillSize.width) * progress,
               height: pillSize.height + (Self.tileSize.height - pillSize.height) * progress)
    }

    func image(progress: CGFloat, lift: CGFloat) -> NSImage {
        let size = NSSize(width: pillSize.width + (Self.tileSize.width - pillSize.width) * progress,
                          height: pillSize.height + (Self.tileSize.height - pillSize.height) * progress)
        let pad = Self.padding
        let canvas = NSSize(width: size.width + 2 * pad, height: size.height + 2 * pad)
        let title = tab.displayTitle
        let icon = icon
        return NSImage(size: canvas, flipped: true) { _ in
            let body = NSRect(x: pad, y: pad, width: size.width, height: size.height)
            let shape = NSBezierPath(roundedRect: body, xRadius: 8, yRadius: 8)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35 * lift)
            shadow.shadowBlurRadius = 6 * lift
            shadow.shadowOffset = NSSize(width: 0, height: -3 * lift)
            shadow.set()
            NSColor(srgbRed: 0x73 / 255, green: 0x71 / 255, blue: 0x71 / 255, alpha: 1).setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()

            // The icon glides from the row's leading edge to the tile's centre; the title fades out on the way.
            let iconSize: CGFloat = 16
            let leading = body.minX + 10
            let centred = body.midX - iconSize / 2
            let iconX = leading + (centred - leading) * progress
            icon?.draw(in: NSRect(x: iconX, y: body.midY - iconSize / 2, width: iconSize, height: iconSize))
            let textAlpha = max(0, 1 - progress * 2.4)
            if textAlpha > 0 {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byTruncatingTail
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor(srgbRed: 0xED / 255, green: 0xED / 255, blue: 0xED / 255, alpha: textAlpha),
                    .paragraphStyle: style
                ]
                let textX = leading + iconSize + 6
                let textRect = NSRect(x: textX, y: body.midY - 9, width: max(0, body.maxX - 6 - textX), height: 18)
                (title as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)
            }
            return true
        }
    }
}
