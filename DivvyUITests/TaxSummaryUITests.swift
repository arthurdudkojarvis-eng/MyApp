import XCTest

final class TaxSummaryUITests: XCTestCase {

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

    func testTaxSummaryNavigationTitle() {
        navigateToTaxSummary()
        let navBar = app.navigationBars["Tax Summary"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Tax Summary should show navigation title"
        )
    }

    // MARK: - Content States

    func testTaxSummaryShowsContentOrEmptyState() {
        navigateToTaxSummary()
        let emptyTitle = app.staticTexts["No Payments Logged"]
        let allTimeTotals = app.staticTexts["All-Time Totals"]
        XCTAssertTrue(
            emptyTitle.waitForExistence(timeout: 5)
            || allTimeTotals.waitForExistence(timeout: 5),
            "Tax Summary should show totals or empty state"
        )
    }

    // MARK: - Totals Card (data-dependent)

    func testTaxSummaryTotalsCardExists() throws {
        navigateToTaxSummary()
        let allTimeTotals = app.staticTexts["All-Time Totals"]
        guard allTimeTotals.waitForExistence(timeout: 5) else {
            throw XCTSkip("No payments logged — tax summary shows empty state")
        }
        let grossIncome = app.staticTexts["Gross Income"]
        let netIncome = app.staticTexts["Net Income"]
        XCTAssertTrue(
            grossIncome.waitForExistence(timeout: 3),
            "Totals card should show 'Gross Income'"
        )
        XCTAssertTrue(
            netIncome.waitForExistence(timeout: 3),
            "Totals card should show 'Net Income'"
        )
    }

    // MARK: - Export Button (data-dependent)

    func testTaxSummaryExportButtonExists() throws {
        navigateToTaxSummary()
        let allTimeTotals = app.staticTexts["All-Time Totals"]
        guard allTimeTotals.waitForExistence(timeout: 5) else {
            throw XCTSkip("No payments logged — export button not visible")
        }
        let exportButton = app.staticTexts["Export as CSV"]
        // Scroll down to find export button
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        scrollView.swipeUp()
        XCTAssertTrue(
            exportButton.waitForExistence(timeout: 3),
            "Tax Summary should have 'Export as CSV' button"
        )
    }

    // MARK: - Helpers

    private func navigateToTaxSummary() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let link = app.staticTexts["Tax Summary"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
    }
}
