import AppKit
import SwiftUI

/// Keep native window controls and center the design's title across macOS versions.
struct SettingsWindowTitle: NSViewRepresentable {
    let title: String
    @Binding var titlebarHeight: CGFloat
    func makeNSView(context: Context) -> NSView {
        let view = TitleView()
        view.onTitlebarHeight = { height in titlebarHeight = height }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TitleView)?.settingsTitle = title
        nsView.window?.title = title
    }
    private class TitleView: NSView {
        var settingsTitle = "General" {
            didSet { titleLabel?.stringValue = settingsTitle }
        }
        var onTitlebarHeight: ((CGFloat) -> Void)?
        private weak var titleLabel: NSTextField?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.title = settingsTitle
            window?.titleVisibility = .hidden
            window?.titlebarAppearsTransparent = true
            window?.backgroundColor = NSColor(red: 38 / 255, green: 40 / 255, blue: 43 / 255, alpha: 1)
            if let window {
                if titleLabel == nil, let close = window.standardWindowButton(.closeButton), let titlebar = close.superview {
                    let fill = TitlebarFill()
                    fill.wantsLayer = true
                    fill.layer?.backgroundColor = NSColor(red: 38 / 255, green: 40 / 255, blue: 43 / 255, alpha: 1).cgColor
                    fill.translatesAutoresizingMaskIntoConstraints = false
                    titlebar.addSubview(fill, positioned: .below, relativeTo: nil)
                    NSLayoutConstraint.activate([
                        fill.leadingAnchor.constraint(equalTo: titlebar.leadingAnchor),
                        fill.trailingAnchor.constraint(equalTo: titlebar.trailingAnchor),
                        fill.topAnchor.constraint(equalTo: titlebar.topAnchor),
                        fill.bottomAnchor.constraint(equalTo: titlebar.bottomAnchor)
                    ])
                    let label = NSTextField(labelWithString: settingsTitle)
                    label.font = NSFont(descriptor: NSFontDescriptor(fontAttributes: [
                        .family: "Inter", .traits: [NSFontDescriptor.TraitKey.weight: NSFont.Weight.bold.rawValue]
                    ]), size: 13)
                    label.textColor = NSColor(white: 0.84, alpha: 1)
                    label.setAccessibilityElement(false)
                    label.translatesAutoresizingMaskIntoConstraints = false
                    titlebar.addSubview(label)
                    NSLayoutConstraint.activate([
                        label.centerXAnchor.constraint(equalTo: titlebar.centerXAnchor),
                        label.centerYAnchor.constraint(equalTo: close.centerYAnchor)
                    ])
                    titleLabel = label
                }
                let height = window.frame.height - window.contentLayoutRect.height
                Task { @MainActor [weak self] in self?.onTitlebarHeight?(height) }
            }
        }
    }
    private class TitlebarFill: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
}
