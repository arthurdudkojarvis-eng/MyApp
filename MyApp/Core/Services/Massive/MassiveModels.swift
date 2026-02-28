import Foundation

// MARK: - Protocol (enables mocking in tests)

protocol MassiveFetching: Sendable {
    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> MassiveTickerDetails
    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal?
    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [MassiveDividend]
    func fetchTickerSearch(query: String, apiKey: String) async throws -> [MassiveTickerSearchResult]
    func fetchNews(tickers: [String], limit: Int, apiKey: String) async throws -> [MassiveNewsArticle]
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
