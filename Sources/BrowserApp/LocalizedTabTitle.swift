import BrowserCore
import BrowserLocalization

extension BrowserTab {
    func localizedTitle(using localizer: Localizer) -> String {
        if customTitle == nil, url == "about:blank", title == "新しいタブ" || title.isEmpty {
            return localizer.text("New Tab")
        }
        return displayTitle
    }
}
