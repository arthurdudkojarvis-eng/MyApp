import XCTest

final class AddHoldingFormUITests: XCTestCase {

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

    // MARK: - Form Elements

    func testAddHoldingFormHasTickerField() throws {
        try openAddHoldingSheet()
        let tickerField = app.textFields["Ticker symbol"]
        XCTAssertTrue(
            tickerField.waitForExistence(timeout: 5),
            "Add Holding form should have ticker symbol text field"
        )
    }

    func testAddHoldingFormHasSharesField() throws {
        try openAddHoldingSheet()
        let sharesField = app.textFields["Number of shares"]
        XCTAssertTrue(
            sharesField.waitForExistence(timeout: 5),
            "Add Holding form should have shares text field"
        )
    }

    func testAddHoldingFormHasCurrentPriceRow() throws {
        try openAddHoldingSheet()
        let priceRow = app.staticTexts["Current Price"]
        XCTAssertTrue(
            priceRow.waitForExistence(timeout: 5),
            "Add Holding form should show Current Price label"
        )
    }

    func testAddHoldingFormHasPurchaseDatePicker() throws {
        try openAddHoldingSheet()
        let datePicker = app.staticTexts["Purchase Date"]
        XCTAssertTrue(
            datePicker.waitForExistence(timeout: 5),
            "Add Holding form should show Purchase Date picker"
        )
    }

    func testAddHoldingFormHasCancelButton() throws {
        try openAddHoldingSheet()
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: 5),
            "Add Holding form should have Cancel button"
        )
    }

    func testAddHoldingFormHasAddButton() throws {
        try openAddHoldingSheet()
        let addButton = app.buttons["Add"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 5),
            "Add Holding form should have Add button"
        )
    }

    func testAddHoldingCancelDismissesSheet() throws {
        try openAddHoldingSheet()
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // The sheet's nav bar should disappear after cancel
        let sheetNavBar = app.navigationBars["New Holding"]
        XCTAssertFalse(
            sheetNavBar.waitForExistence(timeout: 3),
            "Add Holding sheet should be dismissed after Cancel"
        )
    }

    // MARK: - Helpers

    private func openAddHoldingSheet() throws {
        let portfoliosTab = app.tabBars.buttons["Portfolios"]
        XCTAssertTrue(portfoliosTab.waitForExistence(timeout: 10))
        portfoliosTab.tap()

        let firstPortfolio = app.cells.firstMatch
        guard firstPortfolio.waitForExistence(timeout: 5) else {
            throw XCTSkip("No portfolios found — test requires at least one portfolio")
        }
        firstPortfolio.tap()

        let addHoldingButton = app.buttons["Add holding"]
        XCTAssertTrue(addHoldingButton.waitForExistence(timeout: 5))
        addHoldingButton.tap()
    }
}
