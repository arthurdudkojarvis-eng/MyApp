import XCTest
import SwiftData
@testable import Divvy

final class AddHoldingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var portfolio: Portfolio!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.makeContainer(inMemory: true)
        context = ModelContext(container)
        portfolio = Portfolio(name: "Test Portfolio")
        context.insert(portfolio)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        portfolio = nil
        try await super.tearDown()
    }

    // MARK: - Save logic (mirrors AddHoldingView.save())

    /// `currentPrice` simulates the auto-fetched market price used as cost basis.
    private func simulateSave(
        ticker: String,
        shares: Decimal,
        currentPrice: Decimal = 150,
        purchaseDate: Date = .now
    ) throws {
        let upper = ticker.trimmingCharacters(in: .whitespaces).uppercased()
        let descriptor = FetchDescriptor<Stock>(predicate: #Predicate<Stock> { $0.ticker == upper })
        let stock: Stock
        if let existing = try context.fetch(descriptor).first {
            stock = existing
        } else {
            stock = Stock(ticker: upper)
            context.insert(stock)
        }

        let holding = Holding(shares: shares, averageCostBasis: currentPrice, purchaseDate: purchaseDate)
        holding.portfolio = portfolio
        holding.stock = stock
        context.insert(holding)
    }

    // MARK: - Holding insertion

    func testSaveInsertsOneHolding() throws {
        try simulateSave(ticker: "AAPL", shares: 10)
        let holdings = try context.fetch(FetchDescriptor<Holding>())
        XCTAssertEqual(holdings.count, 1)
    }

    func testSaveLinksHoldingToPortfolio() throws {
        try simulateSave(ticker: "AAPL", shares: 10)
        let holdings = try context.fetch(FetchDescriptor<Holding>())
        XCTAssertEqual(holdings.first?.portfolio?.name, "Test Portfolio")
    }

    func testSaveLinksHoldingToStock() throws {
        try simulateSave(ticker: "AAPL", shares: 10)
        let holdings = try context.fetch(FetchDescriptor<Holding>())
        XCTAssertEqual(holdings.first?.stock?.ticker, "AAPL")
    }

    func testSaveStoresSharesAndCostBasis() throws {
        try simulateSave(ticker: "VTI", shares: Decimal(string: "42.5")!, currentPrice: Decimal(string: "220.75")!)
        let holdings = try context.fetch(FetchDescriptor<Holding>())
        XCTAssertEqual(holdings.first?.shares, Decimal(string: "42.5")!)
        XCTAssertEqual(holdings.first?.averageCostBasis, Decimal(string: "220.75")!)
    }

    func testSaveStoresPurchaseDate() throws {
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        try simulateSave(ticker: "O", shares: 50, purchaseDate: date)
        let holdings = try context.fetch(FetchDescriptor<Holding>())
        XCTAssertEqual(
            Calendar.current.startOfDay(for: holdings.first!.purchaseDate),
            Calendar.current.startOfDay(for: date)
        )
    }

    // MARK: - Ticker uppercasing

    func testTickerIsUppercasedOnSave() throws {
        try simulateSave(ticker: "aapl", shares: 1)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.ticker, "AAPL")
    }

    func testTickerIsTrimmedOnSave() throws {
        try simulateSave(ticker: "  MSFT  ", shares: 1)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.ticker, "MSFT")
    }

    // MARK: - Stock reuse

    func testSavingTwoHoldingsSameTickerSharesOneStock() throws {
        let p2 = Portfolio(name: "Second Portfolio")
        context.insert(p2)

        try simulateSave(ticker: "VYM", shares: 10)

        // Second save for same ticker but different portfolio
        let descriptor = FetchDescriptor<Stock>(predicate: #Predicate<Stock> { $0.ticker == "VYM" })
        let stock = try context.fetch(descriptor).first!
        let holding2 = Holding(shares: 5, averageCostBasis: 105)
        holding2.portfolio = p2
        holding2.stock = stock
        context.insert(holding2)

        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.count, 1, "Both holdings should share the same Stock record")

        let holdings = try context.fetch(FetchDescriptor<Holding>())
        XCTAssertEqual(holdings.count, 2)
    }

    func testSavingDifferentTickersCreatesDistinctStocks() throws {
        try simulateSave(ticker: "AAPL", shares: 5)
        try simulateSave(ticker: "MSFT", shares: 3)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.count, 2)
    }

    // MARK: - isValid logic (mirrors AddHoldingView.isValid)

    private func isValid(ticker: String, sharesText: String, currentPrice: Decimal?) -> Bool {
        let t = ticker.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        guard let s = Decimal(string: sharesText), s > 0 else { return false }
        guard let p = currentPrice, p > 0 else { return false }
        return true
    }

    func testIsValidWithAllFieldsPopulated() {
        XCTAssertTrue(isValid(ticker: "AAPL", sharesText: "10", currentPrice: 150))
    }

    func testIsValidFalseWhenTickerEmpty() {
        XCTAssertFalse(isValid(ticker: "", sharesText: "10", currentPrice: 150))
    }

    func testIsValidFalseWhenSharesZero() {
        XCTAssertFalse(isValid(ticker: "AAPL", sharesText: "0", currentPrice: 150))
    }

    func testIsValidFalseWhenSharesNegative() {
        XCTAssertFalse(isValid(ticker: "AAPL", sharesText: "-5", currentPrice: 150))
    }

    func testIsValidFalseWhenPriceNil() {
        XCTAssertFalse(isValid(ticker: "AAPL", sharesText: "10", currentPrice: nil))
    }

    func testIsValidFalseWhenPriceZero() {
        XCTAssertFalse(isValid(ticker: "AAPL", sharesText: "10", currentPrice: 0))
    }

    func testIsValidFalseWhenSharesNotNumeric() {
        XCTAssertFalse(isValid(ticker: "AAPL", sharesText: "abc", currentPrice: 150))
    }

    func testIsValidFalseWhenTickerIsWhitespaceOnly() {
        XCTAssertFalse(isValid(ticker: "   ", sharesText: "10", currentPrice: 150))
    }

    // MARK: - Delete by sorted index

    func testDeleteBySnapshotIndexRemovesCorrectHolding() throws {
        // Insert in reverse alpha order to ensure sort matters.
        try simulateSave(ticker: "VZ",   shares: 10)
        try simulateSave(ticker: "AAPL", shares: 5)
        try simulateSave(ticker: "MSFT", shares: 3)

        let all = try context.fetch(FetchDescriptor<Holding>())
        let snapshot = all.sorted { ($0.stock?.ticker ?? "") < ($1.stock?.ticker ?? "") }
        // snapshot[0] = AAPL, [1] = MSFT, [2] = VZ

        context.delete(snapshot[0]) // delete AAPL

        let remaining = try context.fetch(FetchDescriptor<Holding>())
        XCTAssertEqual(remaining.count, 2)
        XCTAssertFalse(remaining.contains { $0.stock?.ticker == "AAPL" })
        XCTAssertTrue(remaining.contains { $0.stock?.ticker == "MSFT" })
        XCTAssertTrue(remaining.contains { $0.stock?.ticker == "VZ" })
    }
}
