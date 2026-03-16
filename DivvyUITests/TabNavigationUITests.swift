import XCTest

final class TabNavigationUITests: XCTestCase {

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

    // MARK: - Tab Bar

    func testAllFiveTabsExist() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar must exist")

        XCTAssertTrue(app.tabBars.buttons["Dashboard"].exists, "Dashboard tab must exist")
        XCTAssertTrue(app.tabBars.buttons["Portfolios"].exists, "Portfolios tab must exist")
        XCTAssertTrue(app.tabBars.buttons["Stocks"].exists, "Stocks tab must exist")
        XCTAssertTrue(app.tabBars.buttons["ETFs"].exists, "ETFs tab must exist")
        XCTAssertTrue(app.tabBars.buttons["Crypto"].exists, "Crypto tab must exist")
    }

    func testSwitchToDashboardTab() {
        let tab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(tab.isSelected, "Dashboard tab should be selected")
    }

    func testSwitchToPortfoliosTab() {
        let tab = app.tabBars.buttons["Portfolios"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(tab.isSelected, "Portfolios tab should be selected")
    }

    func testSwitchToStocksTab() {
        let tab = app.tabBars.buttons["Stocks"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(tab.isSelected, "Stocks tab should be selected")
    }

    func testSwitchToETFsTab() {
        let tab = app.tabBars.buttons["ETFs"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(tab.isSelected, "ETFs tab should be selected")
    }

    func testSwitchToCryptoTab() {
        let tab = app.tabBars.buttons["Crypto"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(tab.isSelected, "Crypto tab should be selected")
    }

    func testTabSwitchingRoundTrip() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        // Cycle through all tabs
        for tabName in ["Portfolios", "Stocks", "ETFs", "Crypto", "Dashboard"] {
            app.tabBars.buttons[tabName].tap()
            XCTAssertTrue(
                app.tabBars.buttons[tabName].isSelected,
                "\(tabName) tab should be selected after tapping"
            )
        }
    }
}
