import XCTest
import SwiftData
@testable import Divvy

// MARK: - scrollTargetKey tests (pure date math, no SwiftData needed)

final class ScrollTargetKeyTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(year: Int, month: Int, day: Int = 1) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testFindsCurrentMonthWhenPresent() {
        let keys = [202501, 202502, 202503]
        let target = scrollTargetKey(from: keys, currentDate: date(year: 2025, month: 2), calendar: cal)
        XCTAssertEqual(target, 202502)
    }

    func testFallsToNextFutureMonthWhenCurrentNotPresent() {
        // No key for Feb 2025 — should land on Mar 2025
        let keys = [202501, 202503, 202504]
        let target = scrollTargetKey(from: keys, currentDate: date(year: 2025, month: 2), calendar: cal)
        XCTAssertEqual(target, 202503)
    }

    func testReturnsNilWhenAllEventsAreInPast() {
        let keys = [202501, 202502]
        let target = scrollTargetKey(from: keys, currentDate: date(year: 2025, month: 12), calendar: cal)
        XCTAssertNil(target)
    }

    func testReturnsNilForEmptyKeyList() {
        XCTAssertNil(scrollTargetKey(from: [], currentDate: .now))
    }

    func testMatchesCurrentMonthOnLastDayOfMonth() {
        // Jan 31 still belongs to January
        let keys = [202501, 202502]
        let target = scrollTargetKey(from: keys, currentDate: date(year: 2025, month: 1, day: 31), calendar: cal)
        XCTAssertEqual(target, 202501)
    }

    func testSingleKeyInFuture() {
        let keys = [202601]
        let target = scrollTargetKey(from: keys, currentDate: date(year: 2025, month: 6), calendar: cal)
        XCTAssertEqual(target, 202601)
    }

    func testSingleKeyInPast() {
        let keys = [202401]
        let target = scrollTargetKey(from: keys, currentDate: date(year: 2025, month: 6), calendar: cal)
        XCTAssertNil(target)
    }
}

// MARK: - calendarGroups tests (requires SwiftData models)

@MainActor
final class CalendarGroupsTests: XCTestCase {
    private var container: ModelContainer!
    private let cal = Calendar(identifier: .gregorian)

    private func date(year: Int, month: Int, day: Int = 15) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.makeContainer(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    private func makeSchedule(payDate: Date, amount: Decimal = 1) throws -> DividendSchedule {
        let ctx = ModelContext(container)
        let s = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: amount,
            exDate: payDate, payDate: payDate, declaredDate: payDate
        )
        ctx.insert(s)
        try ctx.save()
        return s
    }

    func testEmptySchedulesProducesNoGroups() {
        let groups = calendarGroups(from: [], calendar: cal)
        XCTAssertTrue(groups.isEmpty)
    }

    func testSingleScheduleProducesOneGroup() throws {
        let s = try makeSchedule(payDate: date(year: 2025, month: 3))
        let groups = calendarGroups(from: [s], calendar: cal)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].key, 202503)
        XCTAssertEqual(groups[0].schedules.count, 1)
    }

    func testSchedulesInSameMonthGroupTogether() throws {
        let d1 = try makeSchedule(payDate: date(year: 2025, month: 4, day: 5))
        let d2 = try makeSchedule(payDate: date(year: 2025, month: 4, day: 20))
        let groups = calendarGroups(from: [d1, d2], calendar: cal)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].schedules.count, 2)
    }

    func testSchedulesInDifferentMonthsProduceSeparateGroups() throws {
        let jan = try makeSchedule(payDate: date(year: 2025, month: 1))
        let feb = try makeSchedule(payDate: date(year: 2025, month: 2))
        let groups = calendarGroups(from: [jan, feb], calendar: cal)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].key, 202501)
        XCTAssertEqual(groups[1].key, 202502)
    }

    func testGroupsAreSortedChronologically() throws {
        let mar = try makeSchedule(payDate: date(year: 2025, month: 3))
        let jan = try makeSchedule(payDate: date(year: 2025, month: 1))
        let groups = calendarGroups(from: [mar, jan], calendar: cal)
        XCTAssertEqual(groups.map(\.key), [202501, 202503])
    }

    func testSchedulesWithinGroupSortedByPayDate() throws {
        let late  = try makeSchedule(payDate: date(year: 2025, month: 5, day: 25))
        let early = try makeSchedule(payDate: date(year: 2025, month: 5, day: 5))
        let groups = calendarGroups(from: [late, early], calendar: cal)
        XCTAssertEqual(groups[0].schedules[0].payDate, early.payDate)
        XCTAssertEqual(groups[0].schedules[1].payDate, late.payDate)
    }

    func testKeyComputationAcrossYears() throws {
        let dec24 = try makeSchedule(payDate: date(year: 2024, month: 12))
        let jan25 = try makeSchedule(payDate: date(year: 2025, month: 1))
        let groups = calendarGroups(from: [dec24, jan25], calendar: cal)
        XCTAssertEqual(groups[0].key, 202412)
        XCTAssertEqual(groups[1].key, 202501)
    }
}
