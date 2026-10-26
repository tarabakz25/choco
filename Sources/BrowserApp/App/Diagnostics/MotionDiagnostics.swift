import AppKit
import Foundation

/// Opt-in, local-only verification of real SwiftUI/AppKit presentation samples.
/// Captures 30 seconds per requested operation / 600 samples total and never records page content or URLs.
@MainActor enum MotionDiagnostics {
    private static let enabled = ProcessInfo.processInfo.arguments.contains("--motion-diagnostics")
    private static var started: TimeInterval?
    private static var count = 0

    static func record(_ event: String, value: Double, x: Double? = nil, reducedMotion: Bool? = nil) {
        guard enabled, value.isFinite, count < 600 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // A newly requested tab operation can start a fresh short capture window;
        // the total record cap still applies across the entire process.
        if started == nil || event == "tabs" { started = now }
        let elapsed = now - (started ?? now)
        guard elapsed < 30 else { return }
        count += 1
        var row: [String: Any] = ["event": event, "t": elapsed, "value": value, "pid": ProcessInfo.processInfo.processIdentifier]
        if let x, x.isFinite { row["x"] = x }
        if let reducedMotion {
            row["effectiveReducedMotion"] = reducedMotion
            row["systemReducedMotion"] = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            row["preference"] = UserDefaults.standard.string(forKey: MotionPreference.storageKey) ?? "system"
        }
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
        data.append(10)
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OssArc/Diagnostics", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("motion.jsonl")
            if !FileManager.default.fileExists(atPath: file.path) { FileManager.default.createFile(atPath: file.path, contents: nil) }
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Diagnostics must not affect browser state or prevent interaction.
        }
    }
}
