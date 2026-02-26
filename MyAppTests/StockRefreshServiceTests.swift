import XCTest
import SwiftData
@testable import MyApp

// MARK: - Mock

final class MockPolygonService: PolygonFetching {
    var tickerDetailsResult: PolygonTickerDetails = PolygonTickerDetails(
        ticker: "AAPL", name: "Apple Inc.", sicDescription: "Technology"
    )
    var previousCloseResult: Decimal? = Decimal(string: "185.00")
    var dividendsResult: [PolygonDividend] = []
    var shouldThrow = false

    // Call counts let tests verify which endpoints were (or were not) invoked.
    var fetchDetailsCallCount = 0
    var fetchPreviousCloseCallCount = 0
    var fetchDividendsCallCount = 0

    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> PolygonTickerDetails {
        fetchDetailsCallCount += 1
        if shouldThrow { throw PolygonError.httpError(statusCode: 403) }
        return tickerDetailsResult
    }
    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal? {
        fetchPreviousCloseCallCount += 1
        if shouldThrow { throw PolygonError.httpError(statusCode: 403) }
        return previousCloseResult
    }
    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [PolygonDividend] {
        fetchDividendsCallCount += 1
        if shouldThrow { throw PolygonError.httpError(statusCode: 403) }
        return dividendsResult
    }
}

// MARK: - Tests

@MainActor
final class StockRefreshServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var settings: SettingsStore!
    private var mockPolygon: MockPolygonService!
    private var sut: StockRefreshService!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.makeContainer(inMemory: true)
        settings = SettingsStore(
            keychain: KeychainService(service: "com.myapp.tests.refresh.\(UUID().uuidString)"),
            defaults: UserDefaults(suiteName: "com.myapp.tests.refresh.\(UUID().uuidString)")!
        )
        settings.polygonAPIKey = "test-api-key"
        mockPolygon = MockPolygonService()
        sut = StockRefreshService(settings: settings, container: container, polygon: mockPolygon,
                                  interTickerDelay: .zero)
    }

    override func tearDown() async throws {
        sut = nil
        mockPolygon = nil
        settings = nil
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
        mockPolygon.tickerDetailsResult = PolygonTickerDetails(
            ticker: "AAPL", name: "Apple Inc.", sicDescription: nil
        )

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.companyName, "Apple Inc.")
    }

    func testRefreshUpdatesCurrentPrice() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockPolygon.previousCloseResult = Decimal(string: "185.50")

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.currentPrice, Decimal(string: "185.50")!)
    }

    func testRefreshUpdatesSector() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockPolygon.tickerDetailsResult = PolygonTickerDetails(
            ticker: "AAPL", name: "Apple Inc.", sicDescription: "Technology"
        )

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.sector, "Technology")
    }

    func testRefreshSkipsWhenNoAPIKey() async throws {
        _ = try insertStock(ticker: "AAPL")
        settings.polygonAPIKey = ""

        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.companyName, "") // unchanged
        XCTAssertEqual(mockPolygon.fetchDetailsCallCount, 0) // no API call
    }

    func testRefreshHandlesNetworkError() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockPolygon.shouldThrow = true

        // Should not crash
        await sut.refresh(ticker: "AAPL")

        let context = ModelContext(container)
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        XCTAssertEqual(stocks.first?.companyName, "") // unchanged
    }

    func testRefreshLeavesCurrentPriceUnchangedWhenAPIReturnsNilPrice() async throws {
        _ = try insertStock(ticker: "AAPL")
        mockPolygon.previousCloseResult = nil   // API returns no price
        mockPolygon.dividendsResult = []

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
        mockPolygon.dividendsResult = [
            PolygonDividend(
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
        mockPolygon.dividendsResult = [
            PolygonDividend(
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

        mockPolygon.dividendsResult = [
            PolygonDividend(
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
        mockPolygon.previousCloseResult = Decimal(string: "185.00")
        mockPolygon.dividendsResult = [
            PolygonDividend(
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
        XCTAssertEqual(mockPolygon.fetchDetailsCallCount, 0)
    }

    func testRefreshStaleStocksSetsLastRefreshErrorOnFailure() async throws {
        let context = ModelContext(container)
        let staleStock = Stock(ticker: "FAIL")
        staleStock.lastUpdated = .distantPast
        context.insert(staleStock)
        try context.save()
        mockPolygon.shouldThrow = true

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
        mockPolygon.shouldThrow = true
        await sut.refreshStaleStocks()
        XCTAssertNotNil(sut.lastRefreshError)

        // Second pass — succeeds. Mark stock as stale again.
        let stocks = try context.fetch(FetchDescriptor<Stock>())
        stocks.first?.lastUpdated = .distantPast
        try context.save()

        mockPolygon.shouldThrow = false
        await sut.refreshStaleStocks()
        XCTAssertNil(sut.lastRefreshError)
    }

    func testDismissRefreshError() async throws {
        let context = ModelContext(container)
        let staleStock = Stock(ticker: "ERR")
        staleStock.lastUpdated = .distantPast
        context.insert(staleStock)
        try context.save()
        mockPolygon.shouldThrow = true

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

        mockPolygon.tickerDetailsResult = PolygonTickerDetails(
            ticker: "AAPL", name: "Updated", sicDescription: nil
        )

        await sut.refreshStaleStocks()

        // Both tickers must have been fetched (sequential, not skipped).
        XCTAssertEqual(mockPolygon.fetchDetailsCallCount, 2)
        XCTAssertEqual(mockPolygon.fetchPreviousCloseCallCount, 2)
        XCTAssertEqual(mockPolygon.fetchDividendsCallCount, 2)
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
        XCTAssertEqual(mockPolygon.fetchDetailsCallCount, 1)
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
        mockPolygon.dividendsResult = [
            PolygonDividend(
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
        mockPolygon.tickerDetailsResult = PolygonTickerDetails(
            ticker: "O", name: "Realty Income Corp.", sicDescription: nil
        )
        mockPolygon.dividendsResult = [
            PolygonDividend(
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
        mockPolygon.dividendsResult = [
            PolygonDividend(
                ticker: "AAPL",
                cashAmount: Decimal(string: "0.24")!,
                exDividendDate: "2024-08-09",
                payDate: "2024-08-15",
                declarationDate: "2024-07-25",
                frequency: 4,
                dividendType: "CD"
            ),
            PolygonDividend(
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
        XCTAssertLessThanOrEqual(mockPolygon.fetchDetailsCallCount, 1)
    }
}
