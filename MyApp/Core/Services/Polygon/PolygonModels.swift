import Foundation

// MARK: - Protocol (enables mocking in tests)

protocol PolygonFetching: Sendable {
    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> PolygonTickerDetails
    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal?
    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [PolygonDividend]
    func fetchTickerSearch(query: String, apiKey: String) async throws -> [PolygonTickerSearchResult]
    func fetchNews(tickers: [String], limit: Int, apiKey: String) async throws -> [PolygonNewsArticle]
}

// MARK: - Ticker Details

struct PolygonTickerDetailsResponse: Decodable {
    let results: PolygonTickerDetails
}

struct PolygonTickerDetails: Decodable {
    let ticker: String
    let name: String
    let sicDescription: String?   // maps to sector
    let marketCap: Decimal?       // may be absent for small/unlisted tickers
    let description: String?      // company description
}

// MARK: - Ticker Search

struct PolygonTickerSearchResponse: Decodable {
    let results: [PolygonTickerSearchResult]?
}

struct PolygonTickerSearchResult: Decodable, Identifiable {
    let ticker: String
    let name: String
    let market: String?
    let type: String?
    let primaryExchange: String?

    var id: String { ticker }
}

// MARK: - Snapshot (Price)

struct PolygonSnapshotResponse: Decodable {
    let ticker: PolygonSnapshotTicker
}

struct PolygonSnapshotTicker: Decodable {
    let day: PolygonSnapshotBar?
    let prevDay: PolygonSnapshotBar?
}

struct PolygonSnapshotBar: Decodable {
    let c: Decimal   // close price — decoded as Decimal to avoid Double precision loss
}

// MARK: - Dividends

struct PolygonDividendsResponse: Decodable {
    let results: [PolygonDividend]?
}

struct PolygonDividend: Decodable {
    let ticker: String
    let cashAmount: Decimal
    let exDividendDate: String          // "YYYY-MM-DD"
    let payDate: String?
    let declarationDate: String?
    let frequency: Int?                 // 1, 2, 4, 12
    let dividendType: String            // "CD" = regular, "SC" = special cash
}

// MARK: - News

struct PolygonNewsResponse: Decodable {
    let results: [PolygonNewsArticle]?
}

struct PolygonNewsArticle: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let publishedUtc: String        // ISO-8601
    let articleUrl: String
    let author: String?
    let tickers: [String]?
    let imageUrl: String?
}

// MARK: - Errors

enum PolygonError: Error, LocalizedError {
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
