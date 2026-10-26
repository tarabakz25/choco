import SwiftUI

/// The geometry of Figma `Dialog Slider`: the 16pt thumb's centre travels between `thumbRadius`
/// and `width - thumbRadius`, the accent fill ends at the thumb's left edge and the track starts
/// at its right edge. Kept pure so it can be tested without a view.
enum ChocoSliderMetrics {
    static let thumbRadius: CGFloat = 8

    static func fraction(of value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    static func thumbCenter(fraction: Double, width: CGFloat) -> CGFloat {
        thumbRadius + CGFloat(fraction) * max(width - 2 * thumbRadius, 0)
    }

    /// The value under a pointer at `x`, snapped to `step` when given.
    static func value(atX x: CGFloat, width: CGFloat, in range: ClosedRange<Double>, step: Double?) -> Double {
        let travel = max(width - 2 * thumbRadius, 1)
        let fraction = min(max(Double((x - thumbRadius) / travel), 0), 1)
        let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        guard let step, step > 0 else { return raw }
        let snapped = range.lowerBound + ((raw - range.lowerBound) / step).rounded() * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }

    /// The value after one arrow-key press: one `step`, or a twentieth of the range without one.
    /// `direction` is -1 to decrease and 1 to increase; the result stays inside `range`.
    static func nudged(_ value: Double, direction: Int, in range: ClosedRange<Double>, step: Double?) -> Double {
        let increment = step.flatMap { $0 > 0 ? $0 : nil } ?? (range.upperBound - range.lowerBound) / 20
        let moved = min(max(value + Double(direction) * increment, range.lowerBound), range.upperBound)
        guard let step, step > 0 else { return moved }
        let snapped = range.lowerBound + ((moved - range.lowerBound) / step).rounded() * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }
}

/// `ChocoSlider(value: $opacity, in: 0...1)`. Width follows the parent (288pt in Figma).
struct ChocoSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double?
    @Environment(\.isEnabled) private var isEnabled

    init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1, step: Double? = nil) {
        _value = value; self.range = range; self.step = step
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let radius = ChocoSliderMetrics.thumbRadius
            let center = ChocoSliderMetrics.thumbCenter(fraction: ChocoSliderMetrics.fraction(of: value, in: range), width: width)
            ZStack(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2)
                    .fill(ChocoTheme.Settings.accent).frame(width: max(center - radius, 0), height: 4)
                UnevenRoundedRectangle(bottomTrailingRadius: 2, topTrailingRadius: 2)
                    .fill(ChocoTheme.Settings.buttonBackground).frame(width: max(width - center - radius, 0), height: 4)
                    .offset(x: center + radius)
                Circle().fill(.white).frame(width: 2 * radius, height: 2 * radius)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1).offset(x: center - radius)
            }
            .frame(width: width, height: proxy.size.height, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = ChocoSliderMetrics.value(atX: drag.location.x, width: width, in: range, step: step)
            })
        }
        .frame(height: 20)
        .opacity(isEnabled ? 1 : ChocoTheme.disabledOpacity)
        .allowsHitTesting(isEnabled)
        // Keyboard: focus with Tab (Full Keyboard Access) and adjust with the arrow keys, like a native slider.
        .focusable(isEnabled)
        .onKeyPress(phases: [.down, .repeat]) { press in
            let direction: Int
            switch press.key {
            case .leftArrow, .downArrow: direction = -1
            case .rightArrow, .upArrow: direction = 1
            default: return .ignored
            }
            value = ChocoSliderMetrics.nudged(value, direction: direction, in: range, step: step)
            return .handled
        }
        // The drag surface is invisible to VoiceOver, so expose a native slider to it.
        .accessibilityRepresentation {
            if let step { Slider(value: $value, in: range, step: step) } else { Slider(value: $value, in: range) }
        }
    }
}
