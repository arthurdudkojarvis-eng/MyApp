import Foundation

// MARK: - Protocol (enables mocking in tests)

protocol PolygonFetching: Sendable {
    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> PolygonTickerDetails
    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal?
    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [PolygonDividend]
    func fetchTickerSearch(query: String, apiKey: String) async throws -> [PolygonTickerSearchResult]
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

// MARK: - Aggregates (Price)

struct PolygonAggregatesResponse: Decodable {
    let results: [PolygonBar]?
}

struct PolygonBar: Decodable {
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

// MARK: - Errors

enum PolygonError: Error, LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:     return "Polygon.io API key is not configured."
        case .httpError(let c):  return "Polygon.io returned HTTP \(c)."
        case .emptyResponse:     return "Polygon.io returned no results."
        }
    }
}
