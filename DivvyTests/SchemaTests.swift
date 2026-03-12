import XCTest
import SwiftData
@testable import Divvy

@MainActor
final class SchemaTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        // Fresh isolated in-memory container per test — no shared state.
        container = try ModelContainer.makeContainer(inMemory: true)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - Portfolio

    func test_portfolio_canBeCreatedAndFetched() throws {
        let portfolio = Portfolio(name: "My Brokerage")
        context.insert(portfolio)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Portfolio>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "My Brokerage")
        XCTAssertEqual(fetched.first?.currency, "USD")
    }

    func test_portfolio_defaultsToEmptyHoldings() throws {
        let portfolio = Portfolio(name: "Test")
        context.insert(portfolio)
        try context.save()

        XCTAssertTrue(portfolio.holdings.isEmpty)
        XCTAssertEqual(portfolio.projectedAnnualIncome, 0)
        XCTAssertEqual(portfolio.projectedMonthlyIncome, 0)
    }

    // MARK: - Stock

    func test_stock_tickerIsUppercased() throws {
        let stock = Stock(ticker: "msft")
        context.insert(stock)
        try context.save()

        XCTAssertEqual(stock.ticker, "MSFT")
    }

    func test_stock_annualDividendPerShare_quarterly() throws {
        let stock = Stock(ticker: "JNJ")
        let schedule = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "1.19")!,
            exDate: .now,
            payDate: Calendar.current.date(byAdding: .day, value: 30, to: .now)!,
            status: .declared
        )
        schedule.stock = stock
        stock.dividendSchedules = [schedule]
        context.insert(stock)
        context.insert(schedule)
        try context.save()

        XCTAssertEqual(stock.annualDividendPerShare, Decimal(string: "4.76")!)
    }

    func test_stock_annualDividendPerShare_prefersDeclaредOverEstimated() throws {
        let stock = Stock(ticker: "T")
        let declared = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.28")!,
            exDate: Date(timeIntervalSinceNow: -86400),   // yesterday (older)
            payDate: .now,
            status: .declared
        )
        let estimated = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.30")!,
            exDate: Date(timeIntervalSinceNow: 86400 * 90), // future (newer)
            payDate: .now,
            status: .estimated
        )
        declared.stock = stock
        estimated.stock = stock
        stock.dividendSchedules = [declared, estimated]
        context.insert(stock)
        context.insert(declared)
        context.insert(estimated)
        try context.save()

        // Should prefer declared (0.28 * 4 = 1.12), not estimated (0.30 * 4 = 1.20)
        XCTAssertEqual(stock.annualDividendPerShare, Decimal(string: "1.12")!)
    }

    func test_stock_annualDividendPerShare_fallsBackToMostRecentPaid() throws {
        let stock = Stock(ticker: "KO")
        let paid = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.46")!,
            exDate: Date(timeIntervalSinceNow: -86400 * 30),
            payDate: Date(timeIntervalSinceNow: -86400 * 15),
            status: .paid
        )
        paid.stock = stock
        stock.dividendSchedules = [paid]
        context.insert(stock)
        context.insert(paid)
        try context.save()

        // No declared or estimated — falls back to paid
        XCTAssertEqual(stock.annualDividendPerShare, Decimal(string: "1.84")!)
    }

    func test_stock_annualDividendPerShare_returnsZeroWithNoSchedules() throws {
        let stock = Stock(ticker: "NEW")
        context.insert(stock)
        try context.save()

        XCTAssertEqual(stock.annualDividendPerShare, 0)
    }

    func test_stock_isStale_falseForRecentlyUpdated() throws {
        // Stock with a non-zero price gets lastUpdated = .now (not stale).
        let stock = Stock(ticker: "AAPL", currentPrice: 150)
        context.insert(stock)
        try context.save()

        XCTAssertFalse(stock.isStale)
    }

    func test_stock_isStale_trueForZeroPriceStock() throws {
        // Stock with zero price gets lastUpdated = .distantPast (immediately stale).
        let stock = Stock(ticker: "NEW0")
        context.insert(stock)
        try context.save()

        XCTAssertTrue(stock.isStale)
    }

    func test_stock_nextExDate_returnsUpcomingDate() throws {
        let stock = Stock(ticker: "O")
        let past = DividendSchedule(
            frequency: .monthly,
            amountPerShare: Decimal(string: "0.257")!,
            exDate: Date(timeIntervalSinceNow: -86400 * 5),
            payDate: Date(timeIntervalSinceNow: -86400 * 3)
        )
        let future = DividendSchedule(
            frequency: .monthly,
            amountPerShare: Decimal(string: "0.257")!,
            exDate: Date(timeIntervalSinceNow: 86400 * 25),
            payDate: Date(timeIntervalSinceNow: 86400 * 27)
        )
        past.stock = stock
        future.stock = stock
        stock.dividendSchedules = [past, future]
        context.insert(stock)
        context.insert(past)
        context.insert(future)
        try context.save()

        XCTAssertNotNil(stock.nextExDate)
        XCTAssertGreaterThan(stock.nextExDate!, .now)
    }

    // MARK: - Holding

    func test_holding_linkedToPortfolioAndStock() throws {
        let portfolio = Portfolio(name: "Roth IRA")
        let stock = Stock(ticker: "AAPL", companyName: "Apple Inc.", currentPrice: 189)
        let holding = Holding(shares: 10, averageCostBasis: 150)
        holding.portfolio = portfolio
        holding.stock = stock

        context.insert(portfolio)
        context.insert(stock)
        context.insert(holding)
        try context.save()

        XCTAssertEqual(portfolio.holdings.count, 1)
        XCTAssertEqual(holding.stock?.ticker, "AAPL")
    }

    func test_holding_currentValue() throws {
        let stock = Stock(ticker: "AAPL", currentPrice: 189)
        let holding = Holding(shares: 10, averageCostBasis: 150)
        holding.stock = stock
        context.insert(stock)
        context.insert(holding)
        try context.save()

        XCTAssertEqual(holding.currentValue, 1890)
    }

    func test_holding_yieldOnCost_monthly() throws {
        let stock = Stock(ticker: "O")
        let schedule = DividendSchedule(
            frequency: .monthly,
            amountPerShare: Decimal(string: "0.2630")!,
            exDate: .now,
            payDate: .now
        )
        schedule.stock = stock
        stock.dividendSchedules = [schedule]

        let holding = Holding(shares: 100, averageCostBasis: 50)
        holding.stock = stock

        context.insert(stock)
        context.insert(schedule)
        context.insert(holding)
        try context.save()

        // Annual = 0.2630 * 12 = 3.1560; YoC = (3.1560 / 50) * 100 = 6.312
        XCTAssertEqual(holding.yieldOnCost, Decimal(string: "6.312")!)
    }

    func test_holding_currentYield() throws {
        let stock = Stock(ticker: "VZ", currentPrice: 40)
        let schedule = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.665")!,
            exDate: .now,
            payDate: .now
        )
        schedule.stock = stock
        stock.dividendSchedules = [schedule]

        let holding = Holding(shares: 50, averageCostBasis: 35)
        holding.stock = stock

        context.insert(stock)
        context.insert(schedule)
        context.insert(holding)
        try context.save()

        // currentYield = (0.665 * 4 / 40) * 100 = 6.65
        XCTAssertEqual(holding.currentYield, Decimal(string: "6.65")!)
    }

    func test_holding_projectedMonthlyIncome() throws {
        let stock = Stock(ticker: "PEP")
        let schedule = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "1.355")!,
            exDate: .now,
            payDate: .now
        )
        schedule.stock = stock
        stock.dividendSchedules = [schedule]

        let holding = Holding(shares: 12, averageCostBasis: 170)
        holding.stock = stock

        context.insert(stock)
        context.insert(schedule)
        context.insert(holding)
        try context.save()

        // Annual = 1.355 * 4 * 12 = 65.04; Monthly = 65.04 / 12 = 5.42
        XCTAssertEqual(holding.projectedMonthlyIncome, Decimal(string: "5.42")!)
    }

    // MARK: - DividendSchedule

    func test_dividendSchedule_annualizedAmount() throws {
        let schedule = DividendSchedule(
            frequency: .semiAnnual,
            amountPerShare: Decimal(string: "0.50")!,
            exDate: .now,
            payDate: .now
        )
        context.insert(schedule)
        try context.save()

        XCTAssertEqual(schedule.annualizedAmountPerShare, Decimal(string: "1.00")!)
    }

    func test_dividendSchedule_isUpcoming_todayIsUpcoming() throws {
        let today = Calendar.current.startOfDay(for: .now)
        let schedule = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.50")!,
            exDate: today,
            payDate: Calendar.current.date(byAdding: .day, value: 30, to: today)!
        )
        context.insert(schedule)
        try context.save()

        XCTAssertTrue(schedule.isUpcoming)
    }

    func test_dividendSchedule_isUpcoming_pastDateIsNotUpcoming() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let schedule = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.50")!,
            exDate: yesterday,
            payDate: .now
        )
        context.insert(schedule)
        try context.save()

        XCTAssertFalse(schedule.isUpcoming)
    }

    // MARK: - DividendPayment

    func test_dividendPayment_linkedToHolding() throws {
        let holding = Holding(shares: 200, averageCostBasis: 30)
        let payment = DividendPayment(
            sharesAtTime: 200,
            totalAmount: Decimal(string: "52.60")!
        )
        payment.holding = holding

        context.insert(holding)
        context.insert(payment)
        try context.save()

        XCTAssertEqual(holding.dividendPayments.count, 1)
        XCTAssertEqual(holding.totalDividendsReceived, Decimal(string: "52.60")!)
    }

    func test_dividendPayment_netAmountWithWithholding() throws {
        let payment = DividendPayment(
            sharesAtTime: 100,
            totalAmount: Decimal(string: "50.00")!,
            withholdingTax: Decimal(string: "7.50")!
        )
        context.insert(payment)
        try context.save()

        XCTAssertEqual(payment.netAmount, Decimal(string: "42.50")!)
    }

    func test_dividendPayment_linkedToSchedule() throws {
        let stock = Stock(ticker: "MO")
        let schedule = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.94")!,
            exDate: .now,
            payDate: .now
        )
        schedule.stock = stock
        let holding = Holding(shares: 50, averageCostBasis: 45)
        holding.stock = stock
        let payment = DividendPayment(sharesAtTime: 50, totalAmount: Decimal(string: "47.00")!)
        payment.holding = holding
        payment.dividendSchedule = schedule

        context.insert(stock)
        context.insert(schedule)
        context.insert(holding)
        context.insert(payment)
        try context.save()

        XCTAssertEqual(schedule.payments.count, 1)
    }

    // MARK: - Portfolio Projections

    func test_portfolio_projectedAnnualIncome_acrossMultipleHoldings() throws {
        let portfolio = Portfolio(name: "Income Portfolio")

        let stock1 = Stock(ticker: "KO")
        let schedule1 = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.485")!,
            exDate: .now, payDate: .now
        )
        schedule1.stock = stock1
        stock1.dividendSchedules = [schedule1]
        let holding1 = Holding(shares: 100, averageCostBasis: 60)
        holding1.portfolio = portfolio
        holding1.stock = stock1

        let stock2 = Stock(ticker: "PEP")
        let schedule2 = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "1.355")!,
            exDate: .now, payDate: .now
        )
        schedule2.stock = stock2
        stock2.dividendSchedules = [schedule2]
        let holding2 = Holding(shares: 50, averageCostBasis: 170)
        holding2.portfolio = portfolio
        holding2.stock = stock2

        context.insert(portfolio)
        context.insert(stock1); context.insert(schedule1); context.insert(holding1)
        context.insert(stock2); context.insert(schedule2); context.insert(holding2)
        try context.save()

        // KO: 0.485 * 4 * 100 = 194; PEP: 1.355 * 4 * 50 = 271; Total = 465
        XCTAssertEqual(portfolio.projectedAnnualIncome, Decimal(465))
        XCTAssertEqual(portfolio.projectedMonthlyIncome, Decimal(string: "38.75")!)
    }

    // MARK: - Cascade Delete Rules

    func test_cascade_deletingPortfolio_deletesHoldings() throws {
        let portfolio = Portfolio(name: "To Delete")
        let stock = Stock(ticker: "VZ")
        let holding = Holding(shares: 50, averageCostBasis: 40)
        holding.portfolio = portfolio
        holding.stock = stock

        context.insert(portfolio)
        context.insert(stock)
        context.insert(holding)
        try context.save()

        context.delete(portfolio)
        try context.save()

        let holdings = try context.fetch(FetchDescriptor<Holding>())
        XCTAssertTrue(holdings.isEmpty, "Holdings should cascade-delete with Portfolio")

        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.count, 1, "Stock must survive Portfolio deletion")
    }

    func test_cascade_deletingHolding_doesNotDeleteStock() throws {
        let stock = Stock(ticker: "T")
        let holding = Holding(shares: 100, averageCostBasis: 20)
        holding.stock = stock

        context.insert(stock)
        context.insert(holding)
        try context.save()

        context.delete(holding)
        try context.save()

        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.count, 1, "Stock must not be deleted when Holding is removed")
    }

    func test_cascade_deletingHolding_deletesDividendPayments() throws {
        let holding = Holding(shares: 100, averageCostBasis: 30)
        let payment = DividendPayment(sharesAtTime: 100, totalAmount: Decimal(string: "30.00")!)
        payment.holding = holding

        context.insert(holding)
        context.insert(payment)
        try context.save()

        context.delete(holding)
        try context.save()

        let payments = try context.fetch(FetchDescriptor<DividendPayment>())
        XCTAssertTrue(payments.isEmpty, "DividendPayments must cascade-delete with Holding")
    }

    func test_cascade_deletingStock_deletesDividendSchedules() throws {
        let stock = Stock(ticker: "XOM")
        let schedule = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.91")!,
            exDate: .now, payDate: .now
        )
        schedule.stock = stock
        stock.dividendSchedules = [schedule]

        context.insert(stock)
        context.insert(schedule)
        try context.save()

        context.delete(stock)
        try context.save()

        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertTrue(schedules.isEmpty, "DividendSchedules must cascade-delete with Stock")
    }

    func test_nullify_deletingSchedule_doesNotDeletePayments() throws {
        let schedule = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.50")!,
            exDate: .now, payDate: .now
        )
        let holding = Holding(shares: 50, averageCostBasis: 30)
        let payment = DividendPayment(sharesAtTime: 50, totalAmount: Decimal(string: "25.00")!)
        payment.holding = holding
        payment.dividendSchedule = schedule

        context.insert(schedule)
        context.insert(holding)
        context.insert(payment)
        try context.save()

        context.delete(schedule)
        try context.save()

        let payments = try context.fetch(FetchDescriptor<DividendPayment>())
        XCTAssertEqual(payments.count, 1, "DividendPayment must survive DividendSchedule deletion")
        XCTAssertNil(payments.first?.dividendSchedule, "Schedule reference should be nullified")
    }
}
