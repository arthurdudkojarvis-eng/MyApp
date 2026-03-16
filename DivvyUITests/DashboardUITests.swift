import XCTest

final class DashboardUITests: XCTestCase {

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

    // MARK: - Dashboard Toolbar

    func testFeaturesMenuButtonExists() {
        navigateToDashboard()
        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(
            featuresButton.waitForExistence(timeout: 5),
            "Features menu button must exist on Dashboard"
        )
    }

    func testSettingsButtonExists() {
        navigateToDashboard()
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings button must exist on Dashboard"
        )
    }

    func testFeaturesMenuOpensSheet() {
        navigateToDashboard()
        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        // Verify the features sheet appears with feature links
        let incomeForecast = app.staticTexts["Income Forecast"]
        XCTAssertTrue(
            incomeForecast.waitForExistence(timeout: 5),
            "Features sheet should show Income Forecast link"
        )
    }

    func testSettingsOpensSheet() {
        navigateToDashboard()
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Verify the settings sheet appears
        let colorScheme = app.staticTexts["Color Scheme"]
            .waitForExistence(timeout: 5)
        let incomeGoal = app.staticTexts["Income Goal"]
            .waitForExistence(timeout: 5)
        XCTAssertTrue(colorScheme || incomeGoal, "Settings sheet should appear with expected sections")
    }

    // MARK: - Features Menu Navigation

    func testNavigateToIncomeForecast() {
        openFeaturesMenu()
        app.staticTexts["Income Forecast"].tap()
        let title = app.navigationBars["Income Forecast"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to Income Forecast")
    }

    func testNavigateToSectorAllocation() {
        openFeaturesMenu()
        app.staticTexts["Sector Allocation"].tap()
        let title = app.navigationBars["Sector Allocation"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to Sector Allocation")
    }

    func testNavigateToDRIPSimulator() {
        openFeaturesMenu()
        app.staticTexts["DRIP Simulator"].tap()
        let title = app.navigationBars["DRIP Simulator"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to DRIP Simulator")
    }

    func testNavigateToDividendSafety() {
        openFeaturesMenu()
        app.staticTexts["Dividend Safety"].tap()
        let title = app.navigationBars["Dividend Safety"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to Dividend Safety")
    }

    func testNavigateToTaxSummary() {
        openFeaturesMenu()
        app.staticTexts["Tax Summary"].tap()
        let title = app.navigationBars["Tax Summary"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to Tax Summary")
    }

    func testNavigateToWatchlist() {
        openFeaturesMenu()
        app.staticTexts["Watchlist"].tap()
        let title = app.navigationBars["Watchlist"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to Watchlist")
    }

    func testNavigateToAlerts() {
        openFeaturesMenu()
        app.staticTexts["Alerts"].tap()
        let title = app.navigationBars["Alerts"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to Alerts")
    }

    func testNavigateToDividendCalendar() {
        openFeaturesMenu()
        app.staticTexts["Dividend Calendar"].tap()
        let title = app.navigationBars["Dividend Calendar"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to Dividend Calendar")
    }

    func testNavigateToNews() {
        openFeaturesMenu()
        let newsLink = app.staticTexts["News & Events"]
        XCTAssertTrue(newsLink.waitForExistence(timeout: 5))
        newsLink.tap()
        let title = app.navigationBars["News & Events"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Should navigate to News & Events")
    }

    // MARK: - Helpers

    private func navigateToDashboard() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()
    }

    private func openFeaturesMenu() {
        navigateToDashboard()
        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()
    }
}
