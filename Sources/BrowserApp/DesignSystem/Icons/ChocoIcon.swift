import SwiftUI

/// The icon set of the Figma "Icons" frame (5:221), by meaning instead of by asset hash.
/// Use `DesignIcon(.plus)`; the assets live in `Resources/Design`.
enum ChocoIcon: String, CaseIterable {
    // Navigation and chrome
    case sidebar = "de36e", arrowLeft = "687ab", arrowRight = "caa3a", reload = "108be"
    case search = "9d9ff", plus = "77a3c", chevronRight = "9fb54", arrowDown = "d8aa1", close = "98f70"
    // Page and site actions
    case info = "832a0", message = "ea6dd", link = "d4cd0", siteControls = "20d2c", share = "d2996"
    case boost = "c593a", camera = "6b394", capture = "72336", lock = "dda43", more = "a3077"
    case hammer = "a6475", settings = "82283"
    // Library
    case media = "5de62", downloads = "6f20d", easels = "0f830", spaces = "17ee5", archive = "7f2ec"
    case filter = "03c3d", trash = "a38c1", restore = "8c213", file = "ff17e", library = "e1841"
    // Media
    case globe = "6761a", skipBack = "0c9a0", skipForward = "a56d0", play = "2f545", volume = "45ec9", pause = "aab68"
    // New menu
    case newSpace = "05e85", folder = "6d64c", easel = "36ad5", split = "11aac", newTab = "b1a06"
    case boostBrush = "b2445", planet = "efd4c"

    var assetName: String { rawValue }
}

extension DesignIcon {
    init(_ icon: ChocoIcon, size: CGFloat = 16) { self.init(icon.assetName, size: size) }
}
