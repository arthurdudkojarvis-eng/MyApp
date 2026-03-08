import XCTest
import SwiftData
@testable import Divvy

final class AddPortfolioTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.makeContainer(inMemory: true)
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Save logic (mirrors AddPortfolioView.save())

    private func simulateSave(name: String) throws -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        context.insert(Portfolio(name: trimmed))
        return true
    }

    func testSaveInsertsTrimmedName() throws {
        _ = try simulateSave(name: "  Growth  ")
        let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertEqual(portfolios.count, 1)
        XCTAssertEqual(portfolios.first?.name, "Growth")
    }

    func testSaveRejectsWhitespaceOnlyName() throws {
        let inserted = try simulateSave(name: "   ")
        XCTAssertFalse(inserted)
        let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertEqual(portfolios.count, 0)
    }

    func testSaveRejectsEmptyString() throws {
        let inserted = try simulateSave(name: "")
        XCTAssertFalse(inserted)
        let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertEqual(portfolios.count, 0)
    }

    func testSaveInsertsExactlyOnePortfolio() throws {
        _ = try simulateSave(name: "My Portfolio")
        let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertEqual(portfolios.count, 1)
    }

    func testSavePortfolioHasDefaultCurrencyUSD() throws {
        _ = try simulateSave(name: "Income Fund")
        let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertEqual(portfolios.first?.currency, "USD")
    }

    // MARK: - isValid logic (mirrors AddPortfolioView.isValid)

    private func isValid(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func testIsValidTrueForNonBlankName() {
        XCTAssertTrue(isValid("My Portfolio"))
    }

    func testIsValidFalseForWhitespaceOnlyName() {
        XCTAssertFalse(isValid("   "))
    }

    func testIsValidFalseForEmptyString() {
        XCTAssertFalse(isValid(""))
    }

    // MARK: - Portfolio model integration

    func testDuplicateNamesAreAllowed() throws {
        _ = try simulateSave(name: "Growth")
        _ = try simulateSave(name: "Growth")
        let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertEqual(portfolios.count, 2)
    }

    func testEachPortfolioGetsUniqueId() throws {
        _ = try simulateSave(name: "Alpha")
        _ = try simulateSave(name: "Beta")
        let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertEqual(portfolios.count, 2)
        XCTAssertNotEqual(portfolios[0].id, portfolios[1].id)
    }

    func testCreatedAtIsSetOnInsert() throws {
        let before = Date.now
        _ = try simulateSave(name: "Timestamp Test")
        let portfolios = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertGreaterThanOrEqual(portfolios.first!.createdAt, before)
    }

    func testPortfoliosSortedAlphabeticallyByQuery() throws {
        _ = try simulateSave(name: "Zebra Fund")
        _ = try simulateSave(name: "Alpha Fund")
        let descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.name)])
        let portfolios = try context.fetch(descriptor)
        XCTAssertEqual(portfolios.first?.name, "Alpha Fund")
        XCTAssertEqual(portfolios.last?.name, "Zebra Fund")
    }
}
