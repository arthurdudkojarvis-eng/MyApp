import Foundation

// MARK: - Protocol (enables mocking in tests)

protocol FinnhubFetching: Sendable {
    func fetchRecommendationTrends(ticker: String) async throws -> [FinnhubRecommendation]
    func fetchPriceTarget(ticker: String) async throws -> FinnhubPriceTarget
    func fetchCompanyProfile(ticker: String) async throws -> FinnhubCompanyProfile
    func fetchQuote(ticker: String) async throws -> FinnhubQuote
    func fetchBasicFinancials(ticker: String) async throws -> FinnhubBasicFinancials
    func fetchPeers(ticker: String) async throws -> [String]
    func fetchEarnings(ticker: String) async throws -> [FinnhubEarning]
    func fetchInsiderTransactions(ticker: String) async throws -> [FinnhubInsiderTransaction]
    func fetchInsiderSentiment(ticker: String, from: String, to: String) async throws -> [FinnhubInsiderSentimentData]
    func fetchEarningsCalendar(from: String, to: String) async throws -> [FinnhubEarningsCalendarEntry]
    func fetchCompanyNews(ticker: String, from: String, to: String) async throws -> [FinnhubNewsArticle]
    func fetchGeneralNews(category: String) async throws -> [FinnhubNewsArticle]
}

// MARK: - Recommendation Trends
// Endpoint: /finnhub/stock/recommendation?symbol={ticker}
// Returns an array of monthly consensus snapshots.

struct FinnhubRecommendation: Decodable {
    let buy: Int
    let hold: Int
    let sell: Int
    let strongBuy: Int
    let strongSell: Int
    let period: String          // "YYYY-MM-DD"
}

// MARK: - Price Target Consensus
// Endpoint: /finnhub/stock/price-target?symbol={ticker}

struct FinnhubPriceTarget: Decodable {
    let targetHigh: Decimal
    let targetLow: Decimal
    let targetMean: Decimal
    let targetMedian: Decimal
    let lastUpdated: String     // "YYYY-MM-DD"
}

// MARK: - Company Profile
// Endpoint: /finnhub/stock/profile2?symbol={ticker}

struct FinnhubCompanyProfile: Decodable {
    let country: String?
    let currency: String?
    let exchange: String?
    let finnhubIndustry: String?
    let ipo: String?
    let logo: String?
    let marketCapitalization: Double?
    let name: String?
    let shareOutstanding: Double?
    let ticker: String?
    let weburl: String?
}

// MARK: - Quote
// Endpoint: /finnhub/quote?symbol={ticker}

struct FinnhubQuote: Decodable {
    let c: Double   // current price
    let d: Double?  // change
    let dp: Double? // change percent
    let h: Double   // high
    let l: Double   // low
    let o: Double   // open
    let pc: Double  // previous close
    let t: Int      // unix timestamp
}

// MARK: - Basic Financials (Metrics)
// Endpoint: /finnhub/stock/metric?symbol={ticker}&metric=all
// Uses JSONSerialization — the metric dict has 132 keys with mixed types.

struct FinnhubBasicFinancials {
    let metrics: [String: Double]

    var weekHigh52: Double? { metrics["52WeekHigh"] }
    var weekLow52: Double? { metrics["52WeekLow"] }
    var beta: Double? { metrics["beta"] }
    var dividendYieldIndicatedAnnual: Double? { metrics["dividendYieldIndicatedAnnual"] }
    var dividendGrowthRate5Y: Double? { metrics["dividendGrowthRate5Y"] }
    var dividendPerShareAnnual: Double? { metrics["dividendPerShareAnnual"] }
    var payoutRatioAnnual: Double? { metrics["payoutRatioAnnual"] }
    var peBasicExclExtraTTM: Double? { metrics["peBasicExclExtraTTM"] }
    var pbAnnual: Double? { metrics["pbAnnual"] }
    var epsBasicExclExtraTTM: Double? { metrics["epsBasicExclExtraTTM"] }
    var roaAnnual: Double? { metrics["roaAnnual"] }
    var roeAnnual: Double? { metrics["roeAnnual"] }
    var currentRatioAnnual: Double? { metrics["currentRatioAnnual"] }
    var revenuePerShareAnnual: Double? { metrics["revenuePerShareAnnual"] }
}

// MARK: - Earnings
// Endpoint: /finnhub/stock/earnings?symbol={ticker}

struct FinnhubEarning: Decodable {
    let actual: Double?
    let estimate: Double?
    let period: String
    let quarter: Int
    let surprise: Double?
    let surprisePercent: Double?
    let symbol: String
    let year: Int
}

// MARK: - Insider Transactions
// Endpoint: /finnhub/stock/insider-transactions?symbol={ticker}

struct FinnhubInsiderTransaction: Decodable {
    let change: Int
    let filingDate: String
    let name: String
    let share: Int
    let symbol: String
    let transactionCode: String
    let transactionDate: String
    let transactionPrice: Double
}

struct FinnhubInsiderTransactionsResponse: Decodable {
    let data: [FinnhubInsiderTransaction]?
}

// MARK: - Insider Sentiment
// Endpoint: /finnhub/stock/insider-sentiment?symbol={ticker}&from={from}&to={to}

struct FinnhubInsiderSentimentData: Decodable {
    let symbol: String
    let year: Int
    let month: Int
    let change: Int
    let mspr: Double
}

struct FinnhubInsiderSentimentResponse: Decodable {
    let data: [FinnhubInsiderSentimentData]?
}

// MARK: - Earnings Calendar
// Endpoint: /finnhub/calendar/earnings?from={from}&to={to}

struct FinnhubEarningsCalendarEntry: Decodable {
    let date: String
    let epsActual: Double?
    let epsEstimate: Double?
    let hour: String?
    let quarter: Int
    let revenueActual: Double?
    let revenueEstimate: Double?
    let symbol: String
    let year: Int
}

struct FinnhubEarningsCalendarResponse: Decodable {
    let earningsCalendar: [FinnhubEarningsCalendarEntry]?
}

// MARK: - News Article
// Shared by /finnhub/company-news and /finnhub/news (same JSON shape).

struct FinnhubNewsArticle: Decodable, Identifiable {
    let id: Int
    let category: String
    let datetime: Int
    let headline: String
    let image: String?
    let related: String?
    let source: String
    let summary: String?
    let url: String
}

// MARK: - Errors

enum FinnhubError: Error, LocalizedError {
    case httpError(statusCode: Int)
    case decodingError
    case rateLimitExceeded
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .httpError(let c):    return "Finnhub API returned HTTP \(c)."
        case .decodingError:       return "Failed to decode Finnhub response."
        case .rateLimitExceeded:   return "Finnhub rate limit exceeded."
        case .emptyResponse:       return "Finnhub API returned no results."
        }
    }
}
