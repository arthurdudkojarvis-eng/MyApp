import XCTest
import SwiftData
@testable import MyApp

@MainActor
final class DashboardMetricsTests: XCTestCase {
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

    /// Creates a Portfolio → Holding → Stock → DividendSchedule chain in the container.
    @discardableResult
    private func makeHolding(
        ticker: String,
        shares: Decimal,
        currentPrice: Decimal,
        amountPerShare: Decimal,
        frequency: DividendFrequency,
        portfolioName: String = "Test"
    ) throws -> (Portfolio, Holding) {
        let context = ModelContext(container)

        // Reuse existing portfolio if available.
        let portfolios = try context.fetch(
            FetchDescriptor<Portfolio>(predicate: #Predicate { $0.name == portfolioName })
        )
        let portfolio: Portfolio
        if let existing = portfolios.first {
            portfolio = existing
        } else {
            portfolio = Portfolio(name: portfolioName)
            context.insert(portfolio)
        }

        let stock = Stock(ticker: ticker, currentPrice: currentPrice)
        context.insert(stock)

        let schedule = DividendSchedule(
            frequency: frequency,
            amountPerShare: amountPerShare,
            exDate: .now, payDate: .now, declaredDate: .now, status: .declared
        )
        schedule.stock = stock
        context.insert(schedule)

        let holding = Holding(shares: shares, averageCostBasis: 0)
        holding.stock = stock
        holding.portfolio = portfolio
        context.insert(holding)

        try context.save()
        return (portfolio, holding)
    }

    // MARK: - Empty state

    func testMetricsWithNoPortfolios() {
        let m = DashboardMetrics(portfolios: [])
        XCTAssertEqual(m.projectedAnnualIncome, 0)
        XCTAssertEqual(m.monthlyEquivalent, 0)
        XCTAssertEqual(m.totalMarketValue, 0)
        XCTAssertNil(m.overallYield)
    }

    func testMetricsWithEmptyPortfolio() throws {
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "Empty")
        context.insert(portfolio)
        try context.save()

        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.projectedAnnualIncome, 0)
        XCTAssertNil(m.overallYield)
    }

    // MARK: - Single holding

    func testProjectedAnnualIncome_quarterlyDividend() throws {
        // $0.25/share × 4 payments × 100 shares = $100.00/yr
        let (portfolio, _) = try makeHolding(
            ticker: "AAPL", shares: 100,
            currentPrice: 180, amountPerShare: Decimal(string: "0.25")!, frequency: .quarterly
        )
        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.projectedAnnualIncome, Decimal(string: "100.00")!)
    }

    func testProjectedAnnualIncome_monthlyDividend() throws {
        // $0.50/share × 12 payments × 50 shares = $300.00/yr
        let (portfolio, _) = try makeHolding(
            ticker: "REALTY", shares: 50,
            currentPrice: 55, amountPerShare: Decimal(string: "0.50")!, frequency: .monthly
        )
        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.projectedAnnualIncome, Decimal(string: "300.00")!)
    }

    func testMonthlyEquivalent() throws {
        // Annual = $120 → monthly = $10
        let (portfolio, _) = try makeHolding(
            ticker: "T", shares: 100,
            currentPrice: 20, amountPerShare: Decimal(string: "0.30")!, frequency: .quarterly
        )
        // 0.30 × 4 × 100 = 120
        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.projectedAnnualIncome, 120)
        XCTAssertEqual(m.monthlyEquivalent, 10)
    }

    func testTotalMarketValue() throws {
        // 100 shares × $185 = $18,500
        let (portfolio, _) = try makeHolding(
            ticker: "AAPL", shares: 100,
            currentPrice: 185, amountPerShare: Decimal(string: "0.25")!, frequency: .quarterly
        )
        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.totalMarketValue, 18500)
    }

    func testOverallYield() throws {
        // Annual income $100, market value $2500 → yield = 0.04 (4%)
        let (portfolio, _) = try makeHolding(
            ticker: "XYZ", shares: 100,
            currentPrice: 25, amountPerShare: Decimal(string: "0.25")!, frequency: .quarterly
        )
        // income = 0.25 × 4 × 100 = 100; value = 100 × 25 = 2500; yield = 100/2500 = 0.04
        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.overallYield, Decimal(string: "0.04")!)
    }

    // MARK: - Edge cases

    func testYieldIsNilWhenNoPriceData() throws {
        // Stock with currentPrice = 0 → totalMarketValue = 0 → yield = nil
        let (portfolio, _) = try makeHolding(
            ticker: "NOPRICE", shares: 100,
            currentPrice: 0, amountPerShare: Decimal(string: "0.25")!, frequency: .quarterly
        )
        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.totalMarketValue, 0)
        XCTAssertNil(m.overallYield)
    }

    func testYieldIsZeroWhenNoIncomeButHasMarketValue() throws {
        // Stock has price but no dividend schedules → income = 0, value > 0, yield = 0 (not nil)
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "GrowthOnly")
        context.insert(portfolio)
        let stock = Stock(ticker: "GRW2", currentPrice: 100)
        context.insert(stock)
        // No DividendSchedule inserted — annualDividendPerShare = 0
        let holding = Holding(shares: 10, averageCostBasis: 90)
        holding.stock = stock
        holding.portfolio = portfolio
        context.insert(holding)
        try context.save()

        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.projectedAnnualIncome, 0)
        XCTAssertEqual(m.totalMarketValue, 1000)   // 10 × 100
        // income / value = 0 / 1000 = 0 (not nil, since denominator > 0)
        XCTAssertEqual(m.overallYield, 0)
    }

    func testHoldingWithNoDividendScheduleContributesZeroIncome() throws {
        let context = ModelContext(container)
        let portfolio = Portfolio(name: "NoDividend")
        context.insert(portfolio)
        let stock = Stock(ticker: "GRW", currentPrice: 100)
        context.insert(stock)
        let holding = Holding(shares: 50, averageCostBasis: 90)
        holding.stock = stock
        holding.portfolio = portfolio
        context.insert(holding)
        try context.save()

        let m = DashboardMetrics(portfolios: [portfolio])
        XCTAssertEqual(m.projectedAnnualIncome, 0)
        XCTAssertEqual(m.totalMarketValue, 5000) // 50 × 100
        XCTAssertNil(m.overallYield)             // income = 0
    }

    // MARK: - Multiple portfolios

    func testSumsAcrossMultiplePortfolios() throws {
        let context = ModelContext(container)
        // Portfolio A: AAPL — $100/yr income, $18,500 value
        let (portfolioA, _) = try makeHolding(
            ticker: "AAPL2", shares: 100,
            currentPrice: 185, amountPerShare: Decimal(string: "0.25")!, frequency: .quarterly,
            portfolioName: "A"
        )
        // Portfolio B: VYM — $40/yr income, $6,000 value
        let (portfolioB, _) = try makeHolding(
            ticker: "VYM2", shares: 100,
            currentPrice: 60, amountPerShare: Decimal(string: "0.10")!, frequency: .quarterly,
            portfolioName: "B"
        )
        _ = context  // suppress unused warning

        let m = DashboardMetrics(portfolios: [portfolioA, portfolioB])
        XCTAssertEqual(m.projectedAnnualIncome, 140)   // 100 + 40
        XCTAssertEqual(m.totalMarketValue, 24500)      // 18500 + 6000
    }
}
