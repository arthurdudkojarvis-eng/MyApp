import XCTest

final class SettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Settings Access

    func testSettingsSheetOpens() {
        openSettings()
        // Verify settings content loads
        let colorScheme = app.staticTexts["Color Scheme"]
        let incomeGoal = app.staticTexts["Income Goal"]
        XCTAssertTrue(
            colorScheme.waitForExistence(timeout: 5)
            || incomeGoal.waitForExistence(timeout: 5),
            "Settings sheet should show Color Scheme or Income Goal section"
        )
    }

    func testSettingsHasIncomeGoalSection() {
        openSettings()
        let incomeGoal = app.staticTexts["Income Goal"]
        XCTAssertTrue(
            incomeGoal.waitForExistence(timeout: 5),
            "Settings should have Income Goal section"
        )
    }

    func testSettingsHasAppearanceSection() {
        openSettings()
        let colorScheme = app.staticTexts["Color Scheme"]
        XCTAssertTrue(
            colorScheme.waitForExistence(timeout: 5),
            "Settings should have Color Scheme picker"
        )
    }

    func testSettingsHasDoneButton() {
        openSettings()
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "Settings should have Done button to dismiss"
        )
    }

    func testSettingsDoneButtonDismisses() {
        openSettings()
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        // After dismissing, the Dashboard should be visible again
        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(
            featuresButton.waitForExistence(timeout: 5),
            "Dashboard should be visible after dismissing Settings"
        )
    }

    // MARK: - Income Goal

    func testSettingsHasMonthlyTargetField() {
        openSettings()
        let monthlyTarget = app.staticTexts["Monthly Target"]
        XCTAssertTrue(
            monthlyTarget.waitForExistence(timeout: 5),
            "Settings should have Monthly Target label"
        )
    }

    func testSettingsHasIncomeTargetTextField() {
        openSettings()
        let targetField = app.textFields["Monthly income target"]
        XCTAssertTrue(
            targetField.waitForExistence(timeout: 5),
            "Settings should have monthly income target text field"
        )
    }

    // MARK: - Notifications

    func testSettingsHasWeeklyQuotesToggle() {
        openSettings()
        let toggle = app.switches["Weekly Investor Quotes"]
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 5),
            "Settings should have Weekly Investor Quotes toggle"
        )
    }

    func testSettingsHasNotificationsSectionHeader() {
        openSettings()
        let header = app.staticTexts["Notifications"]
        XCTAssertTrue(
            header.waitForExistence(timeout: 5),
            "Settings should have Notifications section header"
        )
    }

    // MARK: - Appearance

    func testSettingsHasColorSchemeSegments() {
        openSettings()
        // The segmented picker should expose System, Light, and Dark segments
        let systemOption = app.buttons["System"]
        XCTAssertTrue(
            systemOption.waitForExistence(timeout: 5),
            "Color scheme picker should have 'System' option"
        )
        XCTAssertTrue(
            app.buttons["Light"].exists,
            "Color scheme picker should have 'Light' option"
        )
        XCTAssertTrue(
            app.buttons["Dark"].exists,
            "Color scheme picker should have 'Dark' option"
        )
    }

    func testSettingsHasFontThemeLabel() {
        openSettings()
        let fontTheme = app.staticTexts["Font Theme"]
        XCTAssertTrue(
            fontTheme.waitForExistence(timeout: 5),
            "Settings should have Font Theme label"
        )
    }

    // MARK: - Helpers

    private func openSettings() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
    }
}
