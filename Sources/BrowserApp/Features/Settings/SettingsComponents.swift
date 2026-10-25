import SwiftUI

struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }.padding(.horizontal, 10)
            .background(alignment: .top) {
                RoundedRectangle(cornerRadius: 8).fill(SettingsStyle.card)
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }.frame(height: 40)
            }
    }
}

struct SettingsRow<Accessory: View>: View {
    let title: String
    var icon: String?
    var iconColor: String
    var info: Bool
    var divider: Bool
    @ViewBuilder let accessory: Accessory
    init(_ title: String, icon: String? = nil, iconColor: String = "0A84FF", info: Bool = false, divider: Bool = true,
         @ViewBuilder accessory: () -> Accessory) {
        self.title = title; self.icon = icon; self.iconColor = iconColor; self.info = info; self.divider = divider; self.accessory = accessory()
    }
    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                DesignIcon("settings-\(icon)", size: 20).background(Color(hex: iconColor), in: RoundedRectangle(cornerRadius: 5))
            }
            HStack(spacing: 5) {
                Text(title).fixedSize(horizontal: false, vertical: true)
                if info { DesignIcon("settings-a3130", size: 16) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .frame(minHeight: 36)
        .overlay(alignment: .bottom) { if divider { Rectangle().fill(SettingsStyle.divider).frame(height: 1) } }
    }
}

struct SettingsButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(ChocoTheme.font(13, weight: .medium))
            .foregroundStyle(enabled ? SettingsStyle.text : SettingsStyle.secondary)
            .padding(.horizontal, 12).frame(height: 24)
            .background(configuration.isPressed ? SettingsStyle.selected : SettingsStyle.button, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct SettingsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Capsule().fill(configuration.isOn ? SettingsStyle.accent : Color(hex: "4A4B4E"))
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(Color(hex: configuration.isOn ? "F2E6F3" : "D9D9DA"))
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1).frame(width: 18, height: 18).padding(1)
                }.frame(width: 36, height: 20)
        }.buttonStyle(.plain)
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
            }
    }
}

struct SettingsUnavailableToggle: View {
    let title: String
    var icon: String?
    var color: String
    var value: Bool
    var info: Bool
    var divider: Bool
    var help: String

    init(_ title: String, icon: String? = nil, color: String = "0A84FF", value: Bool = false,
         info: Bool = false, divider: Bool = true, help: String = "このバージョンでは未対応です。") {
        self.title = title; self.icon = icon; self.color = color; self.value = value
        self.info = info; self.divider = divider; self.help = help
    }

    var body: some View {
        SettingsRow(title, icon: icon, iconColor: color, info: info, divider: divider) {
            Toggle(title, isOn: .constant(value)).labelsHidden().toggleStyle(SettingsToggleStyle()).disabled(true)
        }.help(help)
    }
}

struct SettingsUnavailableButton: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Button(title) {}.buttonStyle(SettingsButtonStyle()).disabled(true).help("このバージョンでは未対応です。")
    }
}

struct SettingsFixedValue: View {
    let value: String
    init(_ value: String) { self.value = value }

    var body: some View {
        Text(value).frame(width: 136, height: 24, alignment: .leading).padding(.leading, 8)
            .background(SettingsStyle.button, in: RoundedRectangle(cornerRadius: 6))
    }
}
