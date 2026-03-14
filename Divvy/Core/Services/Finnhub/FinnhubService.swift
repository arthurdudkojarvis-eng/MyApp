import Foundation

struct FinnhubService: FinnhubFetching {
    /// Reuses the same CF Worker proxy as MassiveService.
    /// Finnhub requests are routed through the /finnhub/* path prefix.
    private static let baseURL = MassiveService.baseURL

    /// Same shared secret the worker validates via X-App-Token header.
    private static let appToken = "F604F620-65D7-493E-BF22-44C35C2B5E86"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let rateLimiter = FinnhubRateLimiter.shared

    // MARK: - Recommendation Trends

    func fetchRecommendationTrends(ticker: String) async throws -> [FinnhubRecommendation] {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/stock/recommendation") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        let results = try Self.decoder.decode([FinnhubRecommendation].self, from: data)
        return results
    }

    // MARK: - Price Target

    func fetchPriceTarget(ticker: String) async throws -> FinnhubPriceTarget {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/stock/price-target") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        return try Self.decoder.decode(FinnhubPriceTarget.self, from: data)
    }

    // MARK: - Company Profile

    func fetchCompanyProfile(ticker: String) async throws -> FinnhubCompanyProfile {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/stock/profile2") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        return try Self.decoder.decode(FinnhubCompanyProfile.self, from: data)
    }

    // MARK: - Quote

    func fetchQuote(ticker: String) async throws -> FinnhubQuote {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/quote") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        return try Self.decoder.decode(FinnhubQuote.self, from: data)
    }

    // MARK: - Basic Financials

    func fetchBasicFinancials(ticker: String) async throws -> FinnhubBasicFinancials {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/stock/metric") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker),
            URLQueryItem(name: "metric", value: "all")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metricDict = json["metric"] as? [String: Any] else {
            throw FinnhubError.decodingError
        }

        var doubles: [String: Double] = [:]
        for (key, value) in metricDict {
            if let d = value as? Double {
                doubles[key] = d
            }
        }
        return FinnhubBasicFinancials(metrics: doubles)
    }

    // MARK: - Peers

    func fetchPeers(ticker: String) async throws -> [String] {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/stock/peers") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        return try Self.decoder.decode([String].self, from: data)
    }

    // MARK: - Earnings

    func fetchEarnings(ticker: String) async throws -> [FinnhubEarning] {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/stock/earnings") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        return try Self.decoder.decode([FinnhubEarning].self, from: data)
    }

    // MARK: - Insider Transactions

    func fetchInsiderTransactions(ticker: String) async throws -> [FinnhubInsiderTransaction] {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/stock/insider-transactions") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(FinnhubInsiderTransactionsResponse.self, from: data)
        return response.data ?? []
    }

    // MARK: - Insider Sentiment

    func fetchInsiderSentiment(ticker: String, from: String, to: String) async throws -> [FinnhubInsiderSentimentData] {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/stock/insider-sentiment") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(FinnhubInsiderSentimentResponse.self, from: data)
        return response.data ?? []
    }

    // MARK: - Earnings Calendar

    func fetchEarningsCalendar(from: String, to: String) async throws -> [FinnhubEarningsCalendarEntry] {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/calendar/earnings") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        let response = try Self.decoder.decode(FinnhubEarningsCalendarResponse.self, from: data)
        return response.earningsCalendar ?? []
    }

    // MARK: - Company News

    func fetchCompanyNews(ticker: String, from: String, to: String) async throws -> [FinnhubNewsArticle] {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/company-news") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "symbol", value: ticker),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        return try Self.decoder.decode([FinnhubNewsArticle].self, from: data)
    }

    // MARK: - General News

    func fetchGeneralNews(category: String) async throws -> [FinnhubNewsArticle] {
        guard var components = URLComponents(string: "\(Self.baseURL)/finnhub/news") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "category", value: category)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        await rateLimiter.acquire()
        let data = try await fetch(url: url)
        return try Self.decoder.decode([FinnhubNewsArticle].self, from: data)
    }

    // MARK: - Helpers

    private func fetch(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.appToken, forHTTPHeaderField: "X-App-Token")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                throw FinnhubError.rateLimitExceeded
            }
            if !(200..<300).contains(http.statusCode) {
                throw FinnhubError.httpError(statusCode: http.statusCode)
            }
        }
        return data
    }
}
