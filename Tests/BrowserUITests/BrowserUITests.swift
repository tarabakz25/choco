import XCTest

@MainActor final class BrowserUITests: XCTestCase {
    private var app: XCUIApplication!
    private let fixture = "http://127.0.0.1:8765"

    private func launch(session: String = UUID().uuidString) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--test-session", session, "--initial-url", fixture + "/"]
        app.launch()
        XCTAssertTrue(app.buttons["current-url"].waitForExistence(timeout: 15))
    }

    private func navigate(_ url: String, newTab: Bool = false) {
        app.typeKey(newTab ? "t" : "l", modifierFlags: .command)
        let input = app.textFields["command-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.click()
        input.typeKey("a", modifierFlags: .command)
        input.typeText(url)
        input.typeKey(.return, modifierFlags: [])
    }

    private var tabButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "select-tab-"))
    }

    private func capture(_ name: String) {
        app.activate()
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNavigationArchiveRestoreAndRelaunch() throws {
        let session = UUID().uuidString
        launch(session: session)
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Home"].waitForExistence(timeout: 15))
        navigate(fixture + "/second", newTab: true)
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Second"].waitForExistence(timeout: 15))
        XCTAssertEqual(tabButtons.count, 2)
        capture("native-sidebar-second-page")
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.buttons["current-url"].exists, "CmdW must keep main window open")
        XCTAssertEqual(tabButtons.count, 1)
        app.typeKey("t", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Second"].waitForExistence(timeout: 15))
        XCTAssertEqual(tabButtons.count, 2)
        // CmdQ exercises asynchronous flush, unlike forceful test-runner termination.
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Second"].waitForExistence(timeout: 15))
        XCTAssertEqual(tabButtons.count, 2)
        capture("native-restored-session")
        app.terminate()
    }


    func testSplitFocusNavigationAndRestoration() throws {
        let session = UUID().uuidString
        launch(session: session)
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Home"].waitForExistence(timeout: 15))
        navigate(fixture + "/second", newTab: true)
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Second"].waitForExistence(timeout: 15))
        app.descendants(matching: .any).matching(identifier: "split-toggle").firstMatch.click()
        app.menuItems["Acceptance Home"].click()
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Home"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.webViews.count, 2)
        app.webViews.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8)).click()
        navigate(fixture + "/child")
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Child"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Second"].exists, "Navigating right pane must preserve left pane")
        capture("native-split-focus")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Child"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Second"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.webViews.count, 2)
        XCTAssertTrue((app.buttons["current-url"].value as? String)?.contains("/child") == true)
        app.typeKey("w", modifierFlags: .command)
        capture("native-split-after-close")
        XCTAssertTrue(app.buttons["current-url"].exists)
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Second"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.webViews.count, 1)
        XCTAssertEqual(tabButtons.count, 1)
        app.terminate()
    }

    func testProfilesRemainSeparateThroughSpaceUI() throws {
        launch()
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Home"].waitForExistence(timeout: 15))
        let originalSpace = app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "space-[0-9A-Fa-f-]{36}")).firstMatch.identifier
        navigate(fixture + "/set-cookie?value=Alpha")
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Cookie Set"].waitForExistence(timeout: 15))
        app.descendants(matching: .any).matching(identifier: "space-menu").firstMatch.click()
        app.menuItems["プロファイルを追加…"].click()
        let name = app.textFields["editor-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click(); name.typeText("Work")
        app.buttons["editor-save"].click()
        app.buttons["add-space"].click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click(); name.typeText("Work Space")
        app.popUpButtons["profile-picker"].click()
        app.menuItems["Work"].click()
        app.buttons["editor-save"].click()
        navigate(fixture + "/cookie")
        XCTAssertTrue(app.webViews.staticTexts["Cookie echo: (none)"].waitForExistence(timeout: 15))
        capture("native-profile-work")
        app.buttons[originalSpace].click()
        navigate(fixture + "/cookie")
        XCTAssertTrue(app.webViews.staticTexts["Cookie echo: session=Alpha"].waitForExistence(timeout: 15))
        capture("native-profile-original")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Cookie echo: session=Alpha"].waitForExistence(timeout: 15))
        capture("native-profile-after-relaunch")
        app.terminate()
    }

    func testPageInputAndTargetBlankPopup() throws {
        launch()
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Home"].waitForExistence(timeout: 15))
        let input = app.webViews.textFields["Page input"]
        XCTAssertTrue(input.exists)
        input.click(); input.typeText("native typing")
        XCTAssertEqual(input.value as? String, "native typing")
        app.webViews.links["Open child tab"].click()
        XCTAssertTrue(app.webViews.staticTexts["Acceptance Child"].waitForExistence(timeout: 15))
        XCTAssertEqual(tabButtons.count, 2)
        capture("native-popup")
        app.terminate()
    }
}
