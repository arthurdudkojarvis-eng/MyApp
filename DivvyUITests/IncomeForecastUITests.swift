import XCTest

final class IncomeForecastUITests: XCTestCase {

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

    // MARK: - Navigation

    func testIncomeForecastNavigationTitle() {
        navigateToIncomeForecast()
        let navBar = app.navigationBars["Income Forecast"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Income Forecast should show navigation title"
        )
    }

    // MARK: - Content States

    func testIncomeForecastShowsContentOrEmptyState() {
        navigateToIncomeForecast()
        // With holdings: shows chart. Without: shows empty state.
        let noHoldings = app.staticTexts["No Holdings"]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(
            noHoldings.waitForExistence(timeout: 5)
            || scrollView.waitForExistence(timeout: 5),
            "Income Forecast should show chart content or empty state"
        )
    }

    // MARK: - Chart Content (data-dependent)

    func testIncomeForecastHasChartWhenDataExists() throws {
        navigateToIncomeForecast()
        let noHoldings = app.staticTexts["No Holdings"]
        if noHoldings.waitForExistence(timeout: 3) {
            throw XCTSkip("No holdings — income forecast shows empty state")
        }
        // The chart area should be rendered
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(
            scrollView.waitForExistence(timeout: 5),
            "Income Forecast should show scrollable content with chart"
        )
    }

    // MARK: - Helpers

    private func navigateToIncomeForecast() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let link = app.staticTexts["Income Forecast"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
    }
}
