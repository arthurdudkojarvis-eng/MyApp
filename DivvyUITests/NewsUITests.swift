import XCTest

final class NewsUITests: XCTestCase {

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

    func testNewsNavigationTitle() {
        navigateToNews()
        let navBar = app.navigationBars["News & Events"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "News should show 'News & Events' navigation title"
        )
    }

    // MARK: - Content States

    func testNewsShowsContentOrEmptyState() {
        navigateToNews()
        // News can show: loading, articles, "No Holdings", or "No News Found"
        let noHoldings = app.staticTexts["No Holdings"]
        let noNews = app.staticTexts["No News Found"]
        let latest = app.staticTexts["Latest"]
        let allChip = app.buttons.matching(
            NSPredicate(format: "label == %@", "All")
        ).firstMatch

        // Wait for any state to resolve — check likely stable states first
        let foundSomething =
            allChip.waitForExistence(timeout: 5)
            || latest.waitForExistence(timeout: 3)
            || noHoldings.waitForExistence(timeout: 3)
            || noNews.waitForExistence(timeout: 3)
        XCTAssertTrue(
            foundSomething,
            "News view should show content, loading, or empty state"
        )
    }

    // MARK: - Ticker Filter Strip (data-dependent)

    func testNewsTickerFilterChipAllExists() throws {
        navigateToNews()
        // "All" chip only appears when user has holdings
        let allChip = app.buttons.matching(
            NSPredicate(format: "label == %@", "All")
        ).firstMatch
        guard allChip.waitForExistence(timeout: 8) else {
            throw XCTSkip("No holdings — ticker filter strip not shown")
        }
        XCTAssertTrue(allChip.isHittable, "'All' filter chip should be tappable")
    }

    func testNewsTickerChipIsTappable() throws {
        navigateToNews()
        let allChip = app.buttons.matching(
            NSPredicate(format: "label == %@", "All")
        ).firstMatch
        guard allChip.waitForExistence(timeout: 8) else {
            throw XCTSkip("No holdings — ticker filter strip not shown")
        }
        // Tap "All" chip and verify it stays responsive
        allChip.tap()
        XCTAssertTrue(allChip.exists, "'All' chip should remain after tapping")
    }

    // MARK: - Helpers

    private func navigateToNews() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let newsLink = app.staticTexts["News & Events"]
        XCTAssertTrue(newsLink.waitForExistence(timeout: 5))
        newsLink.tap()
    }
}
