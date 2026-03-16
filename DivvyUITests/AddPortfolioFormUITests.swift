import XCTest

final class AddPortfolioFormUITests: XCTestCase {

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

    func testAddPortfolioFormHasNameField() {
        openAddPortfolioSheet()
        let nameField = app.textFields["Portfolio name"]
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 5),
            "Add Portfolio form should have portfolio name text field"
        )
    }

    func testAddPortfolioFormHasCancelButton() {
        openAddPortfolioSheet()
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: 5),
            "Add Portfolio form should have Cancel button"
        )
    }

    func testAddPortfolioFormHasAddButton() {
        openAddPortfolioSheet()
        let addButton = app.buttons["Add portfolio"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 5),
            "Add Portfolio form should have Add button"
        )
    }

    func testAddButtonDisabledWhenNameEmpty() {
        openAddPortfolioSheet()
        let addButton = app.buttons["Add portfolio"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertFalse(
            addButton.isEnabled,
            "Add button should be disabled when name is empty"
        )
    }

    func testCancelDismissesSheet() {
        openAddPortfolioSheet()
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // The sheet's nav bar should disappear after cancel
        let sheetNavBar = app.navigationBars["New Portfolio"]
        XCTAssertFalse(
            sheetNavBar.waitForExistence(timeout: 3),
            "New Portfolio sheet should be dismissed after Cancel"
        )
    }

    func testAddPortfolioFormNavigationTitle() {
        openAddPortfolioSheet()
        let navBar = app.navigationBars["New Portfolio"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Add Portfolio sheet should show 'New Portfolio' title"
        )
    }

    // MARK: - Helpers

    private func openAddPortfolioSheet() {
        let portfoliosTab = app.tabBars.buttons["Portfolios"]
        XCTAssertTrue(portfoliosTab.waitForExistence(timeout: 10))
        portfoliosTab.tap()

        let addButton = app.buttons["Add portfolio"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
    }
}
