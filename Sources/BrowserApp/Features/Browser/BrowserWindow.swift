import AppKit
import BrowserCore
import BrowserRuntime
import Observation
import SwiftUI
import WebKit

struct BrowserWindow: View {
    @Bindable var model: AppModel
    @State private var sidebarWidth: CGFloat = ChocoTheme.sidebarWidth
    @State private var sidebarDragStart: CGFloat?
    @State private var splitDragStart: Double?
    @State private var sidebarPeek = false
    @State private var sidebarHovered = false
    @State private var edgeHovered = false
    @State private var peekDismissTask: Task<Void, Never>?
    @FocusState private var findFocused: Bool
    @State private var pagePresentations: [PagePresentation] = []
    @State private var observedCoreTabIDs: [UUID] = []
    @State private var presentedSelectionIDs: [UUID] = []
    @State private var initializedPages = false
    @State private var welcomePhase = 1.0
    @State private var welcomeAnimates = false

    @ChocoReducedMotion private var reduceMotion: Bool

    /// Colour mode of the selected Space (DESIGN.md §7); the window chrome, sidebar and empty page follow it.
    private var theme: SpaceTheme { model.currentSpaceTheme }
    /// `Space 切替` (DESIGN.md §11): the window colour is the mix of the two Spaces' palettes while `AppModel` animates a
    /// switch (320 ms spring) or a swipe drags it, so it is never given an animation of its own here.
    private var themeBackground: some View { theme.sidebar }
    private var commandPresented: Bool { model.commandMode != nil }
    private var extensionDialogPresented: Bool { model.extensionDialog?.surface == .browser }
    private var modalPresented: Bool { commandPresented || model.showsSiteControls || model.showsNewMenu || extensionDialogPresented }
    private var sidebarPresented: Bool { !model.showsArchive && (model.state.sidebarVisible || sidebarPeek) }
    private var floatingSidebar: Bool { sidebarPeek && !model.state.sidebarVisible && !model.showsArchive }
    private var sidebarPose: Int { model.showsArchive ? 3 : model.state.sidebarVisible ? 2 : sidebarPeek ? 1 : 0 }
    private var reservationPose: Int { model.showsArchive ? 2 : model.state.sidebarVisible ? 1 : 0 }
    private var sidebarAnimation: Animation? { reduceMotion ? nil : ChocoMotion.sidebar(presented: sidebarPresented) }
    private var opacityAnimation: Animation? { reduceMotion ? nil : ChocoMotion.sidebarOpacity }
    private var commandAnimation: Animation? { reduceMotion ? nil : ChocoMotion.command(presented: commandPresented) }
    private var tabAnimation: Animation? { reduceMotion ? nil : ChocoMotion.tabLifecycle }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                mainLayout
                    .allowsHitTesting(!modalPresented)
                    .accessibilityHidden(modalPresented)

                // This is always mounted. Native tracking still receives edge motion,
                // but its hitTest=nil preserves input on the page underneath.
                SidebarHoverSensor(
                    enabled: !model.state.sidebarVisible && !model.showsArchive && !modalPresented && model.editor == nil,
                    onEntered: { edgeHovered = true; revealSidebar() },
                    onExited: { edgeHovered = false; schedulePeekDismissal() }
                )
                .frame(width: ChocoSpace.u(10), height: geometry.size.height)
                .accessibilityHidden(true)

                hiddenSidebarControls
                    .opacity(!model.state.sidebarVisible && !model.showsArchive && !sidebarPeek ? 1 : 0)
                    .allowsHitTesting(!model.state.sidebarVisible && !model.showsArchive && !sidebarPeek && !modalPresented)
                    .accessibilityHidden(model.state.sidebarVisible || model.showsArchive || sidebarPeek || modalPresented)

                sidebarChrome(height: geometry.size.height)

                if model.showsArchive {
                    ArchiveLibraryView(model: model)
                        .frame(width: ChocoTheme.archiveWidth, height: geometry.size.height)
                        .transition(.opacity)
                        .allowsHitTesting(!modalPresented)
                        .accessibilityHidden(modalPresented)
                }

                // Stable geometry parent: only the actual palette/backdrop enters or
                // exits. This never changes the page's structural parent or WebView.
                commandLayer
                extensionDialogLayer(size: geometry.size)
            }
            .animation(opacityAnimation, value: model.showsArchive)
        }
        .overlayPreferenceValue(SiteControlsAnchorKey.self) { anchor in
            GeometryReader { geometry in
                if model.showsSiteControls, let anchor {
                    Color.black.opacity(0.001).ignoresSafeArea()
                        .contentShape(Rectangle()).onTapGesture { model.showsSiteControls = false }
                    let rect = geometry[anchor]
                    SiteControlsView(model: model)
                        .frame(width: ChocoTheme.siteControlsWidth)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(x: min(max(8, rect.maxX - ChocoSpace.u(120)), geometry.size.width - ChocoSpace.u(228)), y: rect.maxY + ChocoSpace.u(7))
                        // SiteControlsView owns its Figma entry spring/fade. Only
                        // removal gets an outer transition, so entry isn't doubled.
                        .transition(.asymmetric(insertion: .identity, removal: .opacity))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("site-controls-panel")
                }
            }
            .animation(reduceMotion ? nil : ChocoMotion.dismiss, value: model.showsSiteControls)
        }
        .overlayPreferenceValue(NewMenuAnchorKey.self) { anchor in
            GeometryReader { geometry in
                if model.showsNewMenu, let anchor {
                    Color.black.opacity(0.001).ignoresSafeArea()
                        .contentShape(Rectangle()).onTapGesture { model.showsNewMenu = false }
                    let rect = geometry[anchor]
                    // Figma: right edges align, and the menu's tail sits 8.5pt above the plus button.
                    NewMenuView(model: model)
                        .fixedSize()
                        .position(x: max(NewMenuView.width / 2 + 8, rect.maxX - NewMenuView.width / 2),
                                  y: rect.minY - ChocoSpace.u(14) - ChocoSpace.u(129))
                        .transition(.asymmetric(insertion: .identity, removal: .opacity))
                        .accessibilityElement(children: .contain)
                }
            }
            .animation(reduceMotion ? nil : ChocoMotion.dismiss, value: model.showsNewMenu)
        }
        .frame(minWidth: 960, minHeight: 600)
        .background(themeBackground)
        .environment(\.spaceTheme, theme)
        .background(WindowReference { window in
            model.browserWindow = window
            configureWindow(window)
        })
        .ignoresSafeArea(.container, edges: .top)
        .tint(model.tint)
        .sheet(item: $model.editor) { request in EditorSheet(model: model, request: request) }
        .onChange(of: model.store.state) { _, _ in
            model.reconcile()
            synchronizePages()
        }
        .onChange(of: reduceMotion) { _, _ in synchronizePages(forceImmediate: true) }
        .onChange(of: reduceMotion, initial: true) { _, reduced in model.reducesMotion = reduced }
        .onChange(of: model.state.sidebarVisible) { _, _ in
            edgeHovered = false
            sidebarPeek = false
            model.showsSiteControls = false
            model.showsNewMenu = false
            updateWindowControls()
        }
        .onChange(of: sidebarPeek) { _, visible in
            if !visible { sidebarHovered = false; peekDismissTask?.cancel() }
            updateWindowControls()
        }
        .onChange(of: modalPresented) { _, open in if open { edgeHovered = false } }
        .onChange(of: model.showsSiteControls) { _, open in if !open { schedulePeekDismissal() } }
        .onChange(of: model.showsNewMenu) { _, open in if !open { schedulePeekDismissal() } }
        .onChange(of: model.editor?.id) { _, editor in
            if editor == nil { schedulePeekDismissal() } else { edgeHovered = false }
        }
        .onChange(of: model.showsArchive) { _, _ in
            edgeHovered = false
            sidebarPeek = false
            model.showsSiteControls = false
            model.showsNewMenu = false
            updateWindowControls()
        }
        .onAppear {
            model.reconcile(); updateWindowControls(); synchronizePages()
            MotionDiagnostics.record("policy", value: model.state.sidebarVisible ? Double(ChocoTheme.sidebarWidth) : 0, reducedMotion: reduceMotion)
        }
        .onChange(of: model.state.tabs.map(\.id)) { _, ids in
            MotionDiagnostics.record("tabs", value: Double(ids.count), reducedMotion: reduceMotion)
        }
        .onChange(of: reservationPose) { _, _ in
            MotionDiagnostics.record("target", value: model.showsArchive ? Double(ChocoTheme.archiveWidth) : model.state.sidebarVisible ? Double(sidebarWidth) : 0, reducedMotion: reduceMotion)
        }
        .onDisappear {
            peekDismissTask?.cancel()
            pagePresentations.forEach { $0.cancelTasks() }
        }
        .onExitCommand {
            // The command field owns Escape, including IME marked-text handling.
            if model.showsSiteControls { model.showsSiteControls = false }
            if model.showsNewMenu { model.showsNewMenu = false }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let error = model.store.persistenceError {
                Label(error, systemImage: "externaldrive.badge.exclamationmark")
                    .font(.caption).padding(ChocoSpace.sm).frame(maxWidth: .infinity)
                    .background(.red.opacity(0.12)).foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private var mainLayout: some View {
        HStack(spacing: 0) {
            // Always the first child: a presentation-clamped animatable spacer
            // reserves layout width without ever mounting a second sidebar.
            Color.clear
                .modifier(SidebarReservation(width: model.showsArchive ? ChocoTheme.archiveWidth : model.state.sidebarVisible ? sidebarWidth : 0))
                .animation(sidebarAnimation, value: reservationPose)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                if model.showsFind { findBar }
                if let session = model.activeSession, session.activeDownloadCount > 0 {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("ダウンロード中 · \(session.activeDownloadCount)件")
                        if let progress = session.downloadProgress { ProgressView(value: progress).frame(width: ChocoSpace.u(100)) }
                        Spacer()
                    }.font(ChocoTheme.font(11)).foregroundStyle(.secondary).padding(ChocoSpace.sm)
                }
                content
            }
            .background(ChocoTheme.content)
            .overlay {
                Color.black.opacity(commandPresented || extensionDialogPresented ? 0.55 : 0)
                    .allowsHitTesting(false)
                    .animation(commandAnimation, value: commandPresented || extensionDialogPresented)
            }
            .clipShape(RoundedRectangle(cornerRadius: ChocoTheme.contentRadius))
            .padding(.top, ChocoTheme.contentInset).padding(.trailing, ChocoTheme.contentInset).padding(.bottom, ChocoTheme.contentInset)
            .padding(.leading, model.showsArchive ? 1 : model.state.sidebarVisible ? -1 : ChocoTheme.contentInset)
            .animation(sidebarAnimation, value: reservationPose)
        }
        .background(theme.sidebar)
    }

    private func sidebarChrome(height: CGFloat) -> some View {
        BrowserSidebar(model: model)
            .frame(width: sidebarWidth, height: max(0, height - (floatingSidebar ? ChocoSpace.u(12) : 0)))
            .background(theme.sidebar)
            .clipShape(RoundedRectangle(cornerRadius: floatingSidebar ? 10 : 0))
            .overlay {
                RoundedRectangle(cornerRadius: floatingSidebar ? 10 : 0)
                    .strokeBorder(Color.white.opacity(floatingSidebar ? 0.1 : 0), lineWidth: 1)
            }
            .shadow(color: .black.opacity(floatingSidebar ? 0.45 : 0), radius: floatingSidebar ? 16 : 0, x: 0, y: 10)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.clear).frame(width: 4).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                        if sidebarDragStart == nil { sidebarDragStart = sidebarWidth }
                        var transaction = Transaction(); transaction.animation = nil
                        withTransaction(transaction) {
                            sidebarWidth = min(ChocoTheme.sidebarMaxWidth, max(ChocoTheme.sidebarWidth, (sidebarDragStart ?? ChocoTheme.sidebarWidth) + value.translation.width))
                        }
                    }.onEnded { _ in sidebarDragStart = nil })
                    .accessibilityLabel("サイドバーの幅")
            }
            .opacity(sidebarPresented ? 1 : 0)
            .animation(opacityAnimation, value: sidebarPresented)
            .offset(x: sidebarPresented ? (floatingSidebar ? 6 : 0) : -sidebarWidth, y: floatingSidebar ? 6 : 0)
            .animation(sidebarAnimation, value: sidebarPose)
            .allowsHitTesting(sidebarPresented && !modalPresented)
            .onHover { hovering in
                // The chrome is always mounted, so its actual pointer state survives
                // peek-to-pin instead of being reset by a second view's creation.
                sidebarHovered = sidebarPresented && hovering
                peekDismissTask?.cancel()
                if !sidebarHovered { schedulePeekDismissal() }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(model.state.sidebarVisible ? "sidebar-docked" : "sidebar-peek")
            // Hide after wrapping, so a dismissed sidebar leaves no empty labelled container behind.
            .accessibilityHidden(!sidebarPresented || modalPresented)
    }

    private var hiddenSidebarControls: some View {
        Button { model.send(.toggleSidebar) } label: {
            DesignIcon("de36e", size: 16).frame(width: ChocoSpace.u(28), height: ChocoSpace.u(28))
                .background(theme.sidebar.opacity(0.95), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(ChocoPressStyle()).help("サイドバーを表示 (⌘S)")
        .accessibilityLabel("サイドバーを表示").accessibilityIdentifier("show-sidebar")
        .padding(.leading, ChocoSpace.lg).padding(.top, 28 - ChocoSpace.u(28) / 2) // keeps the button centred where the native traffic lights are
    }

    private var commandLayer: some View {
        GeometryReader { geometry in
            ZStack {
                if commandPresented {
                    Color.black.opacity(0.001).ignoresSafeArea()
                        .contentShape(Rectangle()).onTapGesture { model.commandMode = nil }
                        // A tappable backdrop would otherwise merge the whole layer into one accessibility
                        // container, stretching the palette's frame to the window.
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    CommandPalette(model: model)
                        .frame(width: min(ChocoSpace.u(668), geometry.size.width - 2 * ChocoSpace.xl))
                        .fixedSize(horizontal: false, vertical: true)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(commandAnimation, value: commandPresented)
        }
        .allowsHitTesting(commandPresented)
        .accessibilityHidden(!commandPresented)
    }

    /// Figma 8b / 8d / 8e: the dialog is centred over the page, beside a docked sidebar. The page's own dim is in `mainLayout`.
    private func extensionDialogLayer(size: CGSize) -> some View {
        let inset = model.showsArchive ? ChocoTheme.archiveWidth : model.state.sidebarVisible ? sidebarWidth : 0
        return ExtensionDialogLayer(model: model, surface: .browser)
            .frame(width: max(0, size.width - inset), height: size.height)
            .offset(x: inset)
    }

    private func revealSidebar() {
        guard !model.state.sidebarVisible, !model.showsArchive, !modalPresented, model.editor == nil else { return }
        peekDismissTask?.cancel()
        sidebarPeek = true
    }

    private func schedulePeekDismissal() {
        peekDismissTask?.cancel()
        guard sidebarPeek && !sidebarHovered && !edgeHovered && !model.showsSiteControls && !model.showsNewMenu && model.editor == nil else { return }
        peekDismissTask = Task { @MainActor in
            while true {
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled && !sidebarHovered && !edgeHovered && !model.showsSiteControls && !model.showsNewMenu && model.editor == nil else { return }
                // A fast pointer jump from the reveal edge into the sidebar can skip its hover-enter event,
                // so trust the real pointer position before dismissing.
                guard pointerIsOverSidebar else { sidebarPeek = false; return }
            }
        }
    }

    private var pointerIsOverSidebar: Bool {
        guard let window = model.browserWindow, let content = window.contentView else { return false }
        let point = window.mouseLocationOutsideOfEventStream
        // The floating sidebar is inset 6pt and drawn at `sidebarWidth`.
        return content.bounds.contains(point) && point.x <= sidebarWidth + 6
    }

    private func configureWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        TrafficLightInset.install(on: window, inset: 6, scale: ChocoSpace.scale)
        window.backgroundColor = NSColor(red: 94 / 255, green: 92 / 255, blue: 92 / 255, alpha: 1)
        let hidden = !model.state.sidebarVisible && !sidebarPeek && !model.showsArchive
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = hidden
        }
    }

    private func updateWindowControls() {
        if let window = model.browserWindow { configureWindow(window) }
    }

    private var findBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("ページ内を検索", text: $model.findText)
                .accessibilityIdentifier("find-input")
                .focused($findFocused)
                .task {
                    // Menu key equivalents restore the previous responder after onAppear (see the command bar).
                    await Task.yield()
                    do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                    guard model.showsFind, !Task.isCancelled else { return }
                    findFocused = true
                }
                .textFieldStyle(.plain).onSubmit { model.activeSession?.find(model.findText) }
                .onChange(of: model.findText) { _, value in model.activeSession?.find(value) }
            Button { model.activeSession?.find(model.findText, backwards: true) } label: { Image(systemName: "chevron.up") }
            Button { model.activeSession?.find(model.findText) } label: { Image(systemName: "chevron.down") }
            Button { model.showsFind = false } label: { Image(systemName: "xmark") }
        }.buttonStyle(.borderless).padding(ChocoSpace.u(10)).background(.background)
    }

    /// Resolve only currently selected Core records. Retiring presentations keep
    /// their existing session references and never recreate a closed WebView.
    private var desiredPageSnapshots: [PageSnapshot] {
        let ids = model.visibleTabIDs
        let fraction = CGFloat(model.state.split?.fraction ?? 0.5)
        let pages = ids.enumerated().compactMap { index, id -> PageSnapshot? in
            guard let tab = model.state.tabs.first(where: { $0.id == id }) else { return nil }
            return PageSnapshot(
                id: id, tabID: id, session: model.session(for: tab),
                layout: PageLayout(
                    widthFraction: ids.count == 2 ? (index == 0 ? fraction : 1 - fraction) : 1,
                    leadingFraction: ids.count == 2 && index == 1 ? fraction : 0,
                    trailingPane: ids.count == 2 && index == 1,
                    split: ids.count == 2
                )
            )
        }
        if !pages.isEmpty { return pages }
        if let id = model.state.selectedFavoriteID,
           let favorite = model.state.favorites.first(where: { $0.id == id }) {
            let session = model.session(for: favorite)
            return [PageSnapshot(id: session.id, tabID: nil, session: session, layout: .single)]
        }
        return []
    }

    private var content: some View {
        // A single persistent UUID-keyed cache hosts both single and Split pages.
        // Retirees are positioned overlays, not extra layout slots or cloned views.
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                welcome
                    .opacity(welcomePhase)
                    .animation(welcomeAnimates && !reduceMotion ? ChocoMotion.tabLifecycle : nil, value: welcomePhase)
                    .allowsHitTesting(presentedSelectionIDs.isEmpty)
                    .accessibilityHidden(!presentedSelectionIDs.isEmpty)
                ForEach(pagePresentations) { page in
                    let available = max(0, geometry.size.width - (page.layout.split ? 5 : 0))
                    BrowserPane(model: model, session: page.session, tabID: page.tabID)
                        .frame(width: available * page.layout.widthFraction, height: geometry.size.height)
                        .offset(x: available * page.layout.leadingFraction + (page.layout.trailingPane ? 5 : 0))
                        .modifier(TabPageMotion(progress: page.phase))
                        .animation(page.animatesPhase && !reduceMotion ? ChocoMotion.tabLifecycle : nil, value: page.phase)
                        .animation(page.animatesLayout && !reduceMotion ? ChocoMotion.tabLifecycle : nil, value: page.layout)
                        .allowsHitTesting(!page.retiring)
                        .accessibilityHidden(page.retiring)
                        .zIndex(page.retiring ? 0 : 1)
                }
                if let split = model.state.split {
                    Rectangle().fill(ChocoTheme.divider).frame(width: 5)
                        .contentShape(Rectangle())
                        .offset(x: max(0, geometry.size.width - 5) * split.fraction)
                        .onHover { if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                        .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                            guard let current = model.state.split else { return }
                            if splitDragStart == nil { splitDragStart = current.fraction }
                            model.store.send(.setSplitFraction((splitDragStart ?? 0.5) + value.translation.width / geometry.size.width))
                        }.onEnded { _ in splitDragStart = nil })
                        .accessibilityLabel("分割の幅")
                        .zIndex(2)
                }
            }
        }
    }

    private func synchronizePages(forceImmediate: Bool = false) {
        let coreIDs = model.state.tabs.map(\.id)
        let snapshots = desiredPageSnapshots
        let desiredIDs = snapshots.map(\.id)
        let lifecycle = initializedPages && observedCoreTabIDs != coreIDs
        let selectionChanged = presentedSelectionIDs != desiredIDs
        let sessionChanged = snapshots.contains { snapshot in
            pagePresentations.contains { $0.id == snapshot.id && $0.session !== snapshot.session }
        }
        observedCoreTabIDs = coreIDs
        presentedSelectionIDs = desiredIDs
        if !initializedPages || forceImmediate || reduceMotion || (!lifecycle && (sessionChanged || selectionChanged)) {
            pagePresentations.forEach { $0.cancelTasks() }
            pagePresentations = snapshots.map { PagePresentation(snapshot: $0, phase: 1) }
            welcomeAnimates = false
            welcomePhase = snapshots.isEmpty ? 1 : 0
            initializedPages = true
            return
        }
        initializedPages = true
        let desired = Set(desiredIDs)
        let previous = Dictionary(uniqueKeysWithValues: pagePresentations.map { ($0.id, $0) })
        if !lifecycle {
            // URL/title/loading and interactive Split resizing must not cancel an
            // entry/exit already in flight or start a fresh lifecycle animation.
            for snapshot in snapshots {
                guard let page = previous[snapshot.id] else { continue }
                if page.layout != snapshot.layout {
                    page.animatesLayout = false
                    page.layout = snapshot.layout
                }
            }
            return
        }
        var active: [PagePresentation] = []
        var entries: [PagePresentation] = []
        var revived: [PagePresentation] = []
        for snapshot in snapshots {
            if let page = previous[snapshot.id], page.session === snapshot.session {
                let wasRetiring = page.retiring
                page.retirementTask?.cancel(); page.retirementTask = nil
                page.retiring = false
                page.animatesLayout = true
                withAnimation(tabAnimation) { page.layout = snapshot.layout }
                active.append(page)
                if wasRetiring { revived.append(page) }
            } else {
                // A just-restored UUID can have a new session while its disposed
                // predecessor is still fading. Replace that one host, never clone it.
                previous[snapshot.id]?.cancelTasks()
                let page = PagePresentation(snapshot: snapshot, phase: 0)
                page.animatesPhase = true
                active.append(page); entries.append(page)
            }
        }
        let retiring = pagePresentations.filter { !desired.contains($0.id) }
        pagePresentations = retiring + active
        for page in retiring where !page.retiring {
            page.entryTask?.cancel(); page.entryTask = nil
            page.retiring = true
            page.animatesPhase = true
            withAnimation(tabAnimation) { page.phase = 0 }
            page.retirementTask = Task { @MainActor [weak page] in
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                guard !Task.isCancelled, let page, page.retiring, !presentedSelectionIDs.contains(page.id) else { return }
                pagePresentations.removeAll { $0 === page }
            }
        }
        for page in revived {
            page.entryTask?.cancel(); page.entryTask = nil
            page.animatesPhase = true
            withAnimation(tabAnimation) { page.phase = 1 }
        }
        for page in entries {
            // Mount the zero-phase native host for one display beat before
            // changing its always-applied modifier; AnyTransition is not involved.
            page.entryTask = Task { @MainActor [weak page] in
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                guard !Task.isCancelled, let page, !page.retiring, presentedSelectionIDs.contains(page.id),
                      pagePresentations.contains(where: { $0 === page }) else { return }
                withAnimation(tabAnimation) { page.phase = 1 }
            }
        }
        welcomeAnimates = true
        withAnimation(tabAnimation) { welcomePhase = snapshots.isEmpty ? 1 : 0 }
    }

    /// With no tab open the page area is just the dim gradient; there is no message or button.
    private var welcome: some View {
        SpaceEmptyContent(theme: theme).frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityHidden(true)
    }
}

private struct BrowserPane: View {
    @Bindable var model: AppModel
    let session: WebSession
    let tabID: UUID?
    var body: some View {
        ZStack {
            if session.url == nil || session.url?.absoluteString == "about:blank" {
                VStack(spacing: ChocoSpace.u(14)) {
                    Image(systemName: "sparkle").font(.system(size: ChocoSpace.u(40), weight: .light)).foregroundStyle(ChocoTheme.secondary)
                    Text("新しいタブ").font(.title2.weight(.medium))
                    Button("検索またはURLを入力  ⌘L") { model.showCommand(.navigate) }.buttonStyle(.bordered)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WebViewMount(webView: session.webView) { model.focusTab(tabID) }
            }
            if let message = session.errorMessage {
                VStack(spacing: ChocoSpace.md) {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                    Text("ページを開けませんでした").font(.headline)
                    Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("再試行") { session.reload() }.buttonStyle(.borderedProminent)
                }.padding(ChocoSpace.u(30)).frame(maxWidth: ChocoSpace.u(480))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { model.focusTab(tabID) })
        .overlay {
            if model.state.split != nil && model.focusedPaneID == tabID {
                Rectangle().strokeBorder(model.tint.opacity(0.45), lineWidth: 1).allowsHitTesting(false)
            }
        }
    }
}

struct WebViewMount: NSViewRepresentable {
    let webView: WKWebView
    let onFocus: () -> Void
    func makeNSView(context: Context) -> WebViewContainer {
        let container = WebViewContainer()
        container.onFocus = onFocus
        attach(to: container)
        return container
    }
    func updateNSView(_ nsView: WebViewContainer, context: Context) { nsView.onFocus = onFocus; attach(to: nsView) }
    private func attach(to container: NSView) {
        guard webView.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

private struct WindowReference: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> WindowReferenceView {
        let view = WindowReferenceView()
        view.onWindow = onWindow
        return view
    }
    func updateNSView(_ nsView: WindowReferenceView, context: Context) { nsView.onWindow = onWindow }
}
private final class WindowReferenceView: NSView {
    var onWindow: ((NSWindow) -> Void)?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { onWindow?(window) }
    }
}

final class WebViewContainer: NSView {
    var onFocus: (() -> Void)?
    override func layout() {
        super.layout()
        let frame = convert(bounds, to: nil)
        MotionDiagnostics.record("native-page", value: Double(frame.width), x: Double(frame.minX))
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let target = super.hitTest(point)
        if target != nil, NSApp.currentEvent?.type == .leftMouseDown { onFocus?() }
        return target
    }
}

/// The Figma spring overshoots by 5.27%. Clamp the *presented* reservation, not
/// just its target, so closing toward zero never asks SwiftUI for a negative width.
private struct SidebarReservation: AnimatableModifier {
    nonisolated var width: CGFloat
    nonisolated var animatableData: CGFloat {
        get { width }
        set { width = newValue }
    }
    func body(content: Content) -> some View {
        MotionDiagnostics.record("sidebar-reservation", value: Double(width))
        return content.frame(width: max(0, width))
    }
}

private struct PageLayout: Equatable {
    var widthFraction: CGFloat
    var leadingFraction: CGFloat
    var trailingPane: Bool
    var split: Bool
    static let single = PageLayout(widthFraction: 1, leadingFraction: 0, trailingPane: false, split: false)
}

private struct PageSnapshot {
    let id: UUID
    let tabID: UUID?
    let session: WebSession
    let layout: PageLayout
}

@MainActor @Observable private final class PagePresentation: Identifiable {
    let id: UUID
    let tabID: UUID?
    let session: WebSession
    var layout: PageLayout
    var phase: Double
    var retiring = false
    var animatesPhase = false
    var animatesLayout = false
    @ObservationIgnored var entryTask: Task<Void, Never>?
    @ObservationIgnored var retirementTask: Task<Void, Never>?

    init(snapshot: PageSnapshot, phase: Double) {
        id = snapshot.id; tabID = snapshot.tabID; session = snapshot.session
        layout = snapshot.layout; self.phase = phase
    }
    func cancelTasks() {
        entryTask?.cancel(); entryTask = nil
        retirementTask?.cancel(); retirementTask = nil
    }
}

/// An instrumentable fade/6-point slide; diagnostics observe presentation values,
/// never drive the animation or mutate browser state.
private struct TabPageMotion: AnimatableModifier {
    nonisolated var progress: Double
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        MotionDiagnostics.record("tab-page", value: progress)
        return content.opacity(progress).offset(y: 6 * (1 - progress))
    }
}
