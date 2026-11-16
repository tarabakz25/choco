import CoreGraphics
import Foundation

/// The address the navigation bar shows for the page in front.
///
/// WebKit's committed URL is briefly `nil` or `about:blank` at the start of a load, and the URL saved
/// on the tab can already be the page the person asked for. Prefer the in-flight URL, then the committed
/// page, then the saved one, and never let a blank document hide a real page (that removed the copy and
/// site-controls buttons and snapped the field back to the placeholder).
enum NavigationBarAddress {
    static func pageURL(provisional: String?, committed: String?, stored: String?) -> String? {
        if let url = normalized(provisional) { return url }
        if let url = normalized(committed) { return url }
        return normalized(stored)
    }

    /// Host and path, as the sidebar field draws them. A root path is just the host.
    static func label(for absolute: String) -> String {
        guard let url = URL(string: absolute), let host = url.host, !host.isEmpty else { return absolute }
        return host + (url.path == "/" ? "" : url.path)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }
        let scheme = url.scheme?.lowercased()
        guard scheme == "http" || scheme == "https", let host = url.host, !host.isEmpty else { return nil }
        return trimmed
    }
}

/// Placement of the sidebar's back, forward and reload controls.
///
/// DESIGN.md's top bar is `Window Controls → Toggle → Back/Forward → Reload`, packed to the leading edge.
/// Extra width when the sidebar is dragged wider has to sit after reload; a spacer between the toggle and
/// the navigation buttons slides them toward the trailing edge for the whole drag.
enum NavigationChromeLayout {
    /// Distance from the window's leading edge to the sidebar toggle, clear of the traffic lights.
    static let trafficLightClearance: CGFloat = 76

    static func leadingClearance(sidebarPadding: CGFloat, barPadding: CGFloat) -> CGFloat {
        max(0, trafficLightClearance - sidebarPadding - barPadding)
    }

    /// Origins of the toggle, back, forward and reload, measured from the sidebar's leading edge.
    /// Extra sidebar width does not move them: the view puts that slack in a trailing spacer, and each
    /// control is one button wide, placed by adding that width (the same way the top-bar `HStack` does).
    static func controlOrigins(sidebarWidth _: CGFloat) -> [CGFloat] {
        let padding = ChocoSpace.u(8)
        let barPadding = ChocoSpace.u(6)
        let button = ChocoSpace.u(28)
        var cursor = padding + barPadding + leadingClearance(sidebarPadding: padding, barPadding: barPadding)
        var origins: [CGFloat] = []
        origins.reserveCapacity(4)
        for _ in 0..<4 {
            origins.append(cursor)
            cursor += button
        }
        return origins
    }
}
