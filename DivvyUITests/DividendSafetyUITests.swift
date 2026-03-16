import XCTest

final class DividendSafetyUITests: XCTestCase {

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

    func testDividendSafetyNavigationTitle() {
        navigateToDividendSafety()
        let navBar = app.navigationBars["Dividend Safety"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Dividend Safety should show navigation title"
        )
    }

    // MARK: - Content States

    func testDividendSafetyShowsContentOrEmptyState() {
        navigateToDividendSafety()
        let noHoldings = app.staticTexts["No Holdings"]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(
            noHoldings.waitForExistence(timeout: 5)
            || scrollView.waitForExistence(timeout: 5),
            "Dividend Safety should show risk indicators or empty state"
        )
    }

    // MARK: - Helpers

    private func navigateToDividendSafety() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let link = app.staticTexts["Dividend Safety"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
    }
}
