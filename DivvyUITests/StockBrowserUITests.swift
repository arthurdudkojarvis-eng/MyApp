import XCTest

final class StockBrowserUITests: XCTestCase {

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

    // MARK: - Stock Browser Tab

    func testStocksTabShowsBrowser() {
        navigateToStocks()
        // Verify the toolbar buttons exist
        let tipsButton = app.buttons["Stock tips"]
        XCTAssertTrue(
            tipsButton.waitForExistence(timeout: 5),
            "Stock tips button must exist"
        )
    }

    func testStockTipsButtonExists() {
        navigateToStocks()
        let tipsButton = app.buttons["Stock tips"]
        XCTAssertTrue(tipsButton.waitForExistence(timeout: 5), "Stock tips button must exist")
    }

    func testStockScreenerButtonExists() {
        navigateToStocks()
        let screenerButton = app.buttons["Stock screener"]
        XCTAssertTrue(screenerButton.waitForExistence(timeout: 5), "Stock screener button must exist")
    }

    func testStockTipsOpensSheet() {
        navigateToStocks()
        let tipsButton = app.buttons["Stock tips"]
        XCTAssertTrue(tipsButton.waitForExistence(timeout: 5))
        tipsButton.tap()

        // Verify tips sheet content appears
        let content = app.scrollViews.firstMatch
        XCTAssertTrue(
            content.waitForExistence(timeout: 5),
            "Stock tips sheet should appear"
        )
    }

    func testStockScreenerOpensSheet() {
        navigateToStocks()
        let screenerButton = app.buttons["Stock screener"]
        XCTAssertTrue(screenerButton.waitForExistence(timeout: 5))
        screenerButton.tap()

        // Verify screener sheet content appears
        let content = app.scrollViews.firstMatch
        XCTAssertTrue(
            content.waitForExistence(timeout: 5),
            "Stock screener sheet should appear"
        )
    }

    func testSearchFieldExists() {
        navigateToStocks()
        // SwiftUI .searchable creates a search field in the navigation bar
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Search field should exist on Stocks tab"
        )
    }

    func testPopularStockCategoriesExist() {
        navigateToStocks()
        // Check that at least one popular category section exists
        let dividendAristocrats = app.staticTexts["Dividend Aristocrats"]
        let blueChip = app.staticTexts["Blue Chip Leaders"]
        XCTAssertTrue(
            dividendAristocrats.waitForExistence(timeout: 5)
            || blueChip.waitForExistence(timeout: 5),
            "At least one popular stock category should be visible"
        )
    }

    // MARK: - Filters

    func testStockFiltersIconExists() {
        navigateToStocks()
        let filtersButton = app.buttons["Filters"]
        XCTAssertTrue(
            filtersButton.waitForExistence(timeout: 5),
            "Filters icon should exist on Stocks tab toolbar"
        )
    }

    // MARK: - Search

    func testStockSearchFieldAcceptsInput() {
        navigateToStocks()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("AAPL")
        // Verify text was entered
        XCTAssertEqual(searchField.value as? String, "AAPL", "Search field should accept text input")
    }

    // MARK: - Helpers

    private func navigateToStocks() {
        let tab = app.tabBars.buttons["Stocks"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
}
