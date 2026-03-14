import XCTest
@testable import Divvy

// MARK: - Mock

final class MockFinnhubService: FinnhubFetching {
    var recommendationResult: [FinnhubRecommendation] = []
    var priceTargetResult: FinnhubPriceTarget = FinnhubPriceTarget(
        targetHigh: 200, targetLow: 150, targetMean: 180,
        targetMedian: 178, lastUpdated: "2026-03-01"
    )
    var companyProfileResult: FinnhubCompanyProfile = FinnhubCompanyProfile(
        country: "US", currency: "USD", exchange: "NASDAQ",
        finnhubIndustry: "Technology", ipo: "1980-12-12", logo: "https://logo.example.com/AAPL.png",
        marketCapitalization: 3000000, name: "Apple Inc",
        shareOutstanding: 15500, ticker: "AAPL", weburl: "https://apple.com"
    )
    var quoteResult: FinnhubQuote = FinnhubQuote(
        c: 185.50, d: 2.30, dp: 1.25, h: 187.00, l: 183.00, o: 184.00, pc: 183.20, t: 1710000000
    )
    var basicFinancialsResult: FinnhubBasicFinancials = FinnhubBasicFinancials(metrics: [
        "52WeekHigh": 199.62, "52WeekLow": 124.17, "beta": 1.29,
        "dividendYieldIndicatedAnnual": 0.55, "payoutRatioAnnual": 15.73
    ])
    var peersResult: [String] = ["MSFT", "GOOG", "META"]
    var earningsResult: [FinnhubEarning] = []
    var insiderTransactionsResult: [FinnhubInsiderTransaction] = []
    var insiderSentimentResult: [FinnhubInsiderSentimentData] = []
    var earningsCalendarResult: [FinnhubEarningsCalendarEntry] = []
    var companyNewsResult: [FinnhubNewsArticle] = []
    var generalNewsResult: [FinnhubNewsArticle] = []
    var shouldThrow = false

    // Call counts let tests verify which endpoints were (or were not) invoked.
    var fetchRecommendationCallCount = 0
    var fetchPriceTargetCallCount = 0
    var fetchCompanyProfileCallCount = 0
    var fetchQuoteCallCount = 0
    var fetchBasicFinancialsCallCount = 0
    var fetchPeersCallCount = 0
    var fetchEarningsCallCount = 0
    var fetchInsiderTransactionsCallCount = 0
    var fetchInsiderSentimentCallCount = 0
    var fetchEarningsCalendarCallCount = 0
    var fetchCompanyNewsCallCount = 0
    var fetchGeneralNewsCallCount = 0

    func fetchRecommendationTrends(ticker: String) async throws -> [FinnhubRecommendation] {
        fetchRecommendationCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return recommendationResult
    }

    func fetchPriceTarget(ticker: String) async throws -> FinnhubPriceTarget {
        fetchPriceTargetCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return priceTargetResult
    }

    func fetchCompanyProfile(ticker: String) async throws -> FinnhubCompanyProfile {
        fetchCompanyProfileCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return companyProfileResult
    }

    func fetchQuote(ticker: String) async throws -> FinnhubQuote {
        fetchQuoteCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return quoteResult
    }

    func fetchBasicFinancials(ticker: String) async throws -> FinnhubBasicFinancials {
        fetchBasicFinancialsCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return basicFinancialsResult
    }

    func fetchPeers(ticker: String) async throws -> [String] {
        fetchPeersCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return peersResult
    }

    func fetchEarnings(ticker: String) async throws -> [FinnhubEarning] {
        fetchEarningsCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return earningsResult
    }

    func fetchInsiderTransactions(ticker: String) async throws -> [FinnhubInsiderTransaction] {
        fetchInsiderTransactionsCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return insiderTransactionsResult
    }

    func fetchInsiderSentiment(ticker: String, from: String, to: String) async throws -> [FinnhubInsiderSentimentData] {
        fetchInsiderSentimentCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return insiderSentimentResult
    }

    func fetchEarningsCalendar(from: String, to: String) async throws -> [FinnhubEarningsCalendarEntry] {
        fetchEarningsCalendarCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return earningsCalendarResult
    }

    func fetchCompanyNews(ticker: String, from: String, to: String) async throws -> [FinnhubNewsArticle] {
        fetchCompanyNewsCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return companyNewsResult
    }

    func fetchGeneralNews(category: String) async throws -> [FinnhubNewsArticle] {
        fetchGeneralNewsCallCount += 1
        if shouldThrow { throw FinnhubError.httpError(statusCode: 403) }
        return generalNewsResult
    }
}

// MARK: - Tests

@MainActor
final class FinnhubServiceTests: XCTestCase {
    private var mock: MockFinnhubService!

    override func setUp() {
        super.setUp()
        mock = MockFinnhubService()
    }

    // MARK: - Recommendation Trends

    func testFetchRecommendationTrends_returnsStubData() async throws {
        let stub = FinnhubRecommendation(
            buy: 10, hold: 5, sell: 2, strongBuy: 8, strongSell: 1, period: "2026-03-01"
        )
        mock.recommendationResult = [stub]

        let results = try await mock.fetchRecommendationTrends(ticker: "AAPL")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].buy, 10)
        XCTAssertEqual(results[0].hold, 5)
        XCTAssertEqual(results[0].sell, 2)
        XCTAssertEqual(results[0].strongBuy, 8)
        XCTAssertEqual(results[0].strongSell, 1)
        XCTAssertEqual(results[0].period, "2026-03-01")
    }

    func testFetchRecommendationTrends_incrementsCallCount() async throws {
        _ = try await mock.fetchRecommendationTrends(ticker: "AAPL")
        _ = try await mock.fetchRecommendationTrends(ticker: "MSFT")

        XCTAssertEqual(mock.fetchRecommendationCallCount, 2)
    }

    // MARK: - Price Target

    func testFetchPriceTarget_returnsStubData() async throws {
        mock.priceTargetResult = FinnhubPriceTarget(
            targetHigh: 250, targetLow: 180, targetMean: 220,
            targetMedian: 215, lastUpdated: "2026-02-15"
        )

        let result = try await mock.fetchPriceTarget(ticker: "AAPL")

        XCTAssertEqual(result.targetHigh, 250)
        XCTAssertEqual(result.targetLow, 180)
        XCTAssertEqual(result.targetMean, 220)
        XCTAssertEqual(result.targetMedian, 215)
        XCTAssertEqual(result.lastUpdated, "2026-02-15")
    }

    func testFetchPriceTarget_incrementsCallCount() async throws {
        _ = try await mock.fetchPriceTarget(ticker: "AAPL")
        _ = try await mock.fetchPriceTarget(ticker: "MSFT")
        _ = try await mock.fetchPriceTarget(ticker: "GOOG")

        XCTAssertEqual(mock.fetchPriceTargetCallCount, 3)
    }

    // MARK: - Company Profile

    func testFetchCompanyProfile_returnsStubData() async throws {
        let result = try await mock.fetchCompanyProfile(ticker: "AAPL")

        XCTAssertEqual(result.name, "Apple Inc")
        XCTAssertEqual(result.ticker, "AAPL")
        XCTAssertEqual(result.country, "US")
        XCTAssertEqual(result.currency, "USD")
        XCTAssertEqual(result.exchange, "NASDAQ")
        XCTAssertEqual(result.finnhubIndustry, "Technology")
        XCTAssertEqual(result.marketCapitalization, 3000000)
    }

    func testFetchCompanyProfile_incrementsCallCount() async throws {
        _ = try await mock.fetchCompanyProfile(ticker: "AAPL")
        _ = try await mock.fetchCompanyProfile(ticker: "MSFT")

        XCTAssertEqual(mock.fetchCompanyProfileCallCount, 2)
    }

    // MARK: - Quote

    func testFetchQuote_returnsStubData() async throws {
        let result = try await mock.fetchQuote(ticker: "AAPL")

        XCTAssertEqual(result.c, 185.50)
        XCTAssertEqual(result.d, 2.30)
        XCTAssertEqual(result.dp, 1.25)
        XCTAssertEqual(result.h, 187.00)
        XCTAssertEqual(result.l, 183.00)
        XCTAssertEqual(result.o, 184.00)
        XCTAssertEqual(result.pc, 183.20)
        XCTAssertEqual(result.t, 1710000000)
    }

    func testFetchQuote_incrementsCallCount() async throws {
        _ = try await mock.fetchQuote(ticker: "AAPL")

        XCTAssertEqual(mock.fetchQuoteCallCount, 1)
    }

    // MARK: - Basic Financials

    func testFetchBasicFinancials_returnsStubData() async throws {
        let result = try await mock.fetchBasicFinancials(ticker: "AAPL")

        XCTAssertEqual(result.weekHigh52, 199.62)
        XCTAssertEqual(result.weekLow52, 124.17)
        XCTAssertEqual(result.beta, 1.29)
        XCTAssertEqual(result.dividendYieldIndicatedAnnual, 0.55)
        XCTAssertEqual(result.payoutRatioAnnual, 15.73)
    }

    func testFetchBasicFinancials_incrementsCallCount() async throws {
        _ = try await mock.fetchBasicFinancials(ticker: "AAPL")
        _ = try await mock.fetchBasicFinancials(ticker: "MSFT")

        XCTAssertEqual(mock.fetchBasicFinancialsCallCount, 2)
    }

    // MARK: - Peers

    func testFetchPeers_returnsStubData() async throws {
        let result = try await mock.fetchPeers(ticker: "AAPL")

        XCTAssertEqual(result, ["MSFT", "GOOG", "META"])
    }

    func testFetchPeers_incrementsCallCount() async throws {
        _ = try await mock.fetchPeers(ticker: "AAPL")

        XCTAssertEqual(mock.fetchPeersCallCount, 1)
    }

    // MARK: - Earnings

    func testFetchEarnings_returnsStubData() async throws {
        let stub = FinnhubEarning(
            actual: 1.52, estimate: 1.43, period: "2025-12-31",
            quarter: 4, surprise: 0.09, surprisePercent: 6.29,
            symbol: "AAPL", year: 2025
        )
        mock.earningsResult = [stub]

        let results = try await mock.fetchEarnings(ticker: "AAPL")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].actual, 1.52)
        XCTAssertEqual(results[0].estimate, 1.43)
        XCTAssertEqual(results[0].period, "2025-12-31")
        XCTAssertEqual(results[0].quarter, 4)
        XCTAssertEqual(results[0].surprise, 0.09)
        XCTAssertEqual(results[0].surprisePercent, 6.29)
        XCTAssertEqual(results[0].symbol, "AAPL")
        XCTAssertEqual(results[0].year, 2025)
    }

    func testFetchEarnings_incrementsCallCount() async throws {
        _ = try await mock.fetchEarnings(ticker: "AAPL")
        _ = try await mock.fetchEarnings(ticker: "MSFT")

        XCTAssertEqual(mock.fetchEarningsCallCount, 2)
    }

    // MARK: - Insider Transactions

    func testFetchInsiderTransactions_returnsStubData() async throws {
        let stub = FinnhubInsiderTransaction(
            change: -5000, filingDate: "2026-02-14", name: "Tim Cook",
            share: 100000, symbol: "AAPL", transactionCode: "S",
            transactionDate: "2026-02-12", transactionPrice: 185.00
        )
        mock.insiderTransactionsResult = [stub]

        let results = try await mock.fetchInsiderTransactions(ticker: "AAPL")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].change, -5000)
        XCTAssertEqual(results[0].name, "Tim Cook")
        XCTAssertEqual(results[0].transactionCode, "S")
        XCTAssertEqual(results[0].transactionPrice, 185.00)
    }

    func testFetchInsiderTransactions_incrementsCallCount() async throws {
        _ = try await mock.fetchInsiderTransactions(ticker: "AAPL")

        XCTAssertEqual(mock.fetchInsiderTransactionsCallCount, 1)
    }

    // MARK: - Insider Sentiment

    func testFetchInsiderSentiment_returnsStubData() async throws {
        let stub = FinnhubInsiderSentimentData(
            symbol: "AAPL", year: 2026, month: 1, change: 15000, mspr: 25.5
        )
        mock.insiderSentimentResult = [stub]

        let results = try await mock.fetchInsiderSentiment(ticker: "AAPL", from: "2026-01-01", to: "2026-03-01")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].symbol, "AAPL")
        XCTAssertEqual(results[0].year, 2026)
        XCTAssertEqual(results[0].month, 1)
        XCTAssertEqual(results[0].change, 15000)
        XCTAssertEqual(results[0].mspr, 25.5)
    }

    func testFetchInsiderSentiment_incrementsCallCount() async throws {
        _ = try await mock.fetchInsiderSentiment(ticker: "AAPL", from: "2026-01-01", to: "2026-03-01")

        XCTAssertEqual(mock.fetchInsiderSentimentCallCount, 1)
    }

    // MARK: - Earnings Calendar

    func testFetchEarningsCalendar_returnsStubData() async throws {
        let stub = FinnhubEarningsCalendarEntry(
            date: "2026-04-25", epsActual: nil, epsEstimate: 1.60,
            hour: "amc", quarter: 2, revenueActual: nil,
            revenueEstimate: 94500000000, symbol: "AAPL", year: 2026
        )
        mock.earningsCalendarResult = [stub]

        let results = try await mock.fetchEarningsCalendar(from: "2026-04-01", to: "2026-04-30")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].date, "2026-04-25")
        XCTAssertNil(results[0].epsActual)
        XCTAssertEqual(results[0].epsEstimate, 1.60)
        XCTAssertEqual(results[0].hour, "amc")
        XCTAssertEqual(results[0].symbol, "AAPL")
    }

    func testFetchEarningsCalendar_incrementsCallCount() async throws {
        _ = try await mock.fetchEarningsCalendar(from: "2026-04-01", to: "2026-04-30")
        _ = try await mock.fetchEarningsCalendar(from: "2026-05-01", to: "2026-05-31")

        XCTAssertEqual(mock.fetchEarningsCalendarCallCount, 2)
    }

    // MARK: - Company News

    func testFetchCompanyNews_returnsStubData() async throws {
        let stub = FinnhubNewsArticle(
            id: 12345, category: "company", datetime: 1710000000,
            headline: "Apple reports record Q1 earnings", image: "https://img.example.com/1.jpg",
            related: "AAPL", source: "Reuters",
            summary: "Apple beat estimates.", url: "https://reuters.com/article/1"
        )
        mock.companyNewsResult = [stub]

        let results = try await mock.fetchCompanyNews(ticker: "AAPL", from: "2026-03-01", to: "2026-03-13")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, 12345)
        XCTAssertEqual(results[0].headline, "Apple reports record Q1 earnings")
        XCTAssertEqual(results[0].source, "Reuters")
        XCTAssertEqual(results[0].related, "AAPL")
    }

    func testFetchCompanyNews_incrementsCallCount() async throws {
        _ = try await mock.fetchCompanyNews(ticker: "AAPL", from: "2026-03-01", to: "2026-03-13")

        XCTAssertEqual(mock.fetchCompanyNewsCallCount, 1)
    }

    // MARK: - General News

    func testFetchGeneralNews_returnsStubData() async throws {
        let stub = FinnhubNewsArticle(
            id: 67890, category: "general", datetime: 1710000000,
            headline: "Markets surge on Fed decision", image: nil,
            related: nil, source: "CNBC",
            summary: "S&P 500 hits new highs.", url: "https://cnbc.com/article/2"
        )
        mock.generalNewsResult = [stub]

        let results = try await mock.fetchGeneralNews(category: "general")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, 67890)
        XCTAssertEqual(results[0].category, "general")
        XCTAssertEqual(results[0].headline, "Markets surge on Fed decision")
        XCTAssertNil(results[0].image)
    }

    func testFetchGeneralNews_incrementsCallCount() async throws {
        _ = try await mock.fetchGeneralNews(category: "general")
        _ = try await mock.fetchGeneralNews(category: "forex")

        XCTAssertEqual(mock.fetchGeneralNewsCallCount, 2)
    }

    // MARK: - Error Handling

    func testShouldThrow_triggersHTTPError() async {
        mock.shouldThrow = true

        do {
            _ = try await mock.fetchRecommendationTrends(ticker: "AAPL")
            XCTFail("Expected FinnhubError to be thrown")
        } catch FinnhubError.httpError(statusCode: let code) {
            XCTAssertEqual(code, 403)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testShouldThrow_affectsBothMethods() async {
        mock.shouldThrow = true

        do {
            _ = try await mock.fetchPriceTarget(ticker: "AAPL")
            XCTFail("Expected FinnhubError to be thrown")
        } catch FinnhubError.httpError(statusCode: let code) {
            XCTAssertEqual(code, 403)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(mock.fetchPriceTargetCallCount, 1,
                       "Call count should increment even when throwing")
    }

    func testShouldThrow_affectsAllNewEndpoints() async {
        mock.shouldThrow = true

        do { _ = try await mock.fetchCompanyProfile(ticker: "AAPL") } catch {}
        do { _ = try await mock.fetchQuote(ticker: "AAPL") } catch {}
        do { _ = try await mock.fetchBasicFinancials(ticker: "AAPL") } catch {}
        do { _ = try await mock.fetchPeers(ticker: "AAPL") } catch {}
        do { _ = try await mock.fetchEarnings(ticker: "AAPL") } catch {}
        do { _ = try await mock.fetchInsiderTransactions(ticker: "AAPL") } catch {}
        do { _ = try await mock.fetchInsiderSentiment(ticker: "AAPL", from: "2026-01-01", to: "2026-03-01") } catch {}
        do { _ = try await mock.fetchEarningsCalendar(from: "2026-04-01", to: "2026-04-30") } catch {}
        do { _ = try await mock.fetchCompanyNews(ticker: "AAPL", from: "2026-03-01", to: "2026-03-13") } catch {}
        do { _ = try await mock.fetchGeneralNews(category: "general") } catch {}

        XCTAssertEqual(mock.fetchCompanyProfileCallCount, 1)
        XCTAssertEqual(mock.fetchQuoteCallCount, 1)
        XCTAssertEqual(mock.fetchBasicFinancialsCallCount, 1)
        XCTAssertEqual(mock.fetchPeersCallCount, 1)
        XCTAssertEqual(mock.fetchEarningsCallCount, 1)
        XCTAssertEqual(mock.fetchInsiderTransactionsCallCount, 1)
        XCTAssertEqual(mock.fetchInsiderSentimentCallCount, 1)
        XCTAssertEqual(mock.fetchEarningsCalendarCallCount, 1)
        XCTAssertEqual(mock.fetchCompanyNewsCallCount, 1)
        XCTAssertEqual(mock.fetchGeneralNewsCallCount, 1)
    }

    // MARK: - Call Counts Start at Zero

    func testCallCountsStartAtZero() {
        XCTAssertEqual(mock.fetchRecommendationCallCount, 0)
        XCTAssertEqual(mock.fetchPriceTargetCallCount, 0)
        XCTAssertEqual(mock.fetchCompanyProfileCallCount, 0)
        XCTAssertEqual(mock.fetchQuoteCallCount, 0)
        XCTAssertEqual(mock.fetchBasicFinancialsCallCount, 0)
        XCTAssertEqual(mock.fetchPeersCallCount, 0)
        XCTAssertEqual(mock.fetchEarningsCallCount, 0)
        XCTAssertEqual(mock.fetchInsiderTransactionsCallCount, 0)
        XCTAssertEqual(mock.fetchInsiderSentimentCallCount, 0)
        XCTAssertEqual(mock.fetchEarningsCalendarCallCount, 0)
        XCTAssertEqual(mock.fetchCompanyNewsCallCount, 0)
        XCTAssertEqual(mock.fetchGeneralNewsCallCount, 0)
    }
}
