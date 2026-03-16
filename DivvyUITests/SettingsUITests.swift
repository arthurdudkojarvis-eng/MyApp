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
