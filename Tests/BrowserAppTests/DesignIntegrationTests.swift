@testable import BrowserApp
import AppKit
import BrowserCore
import Foundation
import Testing

@Suite(.serialized) @MainActor struct DesignIntegrationTests {
    @Test func bundledDesignAssetsDecodeAtOriginalSize() throws {
        let manifestURL = try #require(DesignResources.bundle.url(forResource: "asset-manifest", withExtension: "json"))
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
        let assets = try #require(json["assets"] as? [String: [String: Any]])
        #expect(!assets.isEmpty)
        for (filename, metadata) in assets {
            let stem = (filename as NSString).deletingPathExtension
            let image = try #require(DesignIcon.image(named: stem), "Missing or unusable vector asset: \(filename)")
            #expect(image.size.width > 0 && image.size.height > 0)
            let dimensions = metadata["dimensions"] as? [String: Any]
            if let width = dimensions?["width"] as? String, let expected = Double(width) {
                #expect(abs(image.size.width - expected) < 0.01)
            }
            if let height = dimensions?["height"] as? String, let expected = Double(height) {
                #expect(abs(image.size.height - expected) < 0.01)
            }
        }
    }

    @Test func bundledFontsRegisterWithoutInstallingSystemFonts() throws {
        ChocoTheme.registerFonts()
        let families = Set(NSFontManager.shared.availableFontFamilies)
        #expect(families.contains("Inter"))
        #expect(families.contains("Noto Sans JP"))
        for name in ["Inter", "NotoSansJP"] {
            let url = try #require(DesignResources.bundle.url(forResource: name, withExtension: "ttf"))
            #expect(try Data(contentsOf: url).count > 0)
        }
    }

    @Test func closingTransientContextDoesNotArchiveUnderlyingPage() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("choco-context-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(directory: directory)
        let tabID = try #require(model.state.selectedTabID)
        model.showsArchive = true
        model.closeActive()
        #expect(!model.showsArchive && model.state.selectedTabID == tabID && model.state.archive.isEmpty)
        model.showsSiteControls = true
        model.closeActive()
        #expect(!model.showsSiteControls && model.state.selectedTabID == tabID && model.state.archive.isEmpty)
        model.commandMode = .newTab
        model.closeActive()
        #expect(model.commandMode == nil && model.state.selectedTabID == tabID && model.state.archive.isEmpty)
        model.closeActive()
        #expect(model.state.tabs.isEmpty && model.state.archive.count == 1)
        await model.store.flush()
    }
}
