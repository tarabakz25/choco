import AppKit
import CoreGraphics
import SwiftUI

/// Works both in the SwiftPM-built app bundle and the native Xcode application.
enum DesignResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }
}

/// Figma SVGs are retained unmodified and converted losslessly to PDF for AppKit.
struct DesignIcon: View {
    let name: String
    /// Size in Figma points; `ChocoSpace.scale` is applied on display.
    let size: CGFloat

    init(_ name: String, size: CGFloat = 16) {
        self.name = name
        self.size = size
    }

    private var side: CGFloat { ChocoSpace.u(size) }

    var body: some View {
        if let image = Self.image(named: name) {
            Image(nsImage: image).resizable().renderingMode(.original)
                .aspectRatio(contentMode: .fit).frame(width: side, height: side)
                .accessibilityHidden(true)
        } else {
            Color.clear.frame(width: side, height: side).accessibilityHidden(true)
        }
    }

    static func image(named name: String) -> NSImage? {
        guard let url = DesignResources.bundle.url(forResource: name, withExtension: "pdf") else { return nil }
        guard let image = NSImage(contentsOf: url) else { return nil }
        // NSImage rounds fractional PDF page sizes; retain the original SVG geometry.
        if let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1) {
            let size = page.getBoxRect(.mediaBox).size
            if size.width > 0 && size.height > 0 { image.size = size }
        }
        return image
    }
}

/// Site imagery follows actual URLs, never the example tab data from the design.
struct SiteIcon: View {
    let url: String
    var size: CGFloat = 16

    var body: some View { DesignIcon(Self.asset(for: url), size: size) }

    static func asset(for address: String) -> String {
        guard let host = URL(string: address)?.host?.lowercased() else { return "d354a" }
        func matches(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
        if matches("drive.google.com") { return "a0df4" }
        if matches("colab.research.google.com") { return "6ffaf" }
        if matches("youtube.com") || matches("youtu.be") { return "1f8e5" }
        if matches("github.com") { return "dad7f" }
        if matches("pinterest.com") || matches("pinterest.jp") { return "02093" }
        if matches("amazon.com") || matches("amazon.co.jp") { return "63d41" }
        if matches("x.com") || matches("twitter.com") { return "52e0a" }
        if matches("notion.so") || matches("notion.com") { return "aa799" }
        if matches("adobe.com") { return "b1e76" }
        if matches("google.com") || matches("google.co.jp") { return "0cf92" }
        return "d354a"
    }
}
