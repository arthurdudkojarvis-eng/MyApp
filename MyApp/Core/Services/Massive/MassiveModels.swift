import Foundation

// MARK: - Protocol (enables mocking in tests)

protocol MassiveFetching: Sendable {
    // Existing methods
    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> MassiveTickerDetails
    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal?
    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [MassiveDividend]
    func fetchTickerSearch(query: String, apiKey: String) async throws -> [MassiveTickerSearchResult]
    func fetchNews(tickers: [String], limit: Int, apiKey: String) async throws -> [MassiveNewsArticle]

    // STORY-022: New endpoint methods
    func fetchFinancials(ticker: String, limit: Int, apiKey: String) async throws -> [MassiveFinancial]
    func fetchAggregates(ticker: String, from: String, to: String, apiKey: String) async throws -> [MassiveAggregate]
    func fetchSplits(ticker: String, apiKey: String) async throws -> [MassiveSplit]
    func fetchGroupedDaily(date: String, apiKey: String) async throws -> [MassiveGroupedBar]
    func fetchMarketStatus(apiKey: String) async throws -> MassiveMarketStatus
    func fetchMarketHolidays(apiKey: String) async throws -> [MassiveMarketHoliday]
    func fetchRelatedCompanies(ticker: String, apiKey: String) async throws -> [String]
    func fetchTechnicalIndicator(type: MassiveIndicatorType, ticker: String, apiKey: String) async throws -> [MassiveIndicatorValue]
    func fetchPreviousCloseBar(ticker: String, apiKey: String) async throws -> MassiveAggregate?
}

// MARK: - Ticker Details

struct MassiveTickerDetailsResponse: Decodable {
    let results: MassiveTickerDetails
}

struct MassiveTickerDetails: Decodable {
    let ticker: String
    let name: String
    let sicDescription: String?   // maps to sector
    let marketCap: Decimal?       // may be absent for small/unlisted tickers
    let description: String?      // company description
}

// MARK: - Ticker Search

struct MassiveTickerSearchResponse: Decodable {
    let results: [MassiveTickerSearchResult]?
}

struct MassiveTickerSearchResult: Decodable, Identifiable {
    let ticker: String
    let name: String
    let market: String?
    let type: String?
    let primaryExchange: String?

    var id: String { ticker }
}

// MARK: - Snapshot (Price)

struct MassiveSnapshotResponse: Decodable {
    /// Nil when the ticker is not found (API returns {"ticker": null, "status": "OK"}).
    let ticker: MassiveTickerSnapshot?
}

struct MassiveTickerSnapshot: Decodable {
    let day: MassiveSnapshotBar?
    let prevDay: MassiveSnapshotBar?
}

struct MassiveSnapshotBar: Decodable {
    let c: Decimal   // close price — decoded as Decimal to avoid Double precision loss
}

// MARK: - Dividends

struct MassiveDividendsResponse: Decodable {
    let results: [MassiveDividend]?
}

struct MassiveDividend: Decodable {
    let ticker: String
    let cashAmount: Decimal
    let exDividendDate: String          // "YYYY-MM-DD"
    let payDate: String?
    let declarationDate: String?
    let frequency: Int?                 // 1, 2, 4, 12
    let dividendType: String            // "CD" = regular, "SC" = special cash
}

// MARK: - News

struct MassiveNewsResponse: Decodable {
    let results: [MassiveNewsArticle]?
}

struct MassiveNewsArticle: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let publishedUtc: String        // ISO-8601
    let articleUrl: String
    let author: String?
    let tickers: [String]?
    let imageUrl: String?
}

// MARK: - Financials (STORY-022)
// Endpoint: /vX/reference/financials?ticker=AAPL&limit=1
// Key fields nested under financials[].financials.income_statement

struct MassiveFinancialsResponse: Decodable {
    let results: [MassiveFinancialResult]?
}

/// Top-level result wrapper returned by /vX/reference/financials.
struct MassiveFinancialResult: Decodable {
    let fiscalPeriod: String?   // e.g. "Q3", "FY"
    let fiscalYear: String?     // e.g. "2024"
    let financials: MassiveFinancialStatements?
}

struct MassiveFinancialStatements: Decodable {
    let incomeStatement: MassiveIncomeStatement?
}

struct MassiveIncomeStatement: Decodable {
    let revenues: MassiveFinancialItem?
    let netIncomeLoss: MassiveFinancialItem?
    let basicEarningsPerShare: MassiveFinancialItem?
    let dilutedEarningsPerShare: MassiveFinancialItem?
    let operatingIncomeLoss: MassiveFinancialItem?
}

struct MassiveFinancialItem: Decodable {
    let value: Decimal?
    let unit: String?           // "USD", "USD / shares"
}

/// Flattened view of a single fiscal period's key income statement figures.
struct MassiveFinancial {
    let fiscalPeriod: String?
    let fiscalYear: String?
    let revenues: Decimal?
    let netIncomeLoss: Decimal?
    let basicEarningsPerShare: Decimal?
    let dilutedEarningsPerShare: Decimal?
    let operatingIncomeLoss: Decimal?

    init(result: MassiveFinancialResult) {
        self.fiscalPeriod             = result.fiscalPeriod
        self.fiscalYear               = result.fiscalYear
        let stmt                      = result.financials?.incomeStatement
        self.revenues                 = stmt?.revenues?.value
        self.netIncomeLoss            = stmt?.netIncomeLoss?.value
        self.basicEarningsPerShare    = stmt?.basicEarningsPerShare?.value
        self.dilutedEarningsPerShare  = stmt?.dilutedEarningsPerShare?.value
        self.operatingIncomeLoss      = stmt?.operatingIncomeLoss?.value
    }
}

// MARK: - Aggregates / Historical Prices (STORY-022)
// Endpoint: /v2/aggs/ticker/{ticker}/range/1/day/{from}/{to}

struct MassiveAggregatesResponse: Decodable {
    let results: [MassiveAggregate]?
}

struct MassiveAggregate: Decodable {
    let o: Decimal      // open
    let h: Decimal      // high
    let l: Decimal      // low
    let c: Decimal      // close
    let v: Decimal      // volume
    let vw: Decimal?    // volume-weighted average price
    let t: Int          // Unix timestamp in milliseconds
    let n: Int?         // number of transactions
}

// MARK: - Stock Splits (STORY-022)
// Endpoint: /v3/reference/splits?ticker=AAPL

struct MassiveSplitsResponse: Decodable {
    let results: [MassiveSplit]?
}

struct MassiveSplit: Decodable {
    let executionDate: String   // "YYYY-MM-DD"
    let splitFrom: Decimal      // denominator — e.g. 1 in a 4-for-1 split
    let splitTo: Decimal        // numerator   — e.g. 4 in a 4-for-1 split
}

// MARK: - Grouped Daily (STORY-022)
// Endpoint: /v2/aggs/grouped/locale/us/market/stocks/{date}
// Note: ticker field uses uppercase "T" in the API response — custom CodingKeys required.

struct MassiveGroupedDailyResponse: Decodable {
    let results: [MassiveGroupedBar]?
}

struct MassiveGroupedBar: Decodable {
    let T: String       // ticker symbol — uppercase key in API response
    let o: Decimal      // open
    let h: Decimal      // high
    let l: Decimal      // low
    let c: Decimal      // close
    let v: Decimal      // volume
    let vw: Decimal?    // volume-weighted average price
    let t: Int          // Unix timestamp in milliseconds
    let n: Int?         // number of transactions

    /// Convenience accessor matching the rest of the codebase's lowercase convention.
    var ticker: String { T }
}

// MARK: - Market Status (STORY-022)
// Endpoint: /v1/marketstatus/now

struct MassiveMarketStatus: Decodable {
    /// "open", "closed", "extended-hours"
    let market: String
    let serverTime: String      // ISO-8601
}

// MARK: - Market Holidays (STORY-022)
// Endpoint: /v1/marketstatus/upcoming
// The API returns a top-level array (no "results" wrapper).

struct MassiveMarketHoliday: Decodable {
    let name: String
    let date: String            // "YYYY-MM-DD"
    /// "closed" or "early-close"
    let status: String
}

// MARK: - Related Companies (STORY-022)
// Endpoint: /v1/related-companies/{ticker}

struct MassiveRelatedCompaniesResponse: Decodable {
    let results: [MassiveRelatedCompany]?
}

struct MassiveRelatedCompany: Decodable {
    let ticker: String
}

// MARK: - Technical Indicators (STORY-022)
// Endpoints: /v1/indicators/{sma|ema|rsi|macd}/{ticker}

/// Supported technical indicator types. The raw value maps to the URL path segment.
enum MassiveIndicatorType: String, Sendable {
    case sma  = "sma"
    case ema  = "ema"
    case rsi  = "rsi"
    case macd = "macd"
}

struct MassiveTechnicalResponse: Decodable {
    let results: MassiveTechnicalResults?
}

struct MassiveTechnicalResults: Decodable {
    let values: [MassiveIndicatorValue]?
}

/// A single data point from a technical indicator endpoint.
/// `signal` and `histogram` are only populated for MACD responses.
struct MassiveIndicatorValue: Decodable {
    let timestamp: Int      // Unix ms
    let value: Decimal
    let signal: Decimal?    // MACD signal line
    let histogram: Decimal? // MACD histogram
}

// MARK: - Errors

enum MassiveError: Error, LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:     return "API key is not configured."
        case .httpError(let c):  return "API returned HTTP \(c)."
        case .emptyResponse:     return "API returned no results."
        }
    }
}
