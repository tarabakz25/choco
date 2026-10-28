import AppKit
import SwiftUI

/// Reads one two-finger gesture on the sidebar. It first decides whether the gesture is sideways (a Space swipe) or
/// vertical (the list scrolling); a sideways one then reports the fingers' travel so the lists can follow them.
struct SpaceSwipeRecognizer {
    /// The fastest the lists may move (points per second), whether they follow the fingers or settle after a release.
    /// A hard flick can cover the whole column in a frame; the lists catch up at this speed instead of jumping.
    static let maxSpeed: CGFloat = 2400

    private enum Axis { case undecided, horizontal, vertical }
    private var axis = Axis.undecided
    private var x: CGFloat = 0
    private var y: CGFloat = 0
    /// Smoothed points per event; the sign is the fingers' direction.
    private(set) var velocity: CGFloat = 0

    /// Finger travel since the gesture began: negative is left, which brings the next Space in.
    var offset: CGFloat { x }
    /// The gesture is a sideways swipe, so the vertical list should not scroll with it.
    var isHorizontal: Bool { axis == .horizontal }
    /// The gesture is a vertical scroll and belongs to the list; it never turns into a swipe.
    var isVertical: Bool { axis == .vertical }

    mutating func reset() { self = SpaceSwipeRecognizer() }

    mutating func add(dx: CGFloat, dy: CGFloat) {
        x += dx; y += dy
        if axis == .undecided, abs(x) + abs(y) >= 4 { axis = abs(x) > abs(y) * 1.2 ? .horizontal : .vertical }
        guard axis == .horizontal else { return }
        // A pause (no movement) bleeds the speed off so a slow release is not mistaken for a flick.
        velocity = dx == 0 ? velocity * 0.5 : velocity * 0.4 + dx * 0.6
    }

    /// Where the lists are after `elapsed` seconds of heading for `target` from `shown`, moving no faster than `maxSpeed`.
    static func follow(shown: CGFloat, target: CGFloat, elapsed: CFTimeInterval) -> CGFloat {
        let reach = maxSpeed * CGFloat(elapsed)
        return shown + min(reach, max(-reach, target - shown))
    }

    /// Whether letting go at `offset` finishes the switch: past 30% of the way, or a flick that went the same way.
    static func commits(offset: CGFloat, velocity: CGFloat, travel: CGFloat) -> Bool {
        let distance = abs(offset)
        if distance >= travel * 0.3 { return true }
        return distance >= travel * 0.06 && offset * velocity > 0 && abs(velocity) >= 6
    }

    /// Finger travel with resistance, for pulling past the first or last Space.
    static func rubberBand(_ offset: CGFloat, travel: CGFloat) -> CGFloat {
        let limit = travel * 0.25
        return offset < 0 ? -limit * CGFloat(tanh(Double(-offset / travel))) : limit * CGFloat(tanh(Double(offset / travel)))
    }
}

/// Invisible area over the sidebar that reports horizontal two-finger swipes while they happen.
/// A local monitor is used because the sidebar's vertical `ScrollView` takes the scroll events itself.
struct SpaceSwipeArea: NSViewRepresentable {
    /// Where the lists should be, once per frame while a sideways swipe moves: the fingers' travel, but never reached
    /// faster than `SpaceSwipeRecognizer.maxSpeed`.
    let onChange: (CGFloat) -> Void
    /// The swipe finished (or was cancelled): the fingers' final travel and release velocity. The lists may still be
    /// catching up with them; `onChange` has the last position they were given.
    let onEnd: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> SpaceSwipeView { SpaceSwipeView() }
    func updateNSView(_ view: SpaceSwipeView, context: Context) { view.onChange = onChange; view.onEnd = onEnd }
    static func dismantleNSView(_ view: SpaceSwipeView, coordinator: ()) { view.removeMonitor() }
}

final class SpaceSwipeView: NSView {
    var onChange: ((CGFloat) -> Void)?
    var onEnd: ((CGFloat, CGFloat) -> Void)?
    private var monitor: Any?
    private var recognizer = SpaceSwipeRecognizer()
    private var tracking = false
    /// Where the lists are heading (the fingers' travel) and where they have got to, one frame at a time.
    private var target: CGFloat = 0
    private var shown: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        stopFollowing()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        // Only a trackpad gesture (it has a phase), and only one that started over the sidebar.
        guard event.window === window, event.momentumPhase.isEmpty, !event.phase.isEmpty else { return event }
        if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
            tracking = bounds.contains(convert(event.locationInWindow, from: nil))
            recognizer.reset()
            stopFollowing()
            target = 0; shown = 0
        }
        guard tracking else { return event }
        // With natural scrolling the delta already follows the fingers; otherwise it is the opposite.
        let fingers: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        recognizer.add(dx: event.scrollingDeltaX * fingers, dy: event.scrollingDeltaY * fingers)
        let horizontal = recognizer.isHorizontal
        if horizontal {
            target = recognizer.offset
            startFollowing()
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            tracking = false
            stopFollowing()
            if horizontal { onEnd?(recognizer.offset, recognizer.velocity) }
        }
        // Vertical input is never taken: a sideways swipe swallows its scroll events (its vertical drift included), and
        // until the direction is clear an event that leans sideways is held back from the list too.
        if recognizer.isVertical { return event }
        return horizontal || abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? nil : event
    }

    private func startFollowing() {
        guard displayLink == nil else { return }
        lastTimestamp = CACurrentMediaTime()
        let link = displayLink(target: self, selector: #selector(follow(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopFollowing() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// One frame: move the lists towards the fingers by at most `maxSpeed` × the time since the last frame.
    @objc private func follow(_ link: CADisplayLink) {
        let now = link.timestamp
        // A stalled frame must not turn into one big step.
        let elapsed = min(now - lastTimestamp, 1.0 / 30)
        lastTimestamp = now
        let next = SpaceSwipeRecognizer.follow(shown: shown, target: target, elapsed: elapsed)
        guard next != shown else { return }
        shown = next
        onChange?(shown)
    }
}
