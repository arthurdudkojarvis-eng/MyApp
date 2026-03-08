import XCTest
import SwiftData
@testable import Divvy

// MARK: - Mock

final class MockMassiveService: MassiveFetching {
    var tickerDetailsResult: MassiveTickerDetails = MassiveTickerDetails(
        ticker: "AAPL", name: "Apple Inc.", sicDescription: "Technology",
        marketCap: nil, description: nil, branding: nil
    )
    var previousCloseResult: Decimal? = Decimal(string: "185.00")
    var dividendsResult: [MassiveDividend] = []
    var searchResults: [MassiveTickerSearchResult] = []
    var shouldThrow = false
    var shouldThrowDividends = false
    var shouldThrowMarketStatus = false

    // STORY-024: New endpoint stubs
    var financialsResult: [MassiveFinancial] = []
    var aggregatesResult: [MassiveAggregate] = []
    var splitsResult: [MassiveSplit] = []
    var groupedDailyResult: [MassiveGroupedBar] = []
    var marketStatusResult: MassiveMarketStatus = MassiveMarketStatus(market: "open", serverTime: "2026-01-01T09:30:00Z")
    var marketHolidaysResult: [MassiveMarketHoliday] = []
    var relatedCompaniesResult: [String] = []
    var technicalIndicatorResult: [MassiveIndicatorValue] = []
    var previousCloseBarResult: MassiveAggregate? = nil

    // Call counts let tests verify which endpoints were (or were not) invoked.
    var fetchDetailsCallCount = 0
    var fetchPreviousCloseCallCount = 0
    var fetchDividendsCallCount = 0
    var fetchSearchCallCount = 0
    var fetchFinancialsCallCount = 0
    var fetchAggregatesCallCount = 0
    var fetchSplitsCallCount = 0
    var fetchGroupedDailyCallCount = 0
    var fetchMarketStatusCallCount = 0
    var fetchMarketHolidaysCallCount = 0
    var fetchRelatedCompaniesCallCount = 0
    var fetchTechnicalIndicatorCallCount = 0
    var fetchPreviousCloseBarCallCount = 0
    var fetchImageDataCallCount = 0

    func fetchTickerDetails(ticker: String) async throws -> MassiveTickerDetails {
        fetchDetailsCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return tickerDetailsResult
    }
    func fetchPreviousClose(ticker: String) async throws -> Decimal? {
        fetchPreviousCloseCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return previousCloseResult
    }
    func fetchDividends(ticker: String, limit: Int) async throws -> [MassiveDividend] {
        fetchDividendsCallCount += 1
        if shouldThrow || shouldThrowDividends { throw MassiveError.httpError(statusCode: 403) }
        return dividendsResult
    }
    func fetchTickerSearch(query: String, market: String) async throws -> [MassiveTickerSearchResult] {
        fetchSearchCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return searchResults
    }
    func fetchNews(tickers: [String], limit: Int) async throws -> [MassiveNewsArticle] {
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return []
    }

    // STORY-024: New endpoint stubs

    func fetchFinancials(ticker: String, limit: Int) async throws -> [MassiveFinancial] {
        fetchFinancialsCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return financialsResult
    }
    func fetchAggregates(ticker: String, from: String, to: String) async throws -> [MassiveAggregate] {
        fetchAggregatesCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return aggregatesResult
    }
    func fetchSplits(ticker: String) async throws -> [MassiveSplit] {
        fetchSplitsCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return splitsResult
    }
    func fetchGroupedDaily(date: String) async throws -> [MassiveGroupedBar] {
        fetchGroupedDailyCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return groupedDailyResult
    }
    func fetchMarketStatus() async throws -> MassiveMarketStatus {
        fetchMarketStatusCallCount += 1
        if shouldThrow || shouldThrowMarketStatus { throw MassiveError.httpError(statusCode: 403) }
        return marketStatusResult
    }
    func fetchMarketHolidays() async throws -> [MassiveMarketHoliday] {
        fetchMarketHolidaysCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return marketHolidaysResult
    }
    func fetchRelatedCompanies(ticker: String) async throws -> [String] {
        fetchRelatedCompaniesCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return relatedCompaniesResult
    }
    func fetchTechnicalIndicator(type: MassiveIndicatorType, ticker: String) async throws -> [MassiveIndicatorValue] {
        fetchTechnicalIndicatorCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return technicalIndicatorResult
    }
    func fetchPreviousCloseBar(ticker: String) async throws -> MassiveAggregate? {
        fetchPreviousCloseBarCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return previousCloseBarResult
    }
    func fetchImageData(from url: URL) async throws -> Data {
        fetchImageDataCallCount += 1
        if shouldThrow { throw MassiveError.httpError(statusCode: 403) }
        return Data()
    }
}

// MARK: - Tests

@MainActor
final class StockRefreshServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var mockMassive: MockMassiveService!
    private var sut: StockRefreshService!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.makeContainer(inMemory: true)
        mockMassive = MockMassiveService()
        sut = StockRefreshService(container: container, massive: mockMassive,
                                  interTickerDelay: .zero)
    }

    override func tearDown() async throws {
        sut = nil
        mockMassive = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func insertStock(ticker: String) throws -> Stock {
        let context = ModelContext(container)
        let stock = Stock(ticker: ticker)
        context.insert(stock)
        try context.save()
        return stock
    }

    // MARK: - refresh(ticker:) tests

    func testRefreshUpdatesCompanyName() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.tickerDetailsResult = MassiveTickerDetails(
            ticker: "AAPL", name: "Apple Inc.", sicDescription: nil, marketCap: nil, description: nil, branding: nil
        )

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.companyName, "Apple Inc.")
    }

    func testRefreshUpdatesCurrentPrice() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.previousCloseResult = Decimal(string: "185.50")

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.currentPrice, Decimal(string: "185.50")!)
    }

    func testRefreshUpdatesSector() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.tickerDetailsResult = MassiveTickerDetails(
            ticker: "AAPL", name: "Apple Inc.", sicDescription: "Technology", marketCap: nil, description: nil, branding: nil
        )

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.sector, "Technology")
    }

    func testRefreshHandlesNetworkError() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.shouldThrow = true

        // Should not crash
        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.companyName, "") // unchanged
    }

    func testRefreshLeavesCurrentPriceUnchangedWhenAPIReturnsNilPrice() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.previousCloseResult = nil   // API returns no price
        mockMassive.dividendsResult = []

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.count, 1)
        // currentPrice is non-optional (defaults to 0); nil price from API leaves it unchanged.
        XCTAssertEqual(stocks.first?.currentPrice, 0)
    }

    // MARK: - Dividend schedule tests

    func testRefreshCreatesDividendSchedules() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.dividendsResult = [
            MassiveDividend(
                ticker: "AAPL",
                cashAmount: Decimal(string: "0.24")!,
                exDividendDate: "2024-08-09",
                payDate: "2024-08-15",
                declarationDate: "2024-07-25",
                frequency: 4,
                dividendType: "CD"
            )
        ]

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(schedules.first?.amountPerShare, Decimal(string: "0.24")!)
        XCTAssertEqual(schedules.first?.frequency, .quarterly)
        XCTAssertEqual(schedules.first?.status, .declared)
    }

    func testRefreshIgnoresSpecialCashDividends() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.dividendsResult = [
            MassiveDividend(
                ticker: "AAPL",
                cashAmount: Decimal(string: "5.00")!,
                exDividendDate: "2024-08-09",
                payDate: "2024-08-15",
                declarationDate: nil,
                frequency: 1,
                dividendType: "SC"  // special cash — should be ignored
            )
        ]

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(schedules.count, 0)
    }

    func testRefreshReplacesExistingSchedules() async throws {
        // Pre-populate with one schedule
        let context = ModelContext(container)
        let stock = Stock(ticker: "VYM")
        context.insert(stock)
        let oldSchedule = DividendSchedule(
            frequency: .quarterly, amountPerShare: Decimal(string: "0.90")!,
            exDate: .now, payDate: .now, declaredDate: .now
        )
        oldSchedule.stock = stock
        context.insert(oldSchedule)
        try context.save()

        mockMassive.dividendsResult = [
            MassiveDividend(
                ticker: "VYM",
                cashAmount: Decimal(string: "0.95")!,
                exDividendDate: "2024-09-20",
                payDate: "2024-09-27",
                declarationDate: nil,
                frequency: 4,
                dividendType: "CD"
            )
        ]

        await sut.refresh(ticker: "VYM")

        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(schedules.first?.amountPerShare, Decimal(string: "0.95")!)
    }

    func testRefreshIgnoresDividendWithUnknownFrequency() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.previousCloseResult = Decimal(string: "185.00")
        mockMassive.dividendsResult = [
            MassiveDividend(
                ticker: "AAPL",
                cashAmount: Decimal(string: "0.25")!,
                // Far-future date ensures date filtering can't cause a false pass
                exDividendDate: "2099-08-09",
                payDate: "2099-08-15",
                declarationDate: nil,
                frequency: 99,           // not 1, 2, 4, or 12 — should be ignored
                dividendType: "CD"
            )
        ]

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(schedules.count, 0)
    }

    func testRefreshSkipsWhenStockNotInDatabase() async throws {
        // No Stock inserted — service fetches the API then finds no matching DB record.
        await sut.refresh(ticker: "ZZZZ")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(stocks.count, 0)       // nothing written
        XCTAssertEqual(schedules.count, 0)    // no orphaned schedules
    }

    // MARK: - refreshStaleStocks

    func testRefreshStaleStocksSkipsNonStaleStocks() async throws {
        let context = ModelContext(container)
        let freshStock = Stock(ticker: "MSFT")
        freshStock.lastUpdated = .now   // not stale
        context.insert(freshStock)
        try context.save()

        await sut.refreshStaleStocks()

        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.companyName, "") // not refreshed
        XCTAssertEqual(mockMassive.fetchDetailsCallCount, 0)
    }

    func testRefreshStaleStocksSetsLastRefreshErrorOnFailure() async throws {
        let context = ModelContext(container)
        let staleStock = Stock(ticker: "FAIL")
        staleStock.lastUpdated = .distantPast
        context.insert(staleStock)
        try context.save()
        mockMassive.shouldThrow = true

        await sut.refreshStaleStocks()

        XCTAssertNotNil(sut.lastRefreshError)
        XCTAssertTrue(sut.lastRefreshError?.contains("FAIL") == true)
    }

    func testRefreshStaleStocksClearsErrorBeforeNewRefresh() async throws {
        let context = ModelContext(container)
        let staleStock = Stock(ticker: "AAPL")
        staleStock.lastUpdated = .distantPast
        context.insert(staleStock)
        try context.save()

        // First pass — fails.
        mockMassive.shouldThrow = true
        await sut.refreshStaleStocks()
        XCTAssertNotNil(sut.lastRefreshError)

        // Second pass — succeeds. Mark stock as stale again.
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        stocks.first?.lastUpdated = .distantPast
        try context.save()

        mockMassive.shouldThrow = false
        await sut.refreshStaleStocks()
        XCTAssertNil(sut.lastRefreshError)
    }

    func testDismissRefreshError() async throws {
        let context = ModelContext(container)
        let staleStock = Stock(ticker: "ERR")
        staleStock.lastUpdated = .distantPast
        context.insert(staleStock)
        try context.save()
        mockMassive.shouldThrow = true

        await sut.refreshStaleStocks()
        XCTAssertNotNil(sut.lastRefreshError)

        sut.dismissRefreshError()
        XCTAssertNil(sut.lastRefreshError)
    }

    // MARK: - Performance & Data Integrity (STORY-018)

    func testRefreshStaleStocksRefreshesAllStaleTickersSequentially() async throws {
        let context = ModelContext(container)
        let stock1 = Stock(ticker: "AAPL")
        let stock2 = Stock(ticker: "MSFT")
        stock1.lastUpdated = .distantPast
        stock2.lastUpdated = .distantPast
        context.insert(stock1)
        context.insert(stock2)
        try context.save()

        mockMassive.tickerDetailsResult = MassiveTickerDetails(
            ticker: "AAPL", name: "Updated", sicDescription: nil, marketCap: nil, description: nil, branding: nil
        )

        await sut.refreshStaleStocks()

        // Both tickers must have been fetched (sequential, not skipped).
        XCTAssertEqual(mockMassive.fetchDetailsCallCount, 2)
        XCTAssertEqual(mockMassive.fetchDividendsCallCount, 2)
        // With >= 2 stale tickers, grouped daily is used instead of per-ticker snapshots (STORY-035).
        XCTAssertEqual(mockMassive.fetchGroupedDailyCallCount, 1)
        // Per-ticker snapshot is skipped when batch prices are available.
        // (Empty groupedDailyResult means batchPrice is nil, so fallback kicks in.)
        // The mock returns empty results, so fetchPreviousClose is still called as fallback.
        XCTAssertEqual(mockMassive.fetchPreviousCloseCallCount, 2)
    }

    func testFreshStocksAreNotRefreshedByStaleQuery() async throws {
        let context = ModelContext(container)
        let freshStock = Stock(ticker: "FRESH")
        freshStock.lastUpdated = .now   // not stale
        let staleStock = Stock(ticker: "STALE")
        staleStock.lastUpdated = .distantPast
        context.insert(freshStock)
        context.insert(staleStock)
        try context.save()

        await sut.refreshStaleStocks()

        // Predicate must filter server-side; only one ticker should be refreshed.
        XCTAssertEqual(mockMassive.fetchDetailsCallCount, 1)
    }

    func testDividendScheduleDiffingUpdatesExistingScheduleInPlace() async throws {
        // Arrange: pre-populate with a schedule and a payment linked to it.
        let context = ModelContext(container)
        let stock = Stock(ticker: "VYM")
        stock.lastUpdated = .distantPast
        context.insert(stock)

        let exDateString = "2024-08-09"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let exDate = formatter.date(from: exDateString)!

        let originalSchedule = DividendSchedule(
            frequency: .quarterly, amountPerShare: Decimal(string: "0.90")!,
            exDate: exDate, payDate: exDate, declaredDate: .now
        )
        originalSchedule.stock = stock
        context.insert(originalSchedule)

        let payment = DividendPayment(sharesAtTime: 10, totalAmount: Decimal(string: "9.00")!)
        payment.holding = nil
        payment.dividendSchedule = originalSchedule
        context.insert(payment)

        try context.save()
        let originalScheduleID = originalSchedule.id

        // API now returns the same ex-date but a revised amount.
        mockMassive.dividendsResult = [
            MassiveDividend(
                ticker: "VYM",
                cashAmount: Decimal(string: "0.95")!,
                exDividendDate: exDateString,
                payDate: "2024-08-15",
                declarationDate: "2024-07-25",
                frequency: 4,
                dividendType: "CD"
            )
        ]

        await sut.refresh(ticker: "VYM")

        // Schedule should be updated in place (same id), not replaced.
        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(schedules.first?.id, originalScheduleID)
        XCTAssertEqual(schedules.first?.amountPerShare, Decimal(string: "0.95")!)
        XCTAssertEqual(schedules.first?.status, .declared)  // declarationDate was set → .declared

        // The payment's link to the schedule must survive the refresh.
        let payments = try context.fetch(FetchDescriptor<DividendPayment>())
        XCTAssertEqual(payments.count, 1)
        XCTAssertNotNil(payments.first?.dividendSchedule)
    }

    func testDividendScheduleDiffingDeletesRemovedSchedules() async throws {
        let context = ModelContext(container)
        let stock = Stock(ticker: "O")
        context.insert(stock)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        let old = DividendSchedule(
            frequency: .monthly, amountPerShare: Decimal(string: "0.26")!,
            exDate: formatter.date(from: "2024-01-10")!,
            payDate: formatter.date(from: "2024-01-15")!,
            declaredDate: .now
        )
        old.stock = stock
        context.insert(old)
        try context.save()

        // API returns a completely different ex-date.
        mockMassive.tickerDetailsResult = MassiveTickerDetails(
            ticker: "O", name: "Realty Income Corp.", sicDescription: nil, marketCap: nil, description: nil, branding: nil
        )
        mockMassive.dividendsResult = [
            MassiveDividend(
                ticker: "O",
                cashAmount: Decimal(string: "0.26")!,
                exDividendDate: "2024-02-10",
                payDate: "2024-02-15",
                declarationDate: nil,
                frequency: 12,
                dividendType: "CD"
            )
        ]

        await sut.refresh(ticker: "O")

        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(schedules.count, 1)
        // The old ex-date should be gone; the new one present.
        XCTAssertEqual(
            formatter.string(from: schedules.first!.exDate),
            "2024-02-10"
        )
    }

    func testDividendScheduleDiffingIgnoresDuplicateExDatesInAPIResponse() async throws {
        let context = ModelContext(container)
        let stock = Stock(ticker: "AAPL")
        context.insert(stock)
        try context.save()

        // Two dividends with the same ex-date — only the first should be persisted.
        mockMassive.dividendsResult = [
            MassiveDividend(
                ticker: "AAPL",
                cashAmount: Decimal(string: "0.24")!,
                exDividendDate: "2024-08-09",
                payDate: "2024-08-15",
                declarationDate: "2024-07-25",
                frequency: 4,
                dividendType: "CD"
            ),
            MassiveDividend(
                ticker: "AAPL",
                cashAmount: Decimal(string: "0.50")!,  // different amount, same ex-date
                exDividendDate: "2024-08-09",
                payDate: "2024-08-15",
                declarationDate: nil,
                frequency: 4,
                dividendType: "CD"
            )
        ]

        await sut.refresh(ticker: "AAPL")

        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(schedules.count, 1)
        // First entry wins; second is silently dropped.
        XCTAssertEqual(schedules.first?.amountPerShare, Decimal(string: "0.24")!)
    }

    func testRefreshStaleStocksDoesNotDoubleInvoke() async throws {
        let context = ModelContext(container)
        let staleStock = Stock(ticker: "T")
        // lastUpdated defaults to .distantPast → always stale
        context.insert(staleStock)
        try context.save()

        // Use explicit Tasks so the two calls arrive on the @MainActor
        // independently and the guard !isRefreshing is actually exercised.
        let t1 = Task { await sut.refreshStaleStocks() }
        let t2 = Task { await sut.refreshStaleStocks() }
        await t1.value
        await t2.value

        // Guard must have released the flag correctly.
        XCTAssertFalse(sut.isRefreshing)
        // The @MainActor guard serialises entry; second call sees isRefreshing == true
        // and bails, so the ticker details endpoint is hit at most once.
        XCTAssertLessThanOrEqual(mockMassive.fetchDetailsCallCount, 1)
    }

    // MARK: - Dividend fetch strictness (ISSUE-14)

    func testRefreshSavesPriceAndNameEvenWhenDividendFetchFails() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.tickerDetailsResult = MassiveTickerDetails(
            ticker: "AAPL", name: "Apple Inc.", sicDescription: nil, marketCap: nil, description: nil, branding: nil
        )
        mockMassive.previousCloseResult = Decimal(string: "195.00")
        mockMassive.shouldThrowDividends = true   // dividends fail, price+name should still save

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.companyName, "Apple Inc.", "Name should be saved despite dividend failure")
        XCTAssertEqual(stocks.first?.currentPrice, Decimal(string: "195.00")!, "Price should be saved despite dividend failure")
        let schedules = try context.fetch(FetchDescriptor<DividendSchedule>())
        XCTAssertEqual(schedules.count, 0, "No dividend schedules when fetch fails")
    }

    func testRefreshDoesNotSetLastRefreshErrorWhenOnlyDividendsFail() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockMassive.shouldThrowDividends = true

        await sut.refresh(ticker: "AAPL")

        // Dividend failure is logged, not surfaced to the user.
        XCTAssertNil(sut.lastRefreshError)
    }

    // MARK: - Market-aware refresh (STORY-034)

    func testRefreshStaleStocksSkipsWhenMarketClosed() async throws {
        let context = ModelContext(container)
        let stock = Stock(ticker: "AAPL")
        stock.lastUpdated = .distantPast
        context.insert(stock)
        try context.save()

        mockMassive.marketStatusResult = MassiveMarketStatus(market: "closed", serverTime: "2026-02-28T20:00:00Z")

        await sut.refreshStaleStocks()

        // Market is closed — should skip all refresh work.
        XCTAssertEqual(mockMassive.fetchMarketStatusCallCount, 1)
        XCTAssertEqual(mockMassive.fetchDetailsCallCount, 0, "Should not refresh when market is closed")
    }

    func testRefreshStaleStocksProceedsWhenMarketOpen() async throws {
        let context = ModelContext(container)
        let stock = Stock(ticker: "AAPL")
        stock.lastUpdated = .distantPast
        context.insert(stock)
        try context.save()

        mockMassive.marketStatusResult = MassiveMarketStatus(market: "open", serverTime: "2026-02-28T14:00:00Z")

        await sut.refreshStaleStocks()

        XCTAssertEqual(mockMassive.fetchDetailsCallCount, 1, "Should refresh when market is open")
    }

    func testRefreshStaleStocksProceedsWhenMarketExtendedHours() async throws {
        let context = ModelContext(container)
        let stock = Stock(ticker: "AAPL")
        stock.lastUpdated = .distantPast
        context.insert(stock)
        try context.save()

        mockMassive.marketStatusResult = MassiveMarketStatus(market: "extended-hours", serverTime: "2026-02-28T18:00:00Z")

        await sut.refreshStaleStocks()

        XCTAssertEqual(mockMassive.fetchDetailsCallCount, 1, "Should refresh during extended hours")
    }

    func testRefreshStaleStocksFailsOpenWhenMarketStatusThrows() async throws {
        let context = ModelContext(container)
        let stock = Stock(ticker: "AAPL")
        stock.lastUpdated = .distantPast
        context.insert(stock)
        try context.save()

        mockMassive.shouldThrowMarketStatus = true

        await sut.refreshStaleStocks()

        // Market status check failed — should proceed with refresh (fail-open).
        XCTAssertEqual(mockMassive.fetchDetailsCallCount, 1, "Should fail-open when market status throws")
    }

    // MARK: - Batch price fetch (STORY-035)

    func testRefreshStaleStocksUsesBatchPriceWhenMultipleTickers() async throws {
        let context = ModelContext(container)
        let stock1 = Stock(ticker: "AAPL")
        let stock2 = Stock(ticker: "MSFT")
        stock1.lastUpdated = .distantPast
        stock2.lastUpdated = .distantPast
        context.insert(stock1)
        context.insert(stock2)
        try context.save()

        // Provide batch prices so per-ticker snapshot is not needed.
        mockMassive.groupedDailyResult = [
            MassiveGroupedBar(T: "AAPL", o: 260, h: 265, l: 258, c: 264, v: 1000, vw: 262, t: 1000000, n: 100),
            MassiveGroupedBar(T: "MSFT", o: 410, h: 415, l: 408, c: 412, v: 2000, vw: 411, t: 1000000, n: 200)
        ]

        await sut.refreshStaleStocks()

        XCTAssertEqual(mockMassive.fetchGroupedDailyCallCount, 1, "Should call grouped daily once for batch")
        XCTAssertEqual(mockMassive.fetchPreviousCloseCallCount, 0, "Should skip per-ticker snapshot when batch prices available")

        // Verify prices were written
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        let aapl = stocks.first(where: { $0.ticker == "AAPL" })
        let msft = stocks.first(where: { $0.ticker == "MSFT" })
        XCTAssertEqual(aapl?.currentPrice, 264, "Batch price should be written to stock")
        XCTAssertEqual(msft?.currentPrice, 412, "Batch price should be written to stock")
    }

    func testRefreshSingleStaleStockSkipsBatchFetch() async throws {
        let context = ModelContext(container)
        let stock = Stock(ticker: "AAPL")
        stock.lastUpdated = .distantPast
        context.insert(stock)
        try context.save()

        await sut.refreshStaleStocks()

        // Only 1 stale stock — should use per-ticker snapshot, not grouped daily.
        XCTAssertEqual(mockMassive.fetchGroupedDailyCallCount, 0, "Should not call grouped daily for single ticker")
        XCTAssertEqual(mockMassive.fetchPreviousCloseCallCount, 1, "Should use per-ticker snapshot for single ticker")
    }
}
