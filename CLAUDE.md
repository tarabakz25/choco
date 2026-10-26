# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

choco-browser is a macOS browser (SwiftUI + WKWebView) modelled on Arc's organisation UX. It is a pure Swift 6 / SwiftPM project with no external dependencies, targeting macOS 15.4+ and Xcode 16.3+. The Bun instructions in the parent `/Users/kizuki/Projects/CLAUDE.md` do not apply here. UI strings, docs and the Taskfile descriptions are in Japanese.

## Commands

Everything goes through `scripts/*.sh` (they set up the `.build/` cache/module-cache paths and pass `--disable-sandbox`; don't call bare `swift build`/`swift test` unless you replicate that). `Taskfile.yml` wraps them.

```sh
./scripts/build-app.sh [debug|release]   # builds + assembles build/choco-browser.app (ad-hoc signed)  | task build
open build/choco-browser.app             #                                                              | task run
./scripts/test.sh                        # all non-UI, non-WebKit tests                                 | task test
./scripts/test.sh --filter BrowserCoreTests                    # one target / suite
./scripts/test.sh --filter BrowserCoreTests.BrowserCoreTests/testName   # one test (args go to `swift test`)
OSS_ARC_WEBKIT_TESTS=1 ./scripts/test.sh                       # also run tests that launch real WebKit  | task test:webkit
./scripts/test-ui.sh [xcodebuild args]   # XCUITest; starts scripts/fixture-server.py on 127.0.0.1:8765  | task test:ui
```

- `swift build` alone produces only a bare executable. The `.app` bundle (Info.plist, resource bundle `choco-browser_BrowserApp.bundle`, entitlements, codesign) is assembled only by `build-app.sh`, so use it to actually launch the app.
- UI tests (`Tests/BrowserUITests`) are **not** in `Package.swift`; they only exist in `choco-browser.xcodeproj` (scheme `choco-browser`) and run through `xcodebuild`. The Xcode project uses synchronized folders over the same `Sources/` tree, so new Swift files are picked up by both SwiftPM and Xcode automatically.
- UI tests are slow: don't run `test-ui.sh` / `task test:ui` as part of routine verification. Use `./scripts/test.sh` instead, and run the UI tests only when explicitly asked.
- No linter or formatter is configured.

## Architecture

Three SwiftPM targets with a strict one-way dependency: `BrowserApp` → `BrowserRuntime`, `BrowserCore` (Runtime and Core do not depend on each other). Detail in `docs/architecture.md`; the original API contract is in `docs/implementation-contract.md`.

- **BrowserCore** (Foundation + Observation only): `@MainActor @Observable BrowserStore` owns `BrowserState` (profiles, spaces, tabs, folders, favorites, archive, split, selection). All mutations go through `store.send(BrowserAction)`; the UI must not edit state directly. `Persistence`/`Validation` handle the versioned JSON state file (atomic, serialized saves; on startup dangling references are repaired, and corrupt or unknown-`schemaVersion` files are backed up and surfaced via `persistenceError` — never silently replaced by an empty state).
- **BrowserRuntime** (WebKit/AppKit): `WebSession` wraps one `WKWebView` (navigation state, delegates, downloads, popups, JS dialogs); `WebSessionPool` creates and caches sessions by tab ID + profile ID; `AddressResolver` turns omnibox input into a URL or Google search. `Extensions/` installs Chrome extensions (folder/ZIP/CRX/Web Store) and keeps one `WKWebExtensionController` per Profile.
- **BrowserApp** (SwiftUI): `AppModel` is the glue — it owns the `BrowserStore` and `WebSessionPool`, syncs sessions to store state (disposing sessions of closed/re-profiled tabs), and feeds WebKit URL/title callbacks back via `updatePage` without triggering reloads. `NSViewRepresentable` views only *mount* an existing `session.webView`; they must never create one on redraw. `Features/<Area>` holds screens (Browser, Sidebar, Settings, CommandPalette, Archive, Editing, Extensions); `DesignSystem` holds shared tokens (`ChocoTheme`, `ChocoSpace`), icons and motion. `BrowserApp` is a single module — folders are organisational only.

Model semantics that span files:
- **Profile** = Cookie/data isolation unit; its UUID doubles as the `WKWebsiteDataStore` identifier. **Space** references one Profile and owns tabs/folders. Changing a Space's Profile discards and recreates the WebView; cookies are never copied.
- **Favorites** are global link definitions (max 12), but their live WebView is keyed per Favorite+Profile and is never inserted as a normal tab.
- **Split** holds references to two existing same-Space tabs; closing/archiving/moving a member collapses it. **Folders** contain only pinned tabs; deleting one reparents its children.
- Closing a Today tab archives it; closing a pinned tab keeps the registration.
- State persists URL/layout/names only — not DOM, form input, JS state or full back-history.
- Hidden restored tabs must not hit the network at launch; only visible tab(s) get a session.

## Conventions and gotchas

- Compatibility names are intentionally kept from the project's earlier name: bundle id `org.ossarc.browser`, storage dir `Application Support/OssArc` (UI tests use `OssArcUITests/<UUID>`), env var `OSS_ARC_WEBKIT_TESTS`. Don't "fix" them.
- Don't use private WebKit APIs, don't auto-approve TLS errors, and don't depend on the macOS 26-only SwiftUI `WebView`.
- Fonts (Inter, Noto Sans JP) and SVG/PDF icons are bundled from `Sources/BrowserApp/Resources` and loaded via `DesignIcon`/`SiteIcon`; keep the resource paths/filenames stable (see `docs/figma-ui.md`, `THIRD_PARTY.md`). The UI follows a specific Figma file; `docs/figma-ui.md` records which frames are implemented, exact sizes/timings, and which items are deliberately disabled — check it before changing sidebar, command bar, site controls, archive or settings visuals.
- Motion goes through the shared curves in `DesignSystem/Motion` and must honour the in-app motion preference (system / on / reduced).
- Tests that need a real WebKit process are gated behind `OSS_ARC_WEBKIT_TESTS=1` and use isolated test profiles.
