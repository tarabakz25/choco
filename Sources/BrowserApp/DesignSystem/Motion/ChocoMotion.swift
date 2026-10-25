import SwiftUI

/// Interactive timings extracted from the supplied Figma motion tracks.
/// The sidebar uses its 350 ms active segment, without the demo's pre-roll or loop.
enum ChocoMotion {
    static let sidebar = Animation(FigmaSampledSpring(duration: 0.35))
    static let sidebarOpacity = Animation.easeOut(duration: 0.2)
    static let siteEntry = Animation(FigmaSampledSpring(duration: 0.32)).delay(0.05)
    static let siteOpacity = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.14).delay(0.05)

    // The design has no command or dismissal track. These short, related
    // defaults implement the requested interactive transitions.
    static let command = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.14)
    static let dismiss = Animation.easeOut(duration: 0.14)
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
