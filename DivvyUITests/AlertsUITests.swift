import XCTest

final class AlertsUITests: XCTestCase {

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

    func testAlertsNavigationTitle() {
        navigateToAlerts()
        let navBar = app.navigationBars["Alerts"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Alerts should show navigation title"
        )
    }

    // MARK: - Content States

    func testAlertsShowsContentOrEmptyState() {
        navigateToAlerts()
        let emptyTitle = app.staticTexts["No Upcoming Ex-Dates"]
        let summaryTitle = app.staticTexts["Upcoming Dividends"]
        XCTAssertTrue(
            emptyTitle.waitForExistence(timeout: 5)
            || summaryTitle.waitForExistence(timeout: 5),
            "Alerts should show either empty state or summary card"
        )
    }

    // MARK: - Summary Card (data-dependent)

    func testAlertsSummaryCardHasStats() throws {
        navigateToAlerts()
        let summaryTitle = app.staticTexts["Upcoming Dividends"]
        guard summaryTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("No upcoming ex-dates — alerts shows empty state")
        }
        // Summary card shows "estimated income" and quick stats
        let estimated = app.staticTexts["estimated income"]
        XCTAssertTrue(
            estimated.waitForExistence(timeout: 3),
            "Summary card should show 'estimated income' label"
        )
    }

    func testAlertsQuickStatsExist() throws {
        navigateToAlerts()
        let summaryTitle = app.staticTexts["Upcoming Dividends"]
        guard summaryTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("No upcoming ex-dates — alerts shows empty state")
        }
        let totalStat = app.staticTexts["Total"]
        let perEventStat = app.staticTexts["Per Event"]
        let nextStat = app.staticTexts["Next"]
        XCTAssertTrue(
            totalStat.waitForExistence(timeout: 3),
            "Quick stats should include 'Total'"
        )
        XCTAssertTrue(
            perEventStat.waitForExistence(timeout: 3),
            "Quick stats should include 'Per Event'"
        )
        XCTAssertTrue(
            nextStat.waitForExistence(timeout: 3),
            "Quick stats should include 'Next'"
        )
    }

    // MARK: - Timeline Card (data-dependent)

    func testAlertsTimelineCardExists() throws {
        navigateToAlerts()
        let summaryTitle = app.staticTexts["Upcoming Dividends"]
        guard summaryTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("No upcoming ex-dates — alerts shows empty state")
        }
        let timelineTitle = app.staticTexts["Ex-Date Timeline"]
        XCTAssertTrue(
            timelineTitle.waitForExistence(timeout: 3),
            "Timeline card should show 'Ex-Date Timeline' header"
        )
    }

    // MARK: - Empty State Details

    func testAlertsEmptyStateHasDescription() throws {
        navigateToAlerts()
        let emptyTitle = app.staticTexts["No Upcoming Ex-Dates"]
        guard emptyTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Alerts has data — skipping empty state test")
        }
        // Verify the empty state also shows descriptive text
        let description = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "dividend schedules")
        ).firstMatch
        XCTAssertTrue(
            description.waitForExistence(timeout: 3),
            "Empty state should include description about dividend schedules"
        )
    }

    // MARK: - Helpers

    private func navigateToAlerts() {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 10))
        dashboardTab.tap()

        let featuresButton = app.buttons["Features menu"]
        XCTAssertTrue(featuresButton.waitForExistence(timeout: 5))
        featuresButton.tap()

        let alertsLink = app.staticTexts["Alerts"]
        XCTAssertTrue(alertsLink.waitForExistence(timeout: 5))
        alertsLink.tap()
    }
}
