import XCTest

final class DividendCalendarUITests: XCTestCase {

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

    func testCalendarNavigationTitle() {
        navigateToCalendar()
        let navBar = app.navigationBars["Dividend Calendar"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Calendar should show 'Dividend Calendar' navigation title"
        )
    }

    // MARK: - Empty State

    func testCalendarEmptyStateShowsMessage() {
        navigateToCalendar()
        // If no dividend events, the empty state should show
        let emptyTitle = app.staticTexts["No Dividend Events"]
        let scrollView = app.scrollViews.firstMatch
        // One of these should exist depending on data state
        XCTAssertTrue(
            emptyTitle.waitForExistence(timeout: 5)
            || scrollView.waitForExistence(timeout: 5),
            "Calendar should show either empty state or calendar content"
        )
    }

    // MARK: - Calendar Content (data-dependent)

    func testCalendarStatusLegendExists() throws {
        navigateToCalendar()
        // Legend items are only visible when calendar has events
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 5) else {
            throw XCTSkip("No dividend events — calendar shows empty state")
        }
        let declared = app.staticTexts["Declared"]
        XCTAssertTrue(
            declared.waitForExistence(timeout: 3),
            "Calendar should show 'Declared' legend item"
        )
    }

    func testCalendarHasEstimatedLegend() throws {
        navigateToCalendar()
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 5) else {
            throw XCTSkip("No dividend events — calendar shows empty state")
        }
        let estimated = app.staticTexts["Estimated"]
        XCTAssertTrue(
            estimated.waitForExistence(timeout: 3),
            "Calendar should show 'Estimated' legend item"
        )
    }

    func testCalendarHasPaidLegend() throws {
        navigateToCalendar()
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 5) else {
            throw XCTSkip("No dividend events — calendar shows empty state")
        }
        let paid = app.staticTexts["Paid"]
        XCTAssertTrue(
            paid.waitForExistence(timeout: 3),
            "Calendar should show 'Paid' legend item"
        )
    }

    func testCalendarHasMarketClosedLegend() throws {
        navigateToCalendar()
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 5) else {
            throw XCTSkip("No dividend events — calendar shows empty state")
        }
        let closed = app.staticTexts["Market Closed"]
        XCTAssertTrue(
            closed.waitForExistence(timeout: 3),
            "Calendar should show 'Market Closed' legend item"
        )
    }

    func testCalendarSummaryCardExists() throws {
        navigateToCalendar()
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 5) else {
            throw XCTSkip("No dividend events — calendar shows empty state")
        }
        // Summary card has "Stocks" and "Payments" quick stats
        let stocks = app.staticTexts["Stocks"]
        let payments = app.staticTexts["Payments"]
        XCTAssertTrue(
            stocks.waitForExistence(timeout: 3),
            "Summary card should show 'Stocks' stat"
        )
        XCTAssertTrue(
            payments.waitForExistence(timeout: 3),
            "Summary card should show 'Payments' stat"
        )
    }

    // MARK: - Helpers

    private func navigateToCalendar() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let calendarLink = app.staticTexts["Dividend Calendar"]
        XCTAssertTrue(calendarLink.waitForExistence(timeout: 5))
        calendarLink.tap()
    }
}
