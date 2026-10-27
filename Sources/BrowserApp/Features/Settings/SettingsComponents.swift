import SwiftUI

struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }.padding(.horizontal, ChocoSpace.u(10))
            .background(alignment: .top) {
                RoundedRectangle(cornerRadius: 8).fill(SettingsStyle.card)
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }.frame(height: ChocoSpace.u(40))
            }
    }
}

struct SettingsRow<Accessory: View>: View {
    let title: String
    var subtitle: String?
    var icon: String?
    var iconColor: String
    var info: Bool
    var divider: Bool
    @ViewBuilder let accessory: Accessory
    init(_ title: String, subtitle: String? = nil, icon: String? = nil, iconColor: String = "0A84FF", info: Bool = false, divider: Bool = true,
         @ViewBuilder accessory: () -> Accessory) {
        self.title = title; self.subtitle = subtitle; self.icon = icon; self.iconColor = iconColor; self.info = info; self.divider = divider
        self.accessory = accessory()
    }
    var body: some View {
        HStack(spacing: ChocoSpace.sm) {
            if let icon {
                DesignIcon("settings-\(icon)", size: 20).background(Color(hex: iconColor), in: RoundedRectangle(cornerRadius: 5))
            }
            // Figma "Text": label row, then a 1pt-gapped 11pt caption.
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: ChocoSpace.u(4)) {
                    Text(title).fixedSize(horizontal: false, vertical: true)
                    if info { DesignIcon("settings-a3130", size: 16) }
                }
                if let subtitle {
                    Text(subtitle).font(ChocoTheme.font(11)).foregroundStyle(SettingsStyle.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .frame(minHeight: ChocoSpace.u(36))
        .overlay(alignment: .bottom) { if divider { Rectangle().fill(SettingsStyle.divider).frame(height: 1) } }
    }
}

struct SettingsButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    /// Figma draws a few buttons in `settings/text-disabled` while they still respond to a click.
    var dimmed = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(ChocoTheme.font(13, weight: .medium))
            .foregroundStyle(dimmed ? Color(hex: "5B5C5F") : enabled ? SettingsStyle.text : SettingsStyle.secondary)
            .padding(.horizontal, ChocoSpace.md).frame(height: ChocoSpace.u(24))
            .background(configuration.isPressed ? SettingsStyle.selected : SettingsStyle.button, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct SettingsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Capsule().fill(configuration.isOn ? SettingsStyle.accent : Color(hex: "4A4B4E"))
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(Color(hex: configuration.isOn ? "F2E6F3" : "D9D9DA"))
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1).frame(width: ChocoSpace.u(18), height: ChocoSpace.u(18)).padding(1)
                }.frame(width: ChocoSpace.u(36), height: ChocoSpace.u(20))
        }.buttonStyle(.plain)
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
            }
    }
}

/// A switch that looks and behaves like Figma's. `key` persists the position; a feature that does not exist yet
/// says so through `UnsupportedNotice` when it is flipped. `fixed` pins a switch to what the app really does.
struct SettingsFeatureToggle: View {
    let title: String
    let feature: String
    var subtitle: String?
    var icon: String?
    var color: String
    var info: Bool
    var divider: Bool
    var fixed: Bool?
    @AppStorage private var stored: Bool

    init(_ title: String, key: String, defaultValue: Bool, feature: String? = nil, subtitle: String? = nil,
         icon: String? = nil, color: String = "0A84FF", info: Bool = false, divider: Bool = true, fixed: Bool? = nil) {
        self.title = title; self.feature = feature ?? title; self.subtitle = subtitle; self.icon = icon; self.color = color
        self.info = info; self.divider = divider; self.fixed = fixed
        _stored = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        let binding = Binding<Bool>(
            get: { fixed ?? stored },
            set: { value in
                if fixed == nil { stored = value }
                UnsupportedNotice.shared.show(feature)
            }
        )
        SettingsRow(title, subtitle: subtitle, icon: icon, iconColor: color, info: info, divider: divider) {
            Toggle(title, isOn: binding).labelsHidden().toggleStyle(SettingsToggleStyle())
        }
    }
}

/// Figma `Settings Secondary Button` for something that is not built yet: normal look, says so when pressed.
struct SettingsNoticeButton: View {
    let title: String
    let feature: String
    init(_ title: String, feature: String? = nil) { self.title = title; self.feature = feature ?? title }

    var body: some View {
        Button(title) { UnsupportedNotice.shared.show(feature) }.buttonStyle(SettingsButtonStyle())
    }
}

/// Figma 144pt "Accessory" dropdown: value on the left, chevrons on the right. Picking a value that nothing reads
/// yet keeps the choice and says the setting is not supported.
struct SettingsDropdown: View {
    let feature: String
    let options: [String]
    var icon: String?
    @AppStorage private var selection: String

    init(key: String, options: [String], feature: String, icon: String? = nil) {
        self.feature = feature; self.options = options; self.icon = icon
        _selection = AppStorage(wrappedValue: options[0], key)
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    guard option != selection else { return }
                    selection = option
                    UnsupportedNotice.shared.show(feature)
                }
            }
        } label: {
            HStack(spacing: ChocoSpace.u(6)) {
                if let icon { DesignIcon(icon, size: 16) }
                Text(options.contains(selection) ? selection : options[0]).font(ChocoTheme.font(13, weight: .medium)).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DesignIcon("settings-4e45f", size: 12)
            }
            .padding(.leading, ChocoSpace.u(10)).padding(.trailing, ChocoSpace.u(8))
            .frame(width: ChocoSpace.u(144), height: ChocoSpace.u(24))
            .background(SettingsStyle.button, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    }
}
