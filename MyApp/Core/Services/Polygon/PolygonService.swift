import Foundation

struct PolygonService: PolygonFetching {
    private static let baseURL = "https://api.polygon.io"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Characters permitted unencoded in a ticker path segment.
    private static let tickerAllowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: ".-"))

    // MARK: - Ticker Details

    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> PolygonTickerDetails {
        let encoded = try percentEncode(ticker: ticker)
        let url = try buildURL(path: "/v3/reference/tickers/\(encoded)", apiKey: apiKey)
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(PolygonTickerDetailsResponse.self, from: data)
        return response.results
    }

    // MARK: - Previous Close

    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal? {
        let encoded = try percentEncode(ticker: ticker)
        let url = try buildURL(path: "/v2/aggs/ticker/\(encoded)/prev", apiKey: apiKey)
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(PolygonAggregatesResponse.self, from: data)
        // c is already Decimal — no Double conversion needed
        return response.results?.first?.c
    }

    // MARK: - Dividends

    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [PolygonDividend] {
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
        let response = try Self.decoder.decode(PolygonDividendsResponse.self, from: data)
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
            throw PolygonError.httpError(statusCode: http.statusCode)
        }
        return data
    }
}
