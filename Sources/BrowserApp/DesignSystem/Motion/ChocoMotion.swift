import SwiftUI

/// Interactive timings from DESIGN.md §11. Opening and moving things uses the Figma spring (stiffness 420, damping 28,
/// sampled in `FigmaSpringCurve`); closing and hiding uses `cubic-bezier(0.2, 0.8, 0.2, 1)`.
enum ChocoMotion {
    private static func ease(_ duration: Double) -> Animation { .timingCurve(0.2, 0.8, 0.2, 1, duration: duration) }

    /// Sidebar shown again or peeked: 300 ms spring. Hidden: 200 ms ease.
    static let sidebarShow = Animation(FigmaSampledSpring(duration: 0.3))
    static let sidebarHide = ease(0.2)
    static func sidebar(presented: Bool) -> Animation { presented ? sidebarShow : sidebarHide }
    static let sidebarOpacity = Animation.easeOut(duration: 0.2)
    static let siteEntry = Animation(FigmaSampledSpring(duration: 0.32)).delay(0.05)
    static let siteOpacity = ease(0.14).delay(0.05)
    /// Space switch: 320 ms spring (the window colour mode and the page area follow it).
    static let space = Animation(FigmaSampledSpring(duration: 0.32))
    /// Space switch timeline (163:7447): the lists slide on `space`; the outgoing one fades over 160 ms from the start,
    /// the incoming one over 180 ms and the dots over 160 ms, both 40 ms in; the active indicator follows the spring 40 ms in.
    /// Letting go of a swipe: the same spring, stretched when `distance` is long enough that its fastest moment (about
    /// 5.2 times the average speed) would pass `maxSpeed`. Short moves keep the 320 ms.
    static func spaceSettle(distance: CGFloat, maxSpeed: CGFloat) -> Animation {
        Animation(FigmaSampledSpring(duration: max(0.32, 5.2 * Double(distance) / Double(maxSpeed))))
    }
    static let spaceListFadeOut = ease(0.16)
    static let spaceListFadeIn = ease(0.18).delay(0.04)
    static let spaceDotFade = ease(0.16).delay(0.04)
    static let spaceIndicator = Animation(FigmaSampledSpring(duration: 0.32)).delay(0.04)

    /// New menu (149:7410): 280 ms spring for the panel and the plus-to-x rotation; opacity 140 ms;
    /// rows follow 40 ms later, 30 ms apart, fading over 140 ms and rising 4pt over 200 ms.
    static let newMenuEntry = Animation(FigmaSampledSpring(duration: 0.28))
    static let newMenuOpacity = ease(0.14)
    static func newMenuRowOpacity(_ index: Int) -> Animation { newMenuOpacity.delay(0.04 + 0.03 * Double(index)) }
    static func newMenuRowRise(_ index: Int) -> Animation { ease(0.2).delay(0.04 + 0.03 * Double(index)) }

    /// Command bar: opens with a 320 ms spring, closes with a 160 ms ease.
    static let commandOpen = Animation(FigmaSampledSpring(duration: 0.32))
    static let commandClose = ease(0.16)
    static func command(presented: Bool) -> Animation { presented ? commandOpen : commandClose }
    /// Site controls and the new menu closing: 160 ms ease.
    static let dismiss = ease(0.16)
    /// Favorites tiles making room for a dragged tab, and settling it into its slot.
    static let favoriteReflow = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.22)
    static let tabLifecycle = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.18)
}

/// The exported CSS linear() samples are shared by the sidebar and site panel.
/// Keep the overshoot: clamping the output would change the supplied spring.
enum FigmaSpringCurve {
    private static let samples: [Double] = [
        0, 0.0222, 0.0798, 0.1612, 0.2567, 0.3586, 0.461, 0.5593, 0.6506, 0.7328,
        0.8047, 0.8662, 0.9172, 0.9584, 0.9906, 1.0147, 1.032, 1.0434, 1.0499, 1.0527,
        1.0525, 1.0502, 1.0463, 1.0415, 1.0362, 1.0308, 1.0254, 1.0204, 1.0159, 1.0118,
        1.0084, 1.0054, 1.003, 1.0012, 0.9997, 0.9986, 0.9979, 0.9975, 0.9972, 0.9972,
        0.9973, 0.9975, 0.9977, 0.998, 0.9983, 0.9985, 0.9988, 0.9991, 0.9993, 0.9995, 0.9997
    ]

    static func progress(at normalizedTime: Double) -> Double {
        guard normalizedTime > 0 else { return 0 }
        guard normalizedTime < 1 else { return 1 }
        let position = normalizedTime * Double(samples.count - 1)
        let lower = Int(position)
        let upper = min(lower + 1, samples.count - 1)
        let fraction = position - Double(lower)
        return samples[lower] + (samples[upper] - samples[lower]) * fraction
    }
}

private struct FigmaSampledSpring: CustomAnimation {
    let duration: TimeInterval

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < duration else { return nil }
        return value.scaled(by: FigmaSpringCurve.progress(at: time / duration))
    }
}
