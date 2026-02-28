import Foundation

struct MassiveService: MassiveFetching {
    private static let baseURL = "https://api.massive.com"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Characters permitted unencoded in a ticker path segment.
    private static let tickerAllowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: ".-"))

    // MARK: - Ticker Details

    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> MassiveTickerDetails {
        let encoded = try percentEncode(ticker: ticker)
        let url = try buildURL(path: "/v3/reference/tickers/\(encoded)", apiKey: apiKey)
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveTickerDetailsResponse.self, from: data)
        return response.results
    }

    // MARK: - Snapshot (current delayed price)

    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal? {
        let encoded = try percentEncode(ticker: ticker)
        let url = try buildURL(
            path: "/v2/snapshot/locale/us/markets/stocks/tickers/\(encoded)",
            apiKey: apiKey
        )
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveSnapshotResponse.self, from: data)
        guard let snapshot = response.ticker else { return nil }
        // Prefer today's intraday close. The API sends day.c = 0 when the market
        // hasn't opened yet (pre-market / weekend), so fall back to prevDay in that case.
        if let dayClose = snapshot.day?.c, dayClose > 0 {
            return dayClose
        }
        return snapshot.prevDay?.c
    }

    // MARK: - Dividends

    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [MassiveDividend] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/reference/dividends") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveDividendsResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Ticker Search

    func fetchTickerSearch(query: String, apiKey: String) async throws -> [MassiveTickerSearchResult] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/reference/tickers") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "market", value: "stocks"),
            URLQueryItem(name: "active", value: "true"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveTickerSearchResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - News

    func fetchNews(tickers: [String], limit: Int, apiKey: String) async throws -> [MassiveNewsArticle] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v2/reference/news") else {
            throw URLError(.badURL)
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        // Pass the first ticker for more relevant results; omit for general market news.
        if let first = tickers.first {
            queryItems.append(URLQueryItem(name: "ticker", value: first))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveNewsResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Financials (STORY-023)
    // /vX/reference/financials?ticker=AAPL&limit=1
    // Uses a custom decoder because the financial data nesting requires
    // convertFromSnakeCase to reach income_statement sub-keys.

    func fetchFinancials(ticker: String, limit: Int, apiKey: String) async throws -> [MassiveFinancial] {
        guard var components = URLComponents(string: "\(Self.baseURL)/vX/reference/financials") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveFinancialsResponse.self, from: data)
        return (response.results ?? []).map { MassiveFinancial(result: $0) }
    }

    // MARK: - Aggregates / Historical Prices (STORY-023)
    // /v2/aggs/ticker/{ticker}/range/1/day/{from}/{to}
    // Default: adjusted=true, limit=90 bars.

    func fetchAggregates(ticker: String, from: String, to: String, apiKey: String) async throws -> [MassiveAggregate] {
        let encoded = try percentEncode(ticker: ticker)
        try validateDateParam(from)
        try validateDateParam(to)
        guard var components = URLComponents(
            string: "\(Self.baseURL)/v2/aggs/ticker/\(encoded)/range/1/day/\(from)/\(to)"
        ) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "adjusted", value: "true"),
            URLQueryItem(name: "sort", value: "asc"),
            URLQueryItem(name: "limit", value: "90"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveAggregatesResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Stock Splits (STORY-023)
    // /v3/reference/splits?ticker=AAPL

    func fetchSplits(ticker: String, apiKey: String) async throws -> [MassiveSplit] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/reference/splits") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveSplitsResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Grouped Daily (STORY-023)
    // /v2/aggs/grouped/locale/us/market/stocks/{date}
    // Note: MassiveGroupedBar uses uppercase "T" for ticker — the JSON decoder's
    // convertFromSnakeCase does NOT alter single-character uppercase keys, so "T" decodes
    // correctly into the `T` property without a custom CodingKeys definition.

    func fetchGroupedDaily(date: String, apiKey: String) async throws -> [MassiveGroupedBar] {
        try validateDateParam(date)
        guard var components = URLComponents(
            string: "\(Self.baseURL)/v2/aggs/grouped/locale/us/market/stocks/\(date)"
        ) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "adjusted", value: "true"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveGroupedDailyResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Market Status (STORY-023)
    // /v1/marketstatus/now

    func fetchMarketStatus(apiKey: String) async throws -> MassiveMarketStatus {
        let url = try buildURL(path: "/v1/marketstatus/now", apiKey: apiKey)
        let data = try await fetch(url: url)
        return try Self.decoder.decode(MassiveMarketStatus.self, from: data)
    }

    // MARK: - Market Holidays (STORY-023)
    // /v1/marketstatus/upcoming
    // Response is a top-level JSON array — no "results" wrapper.

    func fetchMarketHolidays(apiKey: String) async throws -> [MassiveMarketHoliday] {
        let url = try buildURL(path: "/v1/marketstatus/upcoming", apiKey: apiKey)
        let data = try await fetch(url: url)
        return try Self.decoder.decode([MassiveMarketHoliday].self, from: data)
    }

    // MARK: - Related Companies (STORY-023)
    // /v1/related-companies/{ticker}

    func fetchRelatedCompanies(ticker: String, apiKey: String) async throws -> [String] {
        let encoded = try percentEncode(ticker: ticker)
        let url = try buildURL(path: "/v1/related-companies/\(encoded)", apiKey: apiKey)
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveRelatedCompaniesResponse.self, from: data)
        return (response.results ?? []).map(\.ticker)
    }

    // MARK: - Technical Indicators (STORY-023)
    // /v1/indicators/{sma|ema|rsi|macd}/{ticker}

    func fetchTechnicalIndicator(
        type: MassiveIndicatorType,
        ticker: String,
        apiKey: String
    ) async throws -> [MassiveIndicatorValue] {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(
            string: "\(Self.baseURL)/v1/indicators/\(type.rawValue)/\(encoded)"
        ) else {
            throw URLError(.badURL)
        }
        // Default window sizes that suit the dividend-investor use case.
        // SMA/EMA use 20-day; RSI uses 14-day; MACD uses standard 12/26/9.
        let windowSize: String
        switch type {
        case .sma:  windowSize = "20"
        case .ema:  windowSize = "20"
        case .rsi:  windowSize = "14"
        case .macd: windowSize = "12"   // fast period; slow=26 and signal=9 are API defaults
        }
        components.queryItems = [
            URLQueryItem(name: "timespan", value: "day"),
            URLQueryItem(name: "adjusted", value: "true"),
            URLQueryItem(name: "window", value: windowSize),
            URLQueryItem(name: "series_type", value: "close"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveTechnicalResponse.self, from: data)
        return response.results?.values ?? []
    }

    // MARK: - Previous Close Bar (STORY-023)
    // Lightweight alternative to the full snapshot: /v2/aggs/ticker/{ticker}/prev
    // Returns a single aggregate bar for the most recent completed trading day.

    func fetchPreviousCloseBar(ticker: String, apiKey: String) async throws -> MassiveAggregate? {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(
            string: "\(Self.baseURL)/v2/aggs/ticker/\(encoded)/prev"
        ) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "adjusted", value: "true"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveAggregatesResponse.self, from: data)
        return response.results?.first
    }

    // MARK: - Helpers

    /// Validates that a date string matches the expected `yyyy-MM-dd` format.
    /// Rejects anything that could alter the URL path structure (e.g. `/`, `..`).
    private func validateDateParam(_ date: String) throws {
        guard date.count == 10,
              date.allSatisfy({ $0.isNumber || $0 == "-" }),
              date.filter({ $0 == "-" }).count == 2
        else { throw URLError(.badURL) }
    }

    /// Percent-encodes `ticker` so only alphanumerics, `.`, and `-` remain unencoded.
    /// Rejects anything that would alter the URL path structure (e.g. `/`, `..`, `%`).
    /// Maximum ticker length is 12 characters (covers all major exchange formats).
    private func percentEncode(ticker: String) throws -> String {
        guard !ticker.isEmpty, ticker.count <= 12 else { throw URLError(.badURL) }
        guard let encoded = ticker.addingPercentEncoding(withAllowedCharacters: Self.tickerAllowed) else {
            throw URLError(.badURL)
        }
        return encoded
    }

    private func buildURL(path: String, apiKey: String) throws -> URL {
        guard var components = URLComponents(string: "\(Self.baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "apiKey", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    private func fetch(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw MassiveError.httpError(statusCode: http.statusCode)
        }
        return data
    }
}
