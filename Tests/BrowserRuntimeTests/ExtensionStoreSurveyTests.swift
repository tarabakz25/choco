import AppKit
import Foundation
import Testing
import WebKit
@testable import BrowserRuntime

/// Downloads popular Chrome Web Store extensions and records whether WebKit accepts and loads each one
/// (issue #23, step 0). Hits the real store, so it is opt-in:
///
///     OSS_ARC_WEBKIT_TESTS=1 OSS_ARC_STORE_SURVEY=1 OSS_ARC_STORE_SURVEY_OUT=/path/report.md ./scripts/test.sh --filter ExtensionStoreSurveyTests
///
/// Verdicts: ◯ loaded with no errors and nothing WebKit ignores, △ loaded but with errors or
/// manifest permissions WebKit does not recognise, ✕ could not be downloaded, staged or loaded.
@Suite("Extension store survey", .serialized, .enabled(
    if: ProcessInfo.processInfo.environment["OSS_ARC_WEBKIT_TESTS"] == "1" && ProcessInfo.processInfo.environment["OSS_ARC_STORE_SURVEY"] == "1",
    "Requires native WebKit access and the network"
))
@MainActor
struct ExtensionStoreSurveyTests {
    private static let candidates: [(id: String, label: String)] = [
        ("ddkjiahejlhfcafbddmgiahcphecmpfh", "uBlock Origin Lite"),
        ("cjpalhdlnbpafiamejdnhcphjbkeiagm", "uBlock Origin"),
        ("cfhdojbkjhnklbpkdaibdccddilifddb", "Adblock Plus"),
        ("gighmmpiobklfepjocnamgkkbiglidom", "AdBlock"),
        ("pkehgijcmpdhfbdbbnkijodmdjhbjlgp", "Privacy Badger"),
        ("ldpochfccmkkmhdbclfhpagapcfdljkj", "Decentraleyes"),
        ("lckanjgmijmafbedllaakclkaicjfmnk", "ClearURLs"),
        ("mlomiejdfkolichcflejclcbmpeaniij", "Ghostery"),
        ("edibdbjcniadpccecjdfdjjppcpchdlm", "I still don't care about cookies"),
        ("nngceckbapebfimnlniiiahkandclblb", "Bitwarden"),
        ("aeblfdkhhhdcdjpifhhbdiojplfjncoa", "1Password"),
        ("hdokiejnpimakedhajhdlcegeplioahd", "LastPass"),
        ("fdjamakpfbbddfjaooikfcpapjohcfmg", "Dashlane"),
        ("eimadpbcbfnmbkopoojfekhnkhdbieeh", "Dark Reader"),
        ("clngdbkpkpeebahjckkjfobafhncgmne", "Stylus"),
        ("dhdgffkkebhmkfjojejmpbldmpobfkfo", "Tampermonkey"),
        ("jinjaccalgkegednnccohejagnlnfdag", "Violentmonkey"),
        ("dbepggeogbaibhgnhhndojpepiihcmeb", "Vimium"),
        ("kbfnbcaeplbcioakkpcpgfkobkghlhen", "Grammarly"),
        ("oldceeleldhonbafppcapldpdifcinji", "LanguageTool"),
        ("aapbdbdomjkkjkaonfhkkikfgjllcleb", "Google Translate"),
        ("mnjggcdmjocbbbhaepdhchncahnbgone", "SponsorBlock"),
        ("gebbhagfogifgggkldgodflihgfeippi", "Return YouTube Dislike"),
        ("ponfpcnoihfmfllpaingbgckeeldkhle", "Enhancer for YouTube"),
        ("fmkadmapgofadopljbjfkapdkoienihi", "React Developer Tools"),
        ("lmhkpmbekcpmknklioeibfkpmmfibljd", "Redux DevTools"),
        ("bfbameneiokkgbdmiekhjnmfkcnldhhm", "Web Developer"),
        ("gppongmhjkpfnbhagpmjfkannfbllamg", "Wappalyzer"),
        ("gbmdgpbipfallnflgajpaliibnhdgobh", "JSON Viewer"),
        ("hlkenndednhfkekhgcdicdfddnkalmdm", "Cookie-Editor"),
        ("hlepfoohegkhhmjieoechaddaejaokhf", "Refined GitHub"),
        ("laookkfknpbbblfpciffpaejjkokdgca", "Momentum"),
        ("ldgfbffkinooeloadekpmfoklnobpien", "Raindrop.io"),
        ("knheggckgoiihginacbkhaalnibhilkk", "Notion Web Clipper"),
        ("liecbddmkiiihnedobmlmillhodjkdmb", "Loom"),
        ("chphlpgkkbolifaimnlloiipkdnihall", "OneTab"),
        ("nkbihfbeogaeaoehlefnkodbefgpgknn", "MetaMask"),
        ("bmnlcjabgnpnenekpadlanbbkooimhnj", "Honey")
    ]

    private struct Row {
        var label: String
        var id: String
        var verdict = "✕"
        var name = ""
        var version = ""
        var manifestVersion = ""
        var minimumChrome = ""
        var background = ""
        var notes: [String] = []
    }

    @Test func surveyPopularExtensions() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ExtensionSurvey-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ExtensionManager(directory: directory)
        let profileID = UUID()
        _ = manager.controller(for: profileID)

        var rows: [Row] = []
        for candidate in Self.candidates {
            var row = Row(label: candidate.label, id: candidate.id)
            do {
                let staged = try await manager.stage(storeReference: candidate.id)
                row.name = staged.name
                row.version = staged.version
                let manifest = Self.manifest(in: staged.stagingDirectory.appendingPathComponent(staged.packageName))
                row.manifestVersion = (manifest["manifest_version"] as? Int).map(String.init) ?? "?"
                row.minimumChrome = manifest["minimum_chrome_version"] as? String ?? ""
                row.background = Self.backgroundKind(manifest)

                // Raw manifest permissions that WebKit does not turn into a known permission or match pattern.
                let extensionObject = try await WKWebExtension(resourceBaseURL: staged.stagingDirectory.appendingPathComponent(staged.packageName))
                let known = Set((extensionObject.requestedPermissions.union(extensionObject.optionalPermissions)).map(\.rawValue))
                let declared = (manifest["permissions"] as? [String] ?? []) + (manifest["optional_permissions"] as? [String] ?? [])
                let unknown = declared.filter { !known.contains($0) && !$0.contains("://") && $0 != "<all_urls>" }
                if !unknown.isEmpty { row.notes.append("WebKit未認識の権限: " + unknown.sorted().joined(separator: ", ")) }
                for error in extensionObject.errors { row.notes.append("errors: " + error.localizedDescription) }

                let item = try await manager.commit(staged)
                if let error = manager.loadErrors[item.id] {
                    row.notes.append("load失敗: " + error)
                } else if let context = manager.loadedContexts(profileID: profileID).first(where: { $0.item.id == item.id })?.context {
                    if !context.isLoaded { row.notes.append("contextが未ロード") }
                    for error in context.errors { row.notes.append("context.errors: " + error.localizedDescription) }
                    row.verdict = row.notes.isEmpty ? "◯" : "△"
                } else {
                    row.notes.append("contextが作られていない")
                }
            } catch {
                row.notes.append(error.localizedDescription)
            }
            rows.append(row)
        }

        let report = Self.markdown(rows)
        let output = ProcessInfo.processInfo.environment["OSS_ARC_STORE_SURVEY_OUT"]
            .map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("choco-extension-survey.md")
        try report.write(to: output, atomically: true, encoding: .utf8)
        print("Extension survey written to \(output.path)\n\(report)")
        #expect(rows.contains { $0.verdict != "✕" }, "no extension could be staged and loaded at all")
    }

    private static func manifest(in package: URL) -> [String: Any] {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: package.path, isDirectory: &isDirectory)
        let data: Data?
        if isDirectory.boolValue {
            data = try? Data(contentsOf: package.appendingPathComponent("manifest.json"))
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-p", package.path, "manifest.json"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            data = (try? process.run()) == nil ? nil : pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
        }
        guard var data else { return [:] }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { data = data.dropFirst(3) }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    private static func backgroundKind(_ manifest: [String: Any]) -> String {
        guard let background = manifest["background"] as? [String: Any] else { return "なし" }
        if background["service_worker"] != nil { return "service_worker" }
        if background["scripts"] != nil { return "scripts" }
        return "page"
    }

    private static func markdown(_ rows: [Row]) -> String {
        func count(_ verdict: String) -> Int { rows.filter { $0.verdict == verdict }.count }
        var lines = [
            "# Chromeウェブストア拡張機能の読み込み計測",
            "",
            "◯ \(count("◯")) / △ \(count("△")) / ✕ \(count("✕")) (計 \(rows.count))",
            "",
            "| 判定 | 拡張機能 | ID | 版 | MV | 最低Chrome | background | メモ |",
            "|---|---|---|---|---|---|---|---|"
        ]
        for row in rows {
            let notes = row.notes.joined(separator: "<br>").replacingOccurrences(of: "|", with: "\\|")
            lines.append("| \(row.verdict) | \(row.name.isEmpty ? row.label : row.name) | `\(row.id)` | \(row.version) | \(row.manifestVersion) | \(row.minimumChrome) | \(row.background) | \(notes) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
