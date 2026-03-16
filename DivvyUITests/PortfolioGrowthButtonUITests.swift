import XCTest

final class PortfolioGrowthButtonUITests: XCTestCase {

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

    // MARK: - Growth Projection Button Tests

    /// Verifies the growth projection button exists on portfolio holding rows.
    /// This test guards against accidental removal of the growth icon feature.
    func testGrowthProjectionButtonExistsOnHoldingRow() throws {
        let growthButton = try navigateToFirstGrowthButton()

        XCTAssertTrue(
            growthButton.waitForExistence(timeout: 5),
            "Growth projection button (chart.line.uptrend.xyaxis) not found on holding rows. "
            + "This button must exist — do not remove it."
        )
        XCTAssertTrue(growthButton.isHittable, "Growth projection button should be tappable")
    }

    /// Verifies tapping the growth projection button presents the Future Value sheet.
    func testGrowthProjectionButtonOpensSheet() throws {
        let growthButton = try navigateToFirstGrowthButton()

        XCTAssertTrue(
            growthButton.waitForExistence(timeout: 5),
            "Growth projection button not found — it may have been removed"
        )

        growthButton.tap()

        // The sheet title is "Future Value — TICKER", so match by prefix
        let sheetTitle = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Future Value")
        ).firstMatch
        XCTAssertTrue(
            sheetTitle.waitForExistence(timeout: 5),
            "Tapping growth button should present the Future Value sheet"
        )
    }

    // MARK: - Helpers

    @discardableResult
    private func navigateToFirstGrowthButton() throws -> XCUIElement {
        // Navigate to Portfolios tab
        let portfoliosTab = app.tabBars.buttons["Portfolios"]
        XCTAssertTrue(
            portfoliosTab.waitForExistence(timeout: 10),
            "Portfolios tab must always be present"
        )
        portfoliosTab.tap()

        // Tap the first portfolio in the list
        let firstPortfolio = app.cells.firstMatch
        guard firstPortfolio.waitForExistence(timeout: 5) else {
            throw XCTSkip("No portfolios found — test requires at least one portfolio with holdings")
        }
        firstPortfolio.tap()

        // Find the growth projection button by accessibility identifier prefix
        return app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "growthProjectionButton_")
        ).firstMatch
    }
}
