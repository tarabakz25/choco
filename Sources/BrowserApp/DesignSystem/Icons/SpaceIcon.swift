import SwiftUI

/// The built-in Space marker uses Material Icons; personal emoji stay personal.
struct SpaceIcon: View {
    let value: String
    let size: CGFloat

    init(_ value: String, size: CGFloat = 16) {
        self.value = value
        self.size = size
    }

    var body: some View {
        if value.isEmpty || value == "🌐" || value == "◉" {
            if let image = DesignIcon.image(named: "material-language") {
                Image(nsImage: image).resizable().renderingMode(.template)
                    .aspectRatio(contentMode: .fit).frame(width: size, height: size)
                    .foregroundStyle(ChocoTheme.text).accessibilityHidden(true)
            }
        } else {
            Text(value).font(ChocoTheme.font(size)).accessibilityHidden(true)
        }
    }
}
