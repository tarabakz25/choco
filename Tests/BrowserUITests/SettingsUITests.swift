import XCTest

@MainActor final class SettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(session: String = UUID().uuidString) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--test-session", session]
        app.launch()
        XCTAssertTrue(app.buttons["current-url"].waitForExistence(timeout: 15))
    }

    private func openSettings() {
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings-tab-general"].waitForExistence(timeout: 5))
    }

    @discardableResult
    private func selectPage(_ title: String) -> XCUIElement {
        app.buttons["settings-tab-\(title.lowercased())"].click()
        let window = app.windows[title]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Settings should display the \(title) page")
        return window
    }

    private func capture(_ window: XCUIElement, name: String) {
        app.activate()
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var tabButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "select-tab-"))
    }

    private func profile(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "settings-profile-", name
        )).firstMatch
    }

    func testSettingsPagesSearchAndWindowClose() throws {
        launch()
        defer { app.terminate() }
        let originalTab = tabButtons.firstMatch.identifier
        let originalTabCount = tabButtons.count
        openSettings()

        let general = selectPage("General")
        XCTAssertEqual(general.frame.width, 684, accuracy: 4)
        XCTAssertEqual(general.frame.height, 650, accuracy: 4)
        XCTAssertTrue(general.descendants(matching: .any).matching(identifier: "settings-appearance").firstMatch.exists)
        XCTAssertTrue(general.descendants(matching: .any).matching(identifier: "settings-motion").firstMatch.exists)
        capture(general, name: "settings-general")

        let profiles = selectPage("Profiles")
        XCTAssertTrue(profile(named: "デフォルト").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings-add-profile"].exists)
        capture(profiles, name: "settings-profiles")

        let shortcuts = selectPage("Shortcuts")
        let search = app.textFields["settings-shortcut-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("New Tab")
        XCTAssertTrue(shortcuts.staticTexts["New Tab"].waitForExistence(timeout: 5))
        XCTAssertFalse(shortcuts.staticTexts["Reload Page"].exists)
        search.typeKey("a", modifierFlags: .command)
        search.typeText("no-matching-shortcut-\(UUID().uuidString)")
        XCTAssertTrue(shortcuts.staticTexts["一致するショートカットがありません"].waitForExistence(timeout: 5))
        XCTAssertFalse(shortcuts.staticTexts["New Tab"].exists)
        search.typeKey("a", modifierFlags: .command)
        search.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(shortcuts.staticTexts["New Tab"].waitForExistence(timeout: 5))
        capture(shortcuts, name: "settings-shortcuts")

        let advanced = selectPage("Advanced")
        XCTAssertTrue(advanced.staticTexts["Play choco-browser sound effects"].exists)
        capture(advanced, name: "settings-advanced")
        app.typeKey("w", modifierFlags: .command)
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: advanced)
        wait(for: [closed], timeout: 5)
        XCTAssertTrue(app.buttons["current-url"].waitForExistence(timeout: 5))
        XCTAssertEqual(tabButtons.count, originalTabCount)
        XCTAssertTrue(app.buttons[originalTab].exists, "Closing Settings must preserve the browser tab")
    }

    func testProfileCreatedFromSettingsPersistsAfterRelaunch() throws {
        let session = UUID().uuidString
        let profileName = "Settings Profile \(UUID().uuidString.prefix(8))"
        launch(session: session)
        defer { app.terminate() }
        openSettings()
        selectPage("Profiles")
        XCTAssertTrue(profile(named: "デフォルト").waitForExistence(timeout: 5))
        app.buttons["settings-add-profile"].click()
        let name = app.textFields["editor-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText(profileName)
        app.buttons["editor-save"].click()
        XCTAssertTrue(profile(named: profileName).waitForExistence(timeout: 5))
        XCTAssertTrue(app.windows["Profiles"].exists, "Profile creation should return to Settings")

        // A normal quit waits for the app's asynchronous persistence flush.
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        XCTAssertTrue(app.buttons["current-url"].waitForExistence(timeout: 15))
        openSettings()
        selectPage("Profiles")
        XCTAssertTrue(profile(named: profileName).waitForExistence(timeout: 5))
        XCTAssertTrue(profile(named: "デフォルト").exists)
    }
}
