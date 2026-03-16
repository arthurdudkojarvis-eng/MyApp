import XCTest

final class WatchlistUITests: XCTestCase {

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

    func testWatchlistNavigationTitle() {
        navigateToWatchlist()
        let navBar = app.navigationBars["Watchlist"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Watchlist should show navigation title"
        )
    }

    // MARK: - Toolbar

    func testAddToWatchlistButtonExists() {
        navigateToWatchlist()
        let addButton = app.buttons["Add to watchlist"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 5),
            "Add to watchlist button must exist in toolbar"
        )
    }

    func testAddToWatchlistOpensSheet() {
        navigateToWatchlist()
        let addButton = app.buttons["Add to watchlist"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // The sheet should have a text field for ticker input
        let tickerField = app.textFields.firstMatch
        XCTAssertTrue(
            tickerField.waitForExistence(timeout: 5),
            "Add to watchlist sheet should show ticker input field"
        )
    }

    // MARK: - Empty State

    func testWatchlistEmptyOrContentLoads() {
        navigateToWatchlist()
        let emptyTitle = app.staticTexts["Watchlist Empty"]
        let watchingPill = app.staticTexts["Watching"]
        XCTAssertTrue(
            emptyTitle.waitForExistence(timeout: 5)
            || watchingPill.waitForExistence(timeout: 5),
            "Watchlist should show either empty state or summary bar"
        )
    }

    // MARK: - Summary Bar (data-dependent)

    func testWatchlistSummaryBarExists() throws {
        navigateToWatchlist()
        let watchingPill = app.staticTexts["Watching"]
        guard watchingPill.waitForExistence(timeout: 5) else {
            throw XCTSkip("Watchlist is empty — summary bar not visible")
        }
        let payDividends = app.staticTexts["Pay Dividends"]
        let upcomingEx = app.staticTexts["Upcoming Ex"]
        XCTAssertTrue(
            payDividends.waitForExistence(timeout: 3),
            "Summary bar should show 'Pay Dividends' pill"
        )
        XCTAssertTrue(
            upcomingEx.waitForExistence(timeout: 3),
            "Summary bar should show 'Upcoming Ex' pill"
        )
    }

    // MARK: - Helpers

    private func navigateToWatchlist() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let watchlistLink = app.staticTexts["Watchlist"]
        XCTAssertTrue(watchlistLink.waitForExistence(timeout: 5))
        watchlistLink.tap()
    }
}
