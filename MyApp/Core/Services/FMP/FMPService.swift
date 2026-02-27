import Foundation

// MARK: - FMPService
// Implements PolygonFetching using the Financial Modeling Prep (FMP) stable API.
// All responses are mapped to the existing Polygon model types so the rest
// of the app continues to work without any structural changes.
//
// Stable API base: https://financialmodelingprep.com/stable/
// (v3 endpoints are legacy and unavailable for accounts created after Aug 2025)

struct FMPService: PolygonFetching {
    private static let baseURL = "https://financialmodelingprep.com/stable"

    private static let decoder = JSONDecoder()

    private static let tickerAllowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: ".-"))

    // MARK: - Ticker Search

    func fetchTickerSearch(query: String, apiKey: String) async throws -> [PolygonTickerSearchResult] {
        guard var components = URLComponents(string: "\(Self.baseURL)/search-symbol") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "query",  value: query),
            URLQueryItem(name: "limit",  value: "20"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let results = try Self.decoder.decode([FMPSearchResult].self, from: data)
        return results.map {
            PolygonTickerSearchResult(
                ticker:          $0.symbol,
                name:            $0.name,
                market:          "stocks",
                type:            nil,
                primaryExchange: $0.exchange
            )
        }
    }

    // MARK: - Ticker Details

    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> PolygonTickerDetails {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(string: "\(Self.baseURL)/profile") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: encoded),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let results = try Self.decoder.decode([FMPProfile].self, from: data)
        guard let profile = results.first else { throw PolygonError.emptyResponse }
        return PolygonTickerDetails(
            ticker:         profile.symbol,
            name:           profile.companyName,
            sicDescription: profile.sector,
            marketCap:      profile.marketCap,
            description:    profile.description
        )
    }

    // MARK: - Price

    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal? {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(string: "\(Self.baseURL)/quote") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: encoded),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let results = try Self.decoder.decode([FMPQuote].self, from: data)
        return results.first?.price
    }

    // MARK: - Dividends

    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [PolygonDividend] {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(string: "\(Self.baseURL)/dividends") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: encoded),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let dividends = try Self.decoder.decode([FMPDividend].self, from: data)

        return dividends.prefix(limit).map { div in
            PolygonDividend(
                ticker:          ticker.uppercased(),
                cashAmount:      div.dividend,
                exDividendDate:  div.date,
                payDate:         div.paymentDate,
                declarationDate: div.declarationDate,
                frequency:       frequencyInt(from: div.frequency),
                dividendType:    "CD"
            )
        }
    }

    // MARK: - News
    // The stable news endpoint is restricted on the free FMP tier.
    // Return an empty array silently so the rest of the app is unaffected.

    func fetchNews(tickers: [String], limit: Int, apiKey: String) async throws -> [PolygonNewsArticle] {
        guard var components = URLComponents(string: "\(Self.baseURL)/news/stock") else {
            throw URLError(.badURL)
        }
        let validTickers = tickers.compactMap { try? percentEncode(ticker: $0) }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit",  value: "\(limit)"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        if !validTickers.isEmpty {
            queryItems.append(URLQueryItem(name: "symbols", value: validTickers.joined(separator: ",")))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        // Gracefully return empty on restricted endpoint (free tier returns a plain
        // error string rather than a JSON array, so decode failure → empty list).
        guard let articles = try? Self.decoder.decode([FMPNewsArticle].self, from: data) else {
            return []
        }
        return articles.map { article in
            PolygonNewsArticle(
                id:           article.url,
                title:        article.title,
                description:  article.text.map { String($0.prefix(300)) },
                publishedUtc: isoDateString(from: article.publishedDate),
                articleUrl:   article.url,
                author:       article.site,
                tickers:      article.symbols,
                imageUrl:     article.image
            )
        }
    }

    // MARK: - Helpers

    private func percentEncode(ticker: String) throws -> String {
        guard !ticker.isEmpty, ticker.count <= 12 else { throw URLError(.badURL) }
        guard let encoded = ticker.addingPercentEncoding(withAllowedCharacters: Self.tickerAllowed) else {
            throw URLError(.badURL)
        }
        return encoded
    }

    private func fetch(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PolygonError.httpError(statusCode: http.statusCode)
        }
        return data
    }

    /// Converts FMP's frequency string to the Int used by PolygonDividend / DividendFrequency.
    private func frequencyInt(from string: String?) -> Int {
        switch string?.lowercased() {
        case "monthly":                   return 12
        case "quarterly":                 return 4
        case "semi-annual", "biannual":   return 2
        case "annual", "annually":        return 1
        default:                          return 4  // fall back to quarterly
        }
    }

    /// Converts FMP's "YYYY-MM-DD HH:mm:ss" to ISO-8601 "YYYY-MM-DDTHH:mm:ssZ".
    private func isoDateString(from fmpDate: String) -> String {
        if fmpDate.contains(" ") {
            return fmpDate.replacingOccurrences(of: " ", with: "T") + "Z"
        }
        return fmpDate
    }
}

// MARK: - FMP stable API decodable models

private struct FMPSearchResult: Decodable {
    let symbol: String
    let name: String
    let exchange: String?
}

private struct FMPProfile: Decodable {
    let symbol: String
    let companyName: String
    let sector: String?
    let marketCap: Decimal?
    let description: String?
}

private struct FMPQuote: Decodable {
    let symbol: String
    let price: Decimal
}

private struct FMPDividend: Decodable {
    let symbol: String
    let date: String             // ex-date "YYYY-MM-DD"
    let dividend: Decimal
    let paymentDate: String?
    let declarationDate: String?
    let frequency: String?       // "Quarterly", "Monthly", "Annual", etc.
}

private struct FMPNewsArticle: Decodable {
    let symbols: [String]?
    let publishedDate: String
    let title: String
    let text: String?
    let url: String
    let image: String?
    let site: String?
}
