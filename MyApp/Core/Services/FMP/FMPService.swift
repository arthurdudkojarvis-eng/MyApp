import Foundation

// MARK: - FMPService
// Implements PolygonFetching using the Financial Modeling Prep (FMP) API.
// All responses are mapped to the existing Polygon model types so the rest
// of the app continues to work without any structural changes.

struct FMPService: PolygonFetching {
    private static let baseURL = "https://financialmodelingprep.com/api"

    // FMP doesn't use snake_case — field names already match Swift conventions.
    private static let decoder = JSONDecoder()

    private static let tickerAllowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: ".-"))

    // MARK: - Ticker Search

    func fetchTickerSearch(query: String, apiKey: String) async throws -> [PolygonTickerSearchResult] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/search-ticker") else {
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
                primaryExchange: $0.stockExchange
            )
        }
    }

    // MARK: - Ticker Details

    func fetchTickerDetails(ticker: String, apiKey: String) async throws -> PolygonTickerDetails {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/profile/\(encoded)") else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let results = try Self.decoder.decode([FMPProfile].self, from: data)
        guard let profile = results.first else { throw PolygonError.emptyResponse }
        return PolygonTickerDetails(
            ticker:         profile.symbol,
            name:           profile.companyName,
            sicDescription: profile.sector,
            marketCap:      profile.mktCap,
            description:    profile.description
        )
    }

    // MARK: - Price (quote-short)

    func fetchPreviousClose(ticker: String, apiKey: String) async throws -> Decimal? {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/quote-short/\(encoded)") else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let results = try Self.decoder.decode([FMPQuoteShort].self, from: data)
        return results.first?.price
    }

    // MARK: - Dividends

    func fetchDividends(ticker: String, limit: Int, apiKey: String) async throws -> [PolygonDividend] {
        let encoded = try percentEncode(ticker: ticker)
        guard var components = URLComponents(
            string: "\(Self.baseURL)/v3/historical-price-full/stock_dividend/\(encoded)"
        ) else { throw URLError(.badURL) }
        components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(FMPDividendResponse.self, from: data)
        let historical = response.historical ?? []

        // Infer payment frequency from the spacing of the most recent dividend dates
        // so StockRefreshService can correctly build DividendSchedules.
        let freq = inferFrequency(from: historical.prefix(13).compactMap {
            Self.ymdFormatter.date(from: $0.date)
        })

        return historical.prefix(limit).map { div in
            PolygonDividend(
                ticker:          ticker.uppercased(),
                cashAmount:      div.dividend,
                exDividendDate:  div.date,
                payDate:         div.paymentDate,
                declarationDate: div.declarationDate,
                frequency:       freq,
                dividendType:    "CD"   // FMP only returns regular cash dividends here
            )
        }
    }

    // MARK: - News

    func fetchNews(tickers: [String], limit: Int, apiKey: String) async throws -> [PolygonNewsArticle] {
        guard var components = URLComponents(string: "\(Self.baseURL)/v3/stock_news") else {
            throw URLError(.badURL)
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit",  value: "\(limit)"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        // Validate each ticker through percentEncode before joining to prevent
        // malformed symbols from splitting the comma-separated parameter.
        let validTickers = tickers.compactMap { try? percentEncode(ticker: $0) }
        if !validTickers.isEmpty {
            queryItems.append(URLQueryItem(name: "tickers", value: validTickers.joined(separator: ",")))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await fetch(url: url)
        let results = try Self.decoder.decode([FMPNewsArticle].self, from: data)
        return results.map { article in
            PolygonNewsArticle(
                id:           article.url,
                title:        article.title,
                description:  article.text.map { String($0.prefix(300)) },
                publishedUtc: isoDateString(from: article.publishedDate),
                articleUrl:   article.url,
                author:       article.site,
                tickers:      article.symbol.map { [$0] },
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

    /// Converts FMP's "YYYY-MM-DD HH:mm:ss" format to ISO-8601 "YYYY-MM-DDTHH:mm:ssZ"
    /// so existing ISO8601DateFormatter usage in the UI parses correctly.
    private func isoDateString(from fmpDate: String) -> String {
        // FMP uses a space separator and no timezone; treat as UTC.
        if fmpDate.contains(" ") {
            return fmpDate.replacingOccurrences(of: " ", with: "T") + "Z"
        }
        return fmpDate
    }

    /// Infers annual payment frequency (1/2/4/12) from average spacing between dividend dates.
    /// Falls back to 4 (quarterly) when there is insufficient history.
    private func inferFrequency(from dates: [Date]) -> Int {
        guard dates.count >= 2 else { return 4 }
        let sorted = dates.sorted()
        let gaps = zip(sorted, sorted.dropFirst()).compactMap {
            Calendar.current.dateComponents([.day], from: $0, to: $1).day
        }
        guard !gaps.isEmpty else { return 4 }
        // Use Double to avoid integer truncation near bucket boundaries.
        let avgGap = Double(gaps.reduce(0, +)) / Double(gaps.count)
        switch avgGap {
        case ..<40:  return 12  // monthly  (~30 days)
        case ..<110: return 4   // quarterly (~91 days)
        case ..<230: return 2   // semi-annual (~182 days)
        default:     return 1   // annual
        }
    }

    private static let ymdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

// MARK: - FMP-private decodable models

private struct FMPSearchResult: Decodable {
    let symbol: String
    let name: String
    let stockExchange: String?
}

private struct FMPProfile: Decodable {
    let symbol: String
    let companyName: String
    let sector: String?
    let mktCap: Decimal?
    let description: String?
}

private struct FMPQuoteShort: Decodable {
    let symbol: String
    let price: Decimal
}

private struct FMPDividendResponse: Decodable {
    let historical: [FMPDividend]?
}

private struct FMPDividend: Decodable {
    let date: String             // ex-date "YYYY-MM-DD"
    let dividend: Decimal
    let paymentDate: String?
    let declarationDate: String?
}

private struct FMPNewsArticle: Decodable {
    let symbol: String?     // absent for general market articles
    let publishedDate: String
    let title: String
    let text: String?
    let url: String
    let image: String?
    let site: String?
}
