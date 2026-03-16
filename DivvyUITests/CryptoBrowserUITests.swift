import XCTest

final class CryptoBrowserUITests: XCTestCase {

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

    // MARK: - Crypto Browser Tab

    func testCryptoTabExists() {
        let tab = app.tabBars.buttons["Crypto"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Crypto tab must exist")
    }

    func testCryptoTabShowsBrowser() {
        navigateToCrypto()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Search field should exist on Crypto tab"
        )
    }

    func testCryptoEmptyStateExists() {
        navigateToCrypto()
        // Without a search, crypto shows an empty/prompt state
        let content = app.scrollViews.firstMatch
        XCTAssertTrue(
            content.waitForExistence(timeout: 5),
            "Crypto browser content should load"
        )
    }

    // MARK: - Helpers

    private func navigateToCrypto() {
        let tab = app.tabBars.buttons["Crypto"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
}
