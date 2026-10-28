@testable import BrowserApp
import Testing

struct MotionPreferenceTests {
    @Test func systemPolicyPreservesAccessibilityPreference() {
        #expect(MotionPreference.system.reducesMotion(systemPreference: true))
        #expect(!MotionPreference.system.reducesMotion(systemPreference: false))
    }

    @Test func explicitAppOverrideWorksEvenWhenMacOSReducesMotion() {
        #expect(!MotionPreference.full.reducesMotion(systemPreference: true))
        #expect(!MotionPreference.full.reducesMotion(systemPreference: false))
        #expect(MotionPreference.reduced.reducesMotion(systemPreference: false))
        #expect(MotionPreference.reduced.reducesMotion(systemPreference: true))
    }

    @Test func launchPreferenceRequiresAnExplicitValidValue() {
        #expect(MotionPreference.requested(in: ["choco-browser"]) == nil)
        #expect(MotionPreference.requested(in: ["choco-browser", "--motion"]) == nil)
        #expect(MotionPreference.requested(in: ["choco-browser", "--motion", "invalid"]) == nil)
        #expect(MotionPreference.requested(in: ["choco-browser", "--motion", "full"]) == .full)
        #expect(MotionPreference.requested(in: ["choco-browser", "--motion", "system"]) == .system)
    }
}
