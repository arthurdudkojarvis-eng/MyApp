import XCTest

final class SectorAllocationUITests: XCTestCase {

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

    func testSectorAllocationNavigationTitle() {
        navigateToSectorAllocation()
        let navBar = app.navigationBars["Sector Allocation"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Sector Allocation should show navigation title"
        )
    }

    // MARK: - Content States

    func testSectorAllocationShowsContentOrEmptyState() {
        navigateToSectorAllocation()
        let noHoldings = app.staticTexts["No Holdings"]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(
            noHoldings.waitForExistence(timeout: 5)
            || scrollView.waitForExistence(timeout: 5),
            "Sector Allocation should show chart or empty state"
        )
    }

    // MARK: - Helpers

    private func navigateToSectorAllocation() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let link = app.staticTexts["Sector Allocation"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
    }
}
