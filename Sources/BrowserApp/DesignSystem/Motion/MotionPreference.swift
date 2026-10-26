import SwiftUI

enum MotionPreference: String, CaseIterable, Identifiable {
    static let storageKey = "motionPreference"
    case system, full, reduced

    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "システムに従う"
        case .full: "アニメーションを有効"
        case .reduced: "動きを減らす"
        }
    }

    func reducesMotion(systemPreference: Bool) -> Bool {
        switch self {
        case .system: systemPreference
        case .full: false
        case .reduced: true
        }
    }

    static func requested(in arguments: [String]) -> Self? {
        guard let index = arguments.firstIndex(of: "--motion"), arguments.indices.contains(index + 1) else { return nil }
        return Self(rawValue: arguments[index + 1])
    }
}

/// Override only this app's SwiftUI subtree, leaving the OS and websites alone.
struct AppMotionPreference: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @AppStorage(MotionPreference.storageKey) private var rawPreference = MotionPreference.system.rawValue

    func body(content: Content) -> some View {
        let preference = MotionPreference(rawValue: rawPreference) ?? .system
        content.environment(\.chocoMotionReduction, preference.reducesMotion(systemPreference: systemReducedMotion))
    }
}

private struct AppMotionReductionKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var chocoMotionReduction: Bool? {
        get { self[AppMotionReductionKey.self] }
        set { self[AppMotionReductionKey.self] = newValue }
    }
}

/// SwiftUI's OS accessibility key is read-only. The app override is separate;
/// views outside the app's policy scope continue respecting the OS by default.
@propertyWrapper struct ChocoReducedMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var systemPreference
    @Environment(\.chocoMotionReduction) private var appPreference
    var wrappedValue: Bool { appPreference ?? systemPreference }
}
