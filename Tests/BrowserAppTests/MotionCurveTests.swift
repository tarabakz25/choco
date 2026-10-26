@testable import BrowserApp
import Testing

struct MotionCurveTests {
    @Test func reproducesFigmaSamplesWithoutClippingSpringOvershoot() {
        // Values independently transcribed from Figma's exported linear() track.
        #expect(abs(FigmaSpringCurve.progress(at: 0.10) - 0.3586) < 0.000001)
        #expect(abs(FigmaSpringCurve.progress(at: 0.38) - 1.0527) < 0.000001)
        #expect(abs(FigmaSpringCurve.progress(at: 0.50) - 1.0308) < 0.000001)
        #expect(abs(FigmaSpringCurve.progress(at: 0.80) - 0.9973) < 0.000001)
        #expect(FigmaSpringCurve.progress(at: 0.38) > 1)
        // Halfway between two exported stops must interpolate, not snap.
        #expect(abs(FigmaSpringCurve.progress(at: 0.15) - 0.60495) < 0.000001)
        #expect(abs(FigmaSpringCurve.progress(at: 0.99) - 0.9996) < 0.000001)
    }

    @Test func settlesExactlyAndHandlesInvalidAnimationTimes() {
        #expect(FigmaSpringCurve.progress(at: -0.3) == 0)
        #expect(FigmaSpringCurve.progress(at: 0) == 0)
        #expect(FigmaSpringCurve.progress(at: 1) == 1)
        #expect(FigmaSpringCurve.progress(at: 3) == 1)
        #expect(FigmaSpringCurve.progress(at: .nan) == 0)
        #expect(FigmaSpringCurve.progress(at: -.infinity) == 0)
        #expect(FigmaSpringCurve.progress(at: .infinity) == 1)
    }
}
