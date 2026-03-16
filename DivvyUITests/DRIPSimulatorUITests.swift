import XCTest

final class DRIPSimulatorUITests: XCTestCase {

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

    func testDRIPSimulatorNavigationTitle() {
        navigateToDRIP()
        let navBar = app.navigationBars["DRIP Simulator"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "DRIP Simulator should show navigation title"
        )
    }

    // MARK: - Content States

    func testDRIPShowsContentOrEmptyState() {
        navigateToDRIP()
        let noHoldings = app.staticTexts["No Holdings"]
        let projectionPeriod = app.staticTexts["Projection Period"]
        XCTAssertTrue(
            noHoldings.waitForExistence(timeout: 5)
            || projectionPeriod.waitForExistence(timeout: 5),
            "DRIP Simulator should show controls or empty state"
        )
    }

    // MARK: - Controls (data-dependent)

    func testDRIPHasProjectionPeriodControl() throws {
        navigateToDRIP()
        let projectionPeriod = app.staticTexts["Projection Period"]
        XCTAssertTrue(
            projectionPeriod.waitForExistence(timeout: 5),
            "Should show 'Projection Period' label (requires holdings)"
        )
    }

    func testDRIPHasReinvestmentRateControl() throws {
        navigateToDRIP()
        let reinvestmentRate = app.staticTexts["Reinvestment Rate"]
        XCTAssertTrue(
            reinvestmentRate.waitForExistence(timeout: 5),
            "Should show 'Reinvestment Rate' label (requires holdings)"
        )
    }

    func testDRIPHasStartingValueStat() throws {
        navigateToDRIP()
        let startingValue = app.staticTexts["Starting Value"]
        XCTAssertTrue(
            startingValue.waitForExistence(timeout: 5),
            "Should show 'Starting Value' stat (requires holdings)"
        )
    }

    func testDRIPHasAvgYieldStat() throws {
        navigateToDRIP()
        let avgYield = app.staticTexts["Avg Yield"]
        XCTAssertTrue(
            avgYield.waitForExistence(timeout: 5),
            "Should show 'Avg Yield' stat (requires holdings)"
        )
    }

    func testDRIPHasAnnualIncomeStat() throws {
        navigateToDRIP()
        let annualIncome = app.staticTexts["Annual Income"]
        XCTAssertTrue(
            annualIncome.waitForExistence(timeout: 5),
            "Should show 'Annual Income' stat (requires holdings)"
        )
    }

    func testDRIPHasSlider() throws {
        navigateToDRIP()
        let slider = app.sliders.firstMatch
        XCTAssertTrue(
            slider.waitForExistence(timeout: 5),
            "DRIP should have reinvestment rate slider (requires holdings)"
        )
    }

    func testDRIPHasStepper() throws {
        navigateToDRIP()
        let stepper = app.steppers.firstMatch
        XCTAssertTrue(
            stepper.waitForExistence(timeout: 5),
            "DRIP should have projection period stepper (requires holdings)"
        )
    }

    // MARK: - Helpers

    private func navigateToDRIP() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let link = app.staticTexts["DRIP Simulator"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
    }
}
