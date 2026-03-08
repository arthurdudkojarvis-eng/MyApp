import Foundation

struct MassiveService: MassiveFetching {
    /// Worker proxy URL. Replace with your deployed Cloudflare Worker URL.
    static let baseURL = "https://myapp-api-proxy.arthurdudko.workers.dev"

    /// Shared secret the worker validates via X-App-Token header.
    /// Set this to the same UUID you stored in `npx wrangler secret put APP_TOKEN`.
    private static let appToken = "F604F620-65D7-493E-BF22-44C35C2B5E86"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Characters permitted unencoded in a ticker path segment.
    private static let tickerAllowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: ".-"))

    // MARK: - Ticker Details

    func fetchTickerDetails(ticker: String) async throws -> MassiveTickerDetails {
        let encoded = try percentEncode(ticker: ticker)
        let url = try buildURL(path: "/v3/reference/tickers/\(encoded)")
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveTickerDetailsResponse.self, from: data)
        return response.results
    }

    // MARK: - Snapshot (current delayed price)

    func fetchPreviousClose(ticker: String) async throws -> Decimal? {
        let encoded = try percentEncode(ticker: ticker)
        let url = try buildURL(
            path: "/v2/snapshot/locale/us/markets/stocks/tickers/\(encoded)"
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

    func fetchDividends(ticker: String, limit: Int) async throws -> [MassiveDividend] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/reference/dividends") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "order", value: "desc")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveDividendsResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Ticker Search

    func fetchTickerSearch(query: String, market: String) async throws -> [MassiveTickerSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        // Two parallel calls: ticker prefix match + text search.
        // The text-only `search` parameter often misses exact ticker matches,
        // so we add a prefix query using ticker.gte / ticker.lt comparison operators.
        //
        // Prefix matching only works for stocks — crypto tickers use the "X:BTCUSD"
        // format which doesn't match alphanumeric prefix ranges.
        let upper = trimmed.uppercased()
        let useTickerPrefix = market == "stocks"

        // The text search is the primary path — errors must propagate so the UI
        // can show a meaningful message instead of an empty "no results" state.
        guard var searchComponents = URLComponents(string: "\(Self.baseURL)/v3/reference/tickers") else {
            throw URLError(.badURL)
        }
        searchComponents.queryItems = [
            URLQueryItem(name: "search", value: trimmed),
            URLQueryItem(name: "market", value: market),
            URLQueryItem(name: "active", value: "true"),
            URLQueryItem(name: "limit", value: "10")
        ]
        guard let searchURL = searchComponents.url else { throw URLError(.badURL) }

        // Ticker prefix match (stocks only) runs in parallel but fails gracefully.
        async let byTicker: [MassiveTickerSearchResult] = {
            guard useTickerPrefix else { return [] }
            guard var c = URLComponents(string: "\(Self.baseURL)/v3/reference/tickers") else { return [] }
            c.queryItems = [
                URLQueryItem(name: "ticker.gte", value: upper),
                URLQueryItem(name: "ticker.lt", value: Self.nextPrefix(upper)),
                URLQueryItem(name: "market", value: market),
                URLQueryItem(name: "active", value: "true"),
                URLQueryItem(name: "order", value: "asc"),
                URLQueryItem(name: "sort", value: "ticker"),
                URLQueryItem(name: "limit", value: "10")
            ]
            guard let url = c.url else { return [] }
            guard let data = try? await fetch(url: url) else { return [] }
            return (try? Self.decoder.decode(MassiveTickerSearchResponse.self, from: data))?.results ?? []
        }()

        // Text search — propagate errors (throws on HTTP 403, network failure, etc.)
        async let bySearch: [MassiveTickerSearchResult] = {
            let data = try await fetch(url: searchURL)
            return (try? Self.decoder.decode(MassiveTickerSearchResponse.self, from: data))?.results ?? []
        }()

        let (tickerResults, searchResults) = try await (byTicker, bySearch)

        // Merge: ticker prefix matches first, then text search (deduped).
        var seen = Set<String>()
        var merged: [MassiveTickerSearchResult] = []
        for result in tickerResults + searchResults {
            if seen.insert(result.ticker).inserted {
                merged.append(result)
            }
        }
        return merged
    }

    /// Returns the next string after `prefix` for use as an exclusive upper bound.
    /// e.g. "AAPL" → "AAPM", "AA" → "AB"
    private static func nextPrefix(_ prefix: String) -> String {
        guard !prefix.isEmpty else { return "" }
        var chars = Array(prefix)
        // Increment the last character.
        chars[chars.count - 1] = Character(UnicodeScalar(chars.last!.asciiValue! + 1))
        return String(chars)
    }

    // MARK: - News

    func fetchNews(tickers: [String], limit: Int) async throws -> [MassiveNewsArticle] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v2/reference/news") else {
            throw URLError(.badURL)
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "order", value: "desc")
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

    func fetchFinancials(ticker: String, limit: Int) async throws -> [MassiveFinancial] {
        guard var components = URLComponents(string: "\(Self.baseURL)/vX/reference/financials") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveFinancialsResponse.self, from: data)
        return (response.results ?? []).map { MassiveFinancial(result: $0) }
    }

    // MARK: - Aggregates / Historical Prices (STORY-023)
    // /v2/aggs/ticker/{ticker}/range/1/day/{from}/{to}
    // Default: adjusted=true, limit=90 bars.

    func fetchAggregates(ticker: String, from: String, to: String) async throws -> [MassiveAggregate] {
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
            URLQueryItem(name: "limit", value: "90")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveAggregatesResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Stock Splits (STORY-023)
    // /v3/reference/splits?ticker=AAPL

    func fetchSplits(ticker: String) async throws -> [MassiveSplit] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/reference/splits") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "ticker", value: ticker),
            URLQueryItem(name: "order", value: "desc")
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

    func fetchGroupedDaily(date: String) async throws -> [MassiveGroupedBar] {
        try validateDateParam(date)
        guard var components = URLComponents(
            string: "\(Self.baseURL)/v2/aggs/grouped/locale/us/market/stocks/\(date)"
        ) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "adjusted", value: "true")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveGroupedDailyResponse.self, from: data)
        return response.results ?? []
    }

    // MARK: - Market Status (STORY-023)
    // /v1/marketstatus/now

    func fetchMarketStatus() async throws -> MassiveMarketStatus {
        let url = try buildURL(path: "/v1/marketstatus/now")
        let data = try await fetch(url: url)
        return try Self.decoder.decode(MassiveMarketStatus.self, from: data)
    }

    // MARK: - Market Holidays (STORY-023)
    // /v1/marketstatus/upcoming
    // Response is a top-level JSON array — no "results" wrapper.

    func fetchMarketHolidays() async throws -> [MassiveMarketHoliday] {
        let url = try buildURL(path: "/v1/marketstatus/upcoming")
        let data = try await fetch(url: url)
        return try Self.decoder.decode([MassiveMarketHoliday].self, from: data)
    }

    // MARK: - Related Companies (STORY-023)
    // /v1/related-companies/{ticker}

    func fetchRelatedCompanies(ticker: String) async throws -> [String] {
        let encoded = try percentEncode(ticker: ticker)
        let url = try buildURL(path: "/v1/related-companies/\(encoded)")
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveRelatedCompaniesResponse.self, from: data)
        return (response.results ?? []).map(\.ticker)
    }

    // MARK: - Technical Indicators (STORY-023)
    // /v1/indicators/{sma|ema|rsi|macd}/{ticker}

    func fetchTechnicalIndicator(
        type: MassiveIndicatorType,
        ticker: String
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
            URLQueryItem(name: "order", value: "desc")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveTechnicalResponse.self, from: data)
        return response.results?.values ?? []
    }

    // MARK: - Previous Close Bar (STORY-023)
    // Lightweight alternative to the full snapshot: /v2/aggs/ticker/{ticker}/prev
    // Returns a single aggregate bar for the most recent completed trading day.

    func fetchPreviousCloseBar(ticker: String) async throws -> MassiveAggregate? {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(
            string: "\(Self.baseURL)/v2/aggs/ticker/\(encoded)/prev"
        ) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "adjusted", value: "true")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(MassiveAggregatesResponse.self, from: data)
        return response.results?.first
    }

    // MARK: - Branding Image

    /// Rewrites an absolute Massive/Polygon branding URL to go through our proxy worker.
    /// Returns nil for URLs that don't belong to a known branding host.
    static func proxiedBrandingURL(from absoluteURL: String) -> URL? {
        guard let original = URL(string: absoluteURL),
              let host = original.host,
              host.contains("polygon") || host.contains("massive")
        else { return nil }
        return URL(string: "\(baseURL)\(original.path)")
    }

    func fetchImageData(from url: URL) async throws -> Data {
        try await fetch(url: url)
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

    private func buildURL(path: String) throws -> URL {
        guard let components = URLComponents(string: "\(Self.baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    private func fetch(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.appToken, forHTTPHeaderField: "X-App-Token")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw MassiveError.httpError(statusCode: http.statusCode)
        }
        return data
    }
}
