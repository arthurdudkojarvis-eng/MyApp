import XCTest

final class ETFBrowserUITests: XCTestCase {

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

    // MARK: - ETF Browser Tab

    func testETFsTabShowsBrowser() {
        navigateToETFs()
        let tipsButton = app.buttons["ETF tips"]
        XCTAssertTrue(
            tipsButton.waitForExistence(timeout: 5),
            "ETF tips button must exist on ETFs tab"
        )
    }

    func testETFTipsButtonExists() {
        navigateToETFs()
        let tipsButton = app.buttons["ETF tips"]
        XCTAssertTrue(tipsButton.waitForExistence(timeout: 5), "ETF tips button must exist")
    }

    func testETFScreenerButtonExists() {
        navigateToETFs()
        let screenerButton = app.buttons["ETF screener"]
        XCTAssertTrue(screenerButton.waitForExistence(timeout: 5), "ETF screener button must exist")
    }

    func testETFFiltersButtonExists() {
        navigateToETFs()
        let filtersButton = app.buttons["Filters"]
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 5), "Filters button must exist")
    }

    func testETFTipsOpensSheet() {
        navigateToETFs()
        let tipsButton = app.buttons["ETF tips"]
        XCTAssertTrue(tipsButton.waitForExistence(timeout: 5))
        tipsButton.tap()

        let content = app.scrollViews.firstMatch
        XCTAssertTrue(
            content.waitForExistence(timeout: 5),
            "ETF tips sheet should appear"
        )
    }

    func testETFSearchFieldExists() {
        navigateToETFs()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Search field should exist on ETFs tab"
        )
    }

    // MARK: - Helpers

    private func navigateToETFs() {
        let tab = app.tabBars.buttons["ETFs"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
}
