import XCTest

@MainActor final class LocalizationUITests: XCTestCase {
    private var app: XCUIApplication!

    func testLanguageSwitchUpdatesOpenWindowsAndPersistsAcrossRelaunch() throws {
        continueAfterFailure = false
        let session = UUID().uuidString
        app = XCUIApplication()
        defer { app.terminate() }
        app.launchArguments = ["--test-session", session, "--app-language", "ja", "--initial-url", "http://127.0.0.1:8765/"]
        app.launch()

        let newTab = app.buttons["new-tab"]
        XCTAssertTrue(newTab.waitForExistence(timeout: 15))
        XCTAssertTrue(newTab.label.contains("新しいタブ"))
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Home"].waitForExistence(timeout: 15))
        let pageInput = app.webViews.textFields["Page input"]
        pageInput.click()
        pageInput.typeText("keep this page input")
        let initialTabs = tabIdentifiers
        XCTAssertFalse(initialTabs.isEmpty)

        // Keep an unfinished address edit open while changing another window.
        // Switching language must preserve the browser's state and view identity.
        app.typeKey("l", modifierFlags: .command)
        let addressInput = app.textFields["command-input"]
        XCTAssertTrue(addressInput.waitForExistence(timeout: 5))
        addressInput.click()
        addressInput.typeKey("a", modifierFlags: .command)
        let pendingAddress = "https://example.test/unfinished-address"
        addressInput.typeText(pendingAddress)

        openSettings()
        XCTAssertTrue(app.staticTexts["外観"].exists)
        selectLanguage("English")
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 5))
        capture("settings-english", window: settingsWindow)
        closeSettings()

        XCTAssertTrue(newTab.waitForExistence(timeout: 5))
        XCTAssertTrue(newTab.label.contains("New Tab"))
        XCTAssertEqual(tabIdentifiers, initialTabs, "Language changes must retain existing tabs")
        XCTAssertTrue(addressInput.waitForExistence(timeout: 5))
        XCTAssertEqual(addressInput.value as? String, pendingAddress)
        addressInput.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(pageInput.value as? String, "keep this page input", "Switching language must preserve the live page")
        assertSpaceMenuTitle("Settings…")
        assertCommandSearch(query: "Open Archive", title: "Open Archive", subtitle: "Command")
        capture("browser-english", window: app.windows.firstMatch)

        // Quit normally so the same test session can restore its browser state.
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launchArguments = ["--test-session", session]
        app.launch()
        XCTAssertTrue(newTab.waitForExistence(timeout: 15))
        XCTAssertTrue(newTab.label.contains("New Tab"), "The saved language must survive relaunch")
        XCTAssertEqual(tabIdentifiers, initialTabs)

        openSettings()
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
        selectLanguage("日本語")
        XCTAssertTrue(app.staticTexts["外観"].waitForExistence(timeout: 5))
        capture("settings-japanese", window: settingsWindow)
        closeSettings()
        XCTAssertTrue(newTab.label.contains("新しいタブ"))
        XCTAssertEqual(tabIdentifiers, initialTabs)
        assertSpaceMenuTitle("設定…")
        // A Latin query avoids invoking the host IME while still matching a Japanese command.
        assertCommandSearch(query: "Today", title: "Todayをすべて閉じる", subtitle: "コマンド")
        capture("browser-japanese", window: app.windows.firstMatch)
    }

    private var languagePicker: XCUIElement { app.radioButtons["English"] }

    private var settingsWindow: XCUIElement {
        app.windows.containing(.radioButton, identifier: "English").firstMatch
    }

    private var tabIdentifiers: [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "select-tab-"))
            .allElementsBoundByIndex.map(\.identifier).sorted()
    }

    private func openSettings() {
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 5))
    }

    private func selectLanguage(_ title: String) {
        let option = app.radioButtons[title]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.click()
    }

    private func closeSettings() {
        settingsWindow.buttons[XCUIIdentifierCloseWindow].click()
    }

    private func assertSpaceMenuTitle(_ title: String) {
        app.descendants(matching: .any).matching(identifier: "space-menu").firstMatch.click()
        XCTAssertTrue(app.menuItems[title].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
    }

    private func assertCommandSearch(query: String, title: String, subtitle: String) {
        app.typeKey("t", modifierFlags: .command)
        let input = app.textFields["command-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.click()
        input.typeText(query)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@", title, subtitle)).firstMatch.waitForExistence(timeout: 5))
        input.typeKey(.escape, modifierFlags: [])
    }

    private func capture(_ name: String, window: XCUIElement) {
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
