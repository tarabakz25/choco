import AppKit
import BrowserCore
import SwiftUI

/// The sidebar's "New" menu (Figma 149:7410), opened by the plus button next to the Space dots.
/// Easel and Boost look and lay out like the design; until they exist they answer with `UnsupportedNotice`.
struct NewMenuView: View {
    static let width: CGFloat = ChocoSpace.u(184)
    private static let surface = Color(hex: "090909")
    private static let highlight = Color(hex: "3B3B3B")

    @Bindable var model: AppModel
    @ChocoReducedMotion private var reduceMotion: Bool
    @State private var hasAppeared = false

    private var shown: Bool { reduceMotion || hasAppeared }
    private var canSplit: Bool { model.state.split == nil && model.selectedTab != nil }

    var body: some View {
        VStack(spacing: 0) {
            row(0, icon: "05e85", title: "新しいSpace", id: "new-menu-space") {
                model.showsNewMenu = false
                model.editor = .space(nil)
            }
            row(1, icon: "6d64c", title: "新しいフォルダ", id: "new-menu-folder") {
                model.showsNewMenu = false
                model.editor = .folder(nil)
            }
            divider(2)
            row(3, icon: "36ad5", title: "新しいEasel", shortcut: "^⇧E", id: "new-menu-easel") {
                model.showsNewMenu = false
                UnsupportedNotice.shared.show("Easel")
            }
            row(4, icon: "b2445", title: "新しいBoost", id: "new-menu-boost") {
                model.showsNewMenu = false
                UnsupportedNotice.shared.show("Boost")
            }
            divider(5)
            row(6, icon: "11aac", title: "新しいSplit", shortcut: "^⇧;", id: "new-menu-split", enabled: canSplit) { model.newSplit() }
            row(7, icon: "b1a06", title: "新しいタブ", shortcut: "⌘T", id: "new-menu-tab") { model.showCommand(.newTab) }
        }
        .padding(ChocoSpace.rem(0.375))
        .frame(width: Self.width)
        .background(Self.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomLeading) {
            if let tail = DesignIcon.image(named: "110fc") {
                Image(nsImage: tail).resizable().frame(width: ChocoSpace.u(12), height: ChocoSpace.u(6))
                    .offset(x: ChocoSpace.u(162), y: ChocoSpace.u(5.5)).accessibilityHidden(true)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 8)
        .opacity(shown ? 1 : 0)
        .animation(reduceMotion ? nil : ChocoMotion.newMenuOpacity, value: hasAppeared)
        .scaleEffect(shown ? 1 : 0.96)
        .offset(x: shown ? 0 : 3.68, y: shown ? 0 : 11.16)
        .animation(reduceMotion ? nil : ChocoMotion.newMenuEntry, value: hasAppeared)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("new-menu-panel")
        .onExitCommand { model.showsNewMenu = false }
        .task { hasAppeared = true }
    }

    private func row(_ index: Int, icon: String, title: String, shortcut: String? = nil, id: String,
                     enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ChocoSpace.u(6)) {
                DesignIcon(icon, size: 16)
                Text(title).font(ChocoTheme.font(13, weight: .semibold)).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let shortcut {
                    Text(shortcut).font(ChocoTheme.font(12, weight: .medium)).foregroundStyle(ChocoTheme.tertiary)
                }
            }
            .padding(.horizontal, ChocoSpace.u(10)).frame(height: ChocoSpace.u(36))
        }
        .buttonStyle(ChocoPressStyle(radius: 8, tint: Color(hex: "4A4A4A"), hoverTint: Self.highlight))
        .disabled(!enabled).opacity(enabled ? 1 : 0.45)
        .modifier(MenuItemEntry(index: index, shown: shown, reduceMotion: reduceMotion))
        .accessibilityIdentifier(id)
    }

    private func divider(_ index: Int) -> some View {
        Rectangle().fill(Self.highlight).frame(height: 1)
            .padding(.horizontal, ChocoSpace.xs).frame(height: ChocoSpace.u(15))
            .modifier(MenuItemEntry(index: index, shown: shown, reduceMotion: reduceMotion))
            .accessibilityHidden(true)
    }
}

/// Each row fades in and rises 4pt a little after the previous one (Figma tracks 149:7411-7418).
private struct MenuItemEntry: ViewModifier {
    let index: Int
    let shown: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? nil : ChocoMotion.newMenuRowOpacity(index), value: shown)
            .offset(y: shown ? 0 : 4)
            .animation(reduceMotion ? nil : ChocoMotion.newMenuRowRise(index), value: shown)
    }
}
