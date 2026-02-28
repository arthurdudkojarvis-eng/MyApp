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

    // MARK: - Helpers

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
