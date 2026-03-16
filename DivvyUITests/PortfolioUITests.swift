import XCTest

final class PortfolioUITests: XCTestCase {

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

    // MARK: - Portfolio Tab

    func testPortfoliosTabExists() {
        let tab = app.tabBars.buttons["Portfolios"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Portfolios tab must exist")
    }

    func testAddPortfolioButtonExists() {
        navigateToPortfolios()
        let addButton = app.buttons["Add portfolio"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 5),
            "Add portfolio button must exist in toolbar"
        )
    }

    func testStrategiesButtonExists() {
        navigateToPortfolios()
        let strategiesButton = app.buttons["Dividend strategies"]
        XCTAssertTrue(
            strategiesButton.waitForExistence(timeout: 5),
            "Dividend strategies button must exist in toolbar"
        )
    }

    func testAddPortfolioOpensSheet() {
        navigateToPortfolios()
        let addButton = app.buttons["Add portfolio"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Verify the Add Portfolio sheet appears with name field
        let nameField = app.textFields["Portfolio name"]
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 5),
            "Add Portfolio sheet should show portfolio name field"
        )
    }

    func testStrategiesOpensSheet() {
        navigateToPortfolios()
        let strategiesButton = app.buttons["Dividend strategies"]
        XCTAssertTrue(strategiesButton.waitForExistence(timeout: 5))
        strategiesButton.tap()

        // Verify the strategies sheet appears
        let content = app.scrollViews.firstMatch
        XCTAssertTrue(
            content.waitForExistence(timeout: 5),
            "Strategies sheet should appear"
        )
    }

    // MARK: - Portfolio Holdings (requires data)

    func testAddHoldingButtonExistsInPortfolio() throws {
        try navigateToFirstPortfolio()
        let addHoldingButton = app.buttons["Add holding"]
        XCTAssertTrue(
            addHoldingButton.waitForExistence(timeout: 5),
            "Add holding button must exist in portfolio detail"
        )
    }

    func testAddHoldingOpensSheet() throws {
        try navigateToFirstPortfolio()
        let addHoldingButton = app.buttons["Add holding"]
        XCTAssertTrue(addHoldingButton.waitForExistence(timeout: 5))
        addHoldingButton.tap()

        // Verify the Add Holding sheet with ticker field
        let tickerField = app.textFields["Ticker symbol"]
        XCTAssertTrue(
            tickerField.waitForExistence(timeout: 5),
            "Add Holding sheet should show ticker field"
        )
    }

    func testHoldingSwipeActionsExist() throws {
        try navigateToFirstPortfolio()

        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 5) else {
            throw XCTSkip("No holdings found")
        }

        // Swipe left to reveal trailing actions
        firstCell.swipeLeft()

        // Edit action should exist on swipe
        let editButton = app.buttons["Edit"]
        XCTAssertTrue(
            editButton.waitForExistence(timeout: 3),
            "Edit swipe action should exist on holdings"
        )
    }

    // MARK: - Helpers

    private func navigateToPortfolios() {
        let tab = app.tabBars.buttons["Portfolios"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }

    private func navigateToFirstPortfolio() throws {
        navigateToPortfolios()
        let firstPortfolio = app.cells.firstMatch
        guard firstPortfolio.waitForExistence(timeout: 5) else {
            throw XCTSkip("No portfolios found — test requires at least one portfolio")
        }
        firstPortfolio.tap()
    }
}
