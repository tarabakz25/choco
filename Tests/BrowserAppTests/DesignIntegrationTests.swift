@testable import BrowserApp
import AppKit
import BrowserCore
import Foundation
import SwiftUI
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

    @Test func spacingTokensMatchFigmaRemScale() {
        #expect(ChocoSpace.rem == 16 && ChocoSpace.scale == 1)
        #expect([ChocoSpace.xxs, ChocoSpace.xs, ChocoSpace.sm, ChocoSpace.md, ChocoSpace.lg, ChocoSpace.xl, ChocoSpace.xxl]
            == [2, 4, 8, 12, 16, 24, 32])
        #expect(ChocoTheme.sidebarWidth == 200 && ChocoTheme.siteControlsWidth == 220)
        #expect(ChocoSpace.u(13) == 13)
    }

    @Test func spaceColourBuildsAPaletteFromItsHue() {
        #expect(SpaceTheme(colorHex: nil) == .dark)
        #expect(SpaceTheme(colorHex: "808080") == .dark) // grey: no hue
        #expect(SpaceTheme(colorHex: "1A1A1A") == .dark) // near black: no tint
        // Figma's Indigo and Teal tokens are reproduced exactly at their hues.
        #expect(SpaceTheme.indigo.sidebar == Color(hex: "262538") && SpaceTheme.teal.sidebar == Color(hex: "213A3A"))
        // Spaces of different colours no longer share a palette, so switching between them changes the window colour.
        let blue = SpaceTheme(colorHex: "7896B8"), purple = SpaceTheme(colorHex: "6C5CE7"), teal = SpaceTheme(colorHex: "2EC4B6")
        let red = SpaceTheme(colorHex: "E55039")
        #expect(blue != purple && purple != teal && red != .dark && red != teal && red != purple)
    }

    @Test func mixedThemesMeetTheirEndsAndPassBetween() {
        let from = SpaceTheme.dark, to = SpaceTheme.teal
        #expect(from.mixed(with: to, t: 0) == from)
        #expect(from.mixed(with: to, t: 1) == to)
        let middle = from.mixed(with: to, t: 0.5)
        #expect(middle != from && middle != to)
        #expect(from.mixed(with: to, t: -3) == from && from.mixed(with: to, t: 3) == to)
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
