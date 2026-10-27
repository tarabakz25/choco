@testable import BrowserApp
import SwiftUI
import Testing

@Suite @MainActor struct ChocoComponentsTests {
    @Test func everyIconResolvesToABundledVectorAtSixteenPoints() throws {
        for icon in ChocoIcon.allCases {
            let image = try #require(DesignIcon.image(named: icon.assetName), "Missing icon asset for \(icon)")
            #expect(abs(image.size.width - 16) < 0.01 && abs(image.size.height - 16) < 0.01, "\(icon) is not 16pt")
        }
        // The Figma "Icons" frame (5:221) holds 44 icons, each with its own asset.
        #expect(ChocoIcon.allCases.count == 44)
        #expect(Set(ChocoIcon.allCases.map(\.assetName)).count == ChocoIcon.allCases.count)
    }

    @Test func buttonPalettesFollowTheFigmaTable() {
        typealias Settings = ChocoTheme.Settings
        typealias Dialog = ChocoTheme.Dialog
        #expect(ChocoButtonKind.primary.palette(for: .normal).background == Settings.accent)
        #expect(ChocoButtonKind.primary.palette(for: .disabled).opacity == ChocoTheme.disabledOpacity)
        #expect(ChocoButtonKind.secondary.palette(for: .normal).background == Settings.buttonBackground)
        #expect(ChocoButtonKind.secondary.palette(for: .hover).background == Settings.buttonHover)
        #expect(ChocoButtonKind.secondary.palette(for: .pressed).background == Settings.buttonPressed)
        #expect(ChocoButtonKind.secondary.palette(for: .disabled).opacity == ChocoTheme.disabledOpacity)
        #expect(ChocoButtonKind.blue.palette(for: .normal).background == Dialog.primary)
        #expect(ChocoButtonKind.blue.palette(for: .disabled).background == Dialog.primaryMuted)
        #expect(ChocoButtonKind.blue.palette(for: .disabled).foreground == Dialog.primaryMutedText)
        #expect(ChocoButtonKind.blue.palette(for: .disabled).opacity == 1)
        #expect(ChocoButtonKind.indigo.palette(for: .normal).border == Dialog.secondaryBorder)
        #expect(ChocoButtonKind.primary.palette(for: .normal).border == nil)
    }

    @Test func sliderThumbSpansTheTrackLikeTheFigmaSamples() {
        // Dialog Slider is 288pt wide; its 25 / 50 / 75 variants put the thumb at 76 / 144 / 212.
        let samples: [(fraction: Double, center: CGFloat)] = [(0.25, 76), (0.5, 144), (0.75, 212)]
        for (fraction, center) in samples {
            #expect(ChocoSliderMetrics.thumbCenter(fraction: fraction, width: 288) == center)
            #expect(abs(ChocoSliderMetrics.value(atX: center, width: 288, in: 0...1, step: nil) - fraction) < 1e-9)
        }
        #expect(ChocoSliderMetrics.thumbCenter(fraction: 0, width: 288) == 8)
        #expect(ChocoSliderMetrics.thumbCenter(fraction: 1, width: 288) == 280)
    }

    @Test func sliderValueClampsAndSnapsToStep() {
        #expect(ChocoSliderMetrics.value(atX: -40, width: 288, in: 0...100, step: nil) == 0)
        #expect(ChocoSliderMetrics.value(atX: 900, width: 288, in: 0...100, step: nil) == 100)
        #expect(ChocoSliderMetrics.value(atX: 77, width: 288, in: 0...100, step: 5) == 25)
        #expect(ChocoSliderMetrics.fraction(of: 5, in: 5...5) == 0)
        #expect(ChocoSliderMetrics.fraction(of: 200, in: 0...100) == 1)
    }
}
