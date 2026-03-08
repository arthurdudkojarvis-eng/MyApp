import XCTest
import SwiftData
@testable import Divvy

@MainActor
final class HoldingPerformanceTests: XCTestCase {

    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.makeContainer(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeHolding(shares: Decimal, costBasis: Decimal, currentPrice: Decimal?) -> Holding {
        let context = ModelContext(container)
        // Unique ticker per call avoids @Attribute(.unique) constraint collisions
        // when multiple test cases share the same in-memory container.
        let stock = Stock(ticker: "T-\(UUID().uuidString.prefix(8))")
        if let price = currentPrice {
            stock.currentPrice = price
        }
        context.insert(stock)
        let holding = Holding(shares: shares, averageCostBasis: costBasis)
        holding.stock = stock
        context.insert(holding)
        return holding
    }

    private func makeHoldingNoStock(shares: Decimal, costBasis: Decimal) -> Holding {
        Holding(shares: shares, averageCostBasis: costBasis)
    }

    // MARK: - Holding.unrealizedGain

    func testUnrealizedGain_positiveGain() {
        // (200 - 150) × 10 = 500
        let holding = makeHolding(shares: 10, costBasis: 150, currentPrice: 200)
        XCTAssertEqual(holding.unrealizedGain, 500)
    }

    func testUnrealizedGain_negativeLoss() {
        // (140 - 150) × 10 = -100
        let holding = makeHolding(shares: 10, costBasis: 150, currentPrice: 140)
        XCTAssertEqual(holding.unrealizedGain, -100)
    }

    func testUnrealizedGain_returnsZeroWhenPriceIsZero() {
        // Stock.currentPrice defaults to 0; guard price > 0 returns 0.
        let holding = makeHolding(shares: 10, costBasis: 150, currentPrice: 0)
        XCTAssertEqual(holding.unrealizedGain, 0)
    }

    func testUnrealizedGain_returnsZeroWhenStockIsNil() {
        let holding = makeHoldingNoStock(shares: 10, costBasis: 150)
        XCTAssertEqual(holding.unrealizedGain, 0)
    }

    // MARK: - Holding.unrealizedGainPercent

    func testUnrealizedGainPercent_positiveGain() throws {
        // ((200 - 150) / 150) × 100 = 33.333...
        let holding = makeHolding(shares: 10, costBasis: 150, currentPrice: 200)
        let pct = try XCTUnwrap(holding.unrealizedGainPercent)
        XCTAssertEqual((pct as NSDecimalNumber).doubleValue, 33.333, accuracy: 0.001)
    }

    func testUnrealizedGainPercent_negativeLoss() throws {
        // ((100 - 150) / 150) × 100 = -33.333...
        let holding = makeHolding(shares: 10, costBasis: 150, currentPrice: 100)
        let pct = try XCTUnwrap(holding.unrealizedGainPercent)
        XCTAssertEqual((pct as NSDecimalNumber).doubleValue, -33.333, accuracy: 0.001)
    }

    func testUnrealizedGainPercent_nilWhenCostBasisIsZero() {
        // guard averageCostBasis > 0 — must not divide by zero
        let holding = makeHolding(shares: 10, costBasis: 0, currentPrice: 200)
        XCTAssertNil(holding.unrealizedGainPercent)
    }

    func testUnrealizedGainPercent_nilWhenPriceIsZero() {
        let holding = makeHolding(shares: 10, costBasis: 150, currentPrice: 0)
        XCTAssertNil(holding.unrealizedGainPercent)
    }

    func testUnrealizedGainPercent_nilWhenStockIsNil() {
        let holding = makeHoldingNoStock(shares: 10, costBasis: 150)
        XCTAssertNil(holding.unrealizedGainPercent)
    }

    // MARK: - Portfolio aggregate performance

    func testPortfolio_totalCostBasis_acrossMultipleHoldings() throws {
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "Test")
        context.insert(portfolio)

        // holding1: 100 shares @ $50 = $5,000
        let h1 = Holding(shares: 100, averageCostBasis: 50)
        h1.portfolio = portfolio
        context.insert(h1)

        // holding2: 50 shares @ $200 = $10,000
        let h2 = Holding(shares: 50, averageCostBasis: 200)
        h2.portfolio = portfolio
        context.insert(h2)

        try context.save()
        XCTAssertEqual(portfolio.totalCostBasis, 15_000)
    }

    func testPortfolio_totalCostBasis_emptyPortfolio() {
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "Empty")
        context.insert(portfolio)
        XCTAssertEqual(portfolio.totalCostBasis, 0)
    }

    func testPortfolio_totalUnrealizedGain_mixedGainsAndLosses() throws {
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "Test")
        context.insert(portfolio)

        // Gain: (200 - 150) × 10 = +500
        let stockA = Stock(ticker: "GAIN")
        stockA.currentPrice = 200
        context.insert(stockA)
        let h1 = Holding(shares: 10, averageCostBasis: 150)
        h1.portfolio = portfolio
        h1.stock = stockA
        context.insert(h1)

        // Loss: (100 - 150) × 10 = -500
        let stockB = Stock(ticker: "LOSS")
        stockB.currentPrice = 100
        context.insert(stockB)
        let h2 = Holding(shares: 10, averageCostBasis: 150)
        h2.portfolio = portfolio
        h2.stock = stockB
        context.insert(h2)

        try context.save()
        XCTAssertEqual(portfolio.totalUnrealizedGain, 0)
    }

    func testPortfolio_totalUnrealizedGainPercent_normalCase() throws {
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "Test")
        context.insert(portfolio)

        // cost basis: 100 × $100 = $10,000; current value: 100 × $110 = $11,000
        // gain: $1,000; percent: (1000 / 10000) × 100 = 10%
        let stock = Stock(ticker: "GROW")
        stock.currentPrice = 110
        context.insert(stock)
        let h = Holding(shares: 100, averageCostBasis: 100)
        h.portfolio = portfolio
        h.stock = stock
        context.insert(h)

        try context.save()
        let pct = try XCTUnwrap(portfolio.totalUnrealizedGainPercent)
        XCTAssertEqual((pct as NSDecimalNumber).doubleValue, 10.0, accuracy: 0.001)
    }

    func testPortfolio_totalUnrealizedGainPercent_nilWhenCostBasisIsZero() {
        // All holdings have zero cost basis — guard cost > 0 returns nil.
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "Test")
        context.insert(portfolio)
        // No holdings — totalCostBasis = 0
        XCTAssertNil(portfolio.totalUnrealizedGainPercent)
    }

    func testPortfolio_totalUnrealizedGainPercent_zeroWhenAllStocksPriceIsZero() throws {
        // totalCostBasis > 0 but all stocks have price 0 → gain = 0, not nil.
        // (price 0 means unrealizedGain = 0 per holding guard; cost basis still counts.)
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "Unpriced")
        context.insert(portfolio)

        let stock = Stock(ticker: "NOPRICE")
        stock.currentPrice = 0
        context.insert(stock)
        let h = Holding(shares: 10, averageCostBasis: 100)
        h.portfolio = portfolio
        h.stock = stock
        context.insert(h)

        try context.save()
        let pct = try XCTUnwrap(portfolio.totalUnrealizedGainPercent)
        XCTAssertEqual((pct as NSDecimalNumber).doubleValue, 0.0, accuracy: 0.001)
    }

    // MARK: - MockMassiveService.fetchTickerSearch

    func testMockFetchTickerSearchReturnsConfiguredResults() async throws {
        let mock = MockMassiveService()
        mock.searchResults = [
            MassiveTickerSearchResult(ticker: "AAPL", name: "Apple Inc.", market: "stocks", type: "CS", primaryExchange: "XNAS")
        ]
        let results = try await mock.fetchTickerSearch(query: "Apple")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.ticker, "AAPL")
        XCTAssertEqual(mock.fetchSearchCallCount, 1)
    }

    func testMockFetchTickerSearchThrowsWhenShouldThrow() async {
        let mock = MockMassiveService()
        mock.shouldThrow = true
        do {
            _ = try await mock.fetchTickerSearch(query: "AAPL")
            XCTFail("Expected throw")
        } catch MassiveError.httpError(statusCode: let code) {
            XCTAssertEqual(code, 403)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
