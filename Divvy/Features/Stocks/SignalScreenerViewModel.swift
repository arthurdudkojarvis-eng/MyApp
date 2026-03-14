import Foundation
import SwiftData
import OSLog

private let screenerLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.divvy.Divvy",
                                    category: "SignalScreener")

// MARK: - Row Model

struct SignalScreenerRow: Identifiable {
    let ticker: String
    let companyName: String
    var marketCap: Decimal?
    var signalScore: Int?
    var confidence: Confidence?
    var isLoading: Bool

    var id: String { ticker }
}

// MARK: - Sort Column

enum ScreenerSortColumn: String, CaseIterable {
    case symbol, marketCap, signalScore
}

// MARK: - View Model

@MainActor @Observable
final class SignalScreenerViewModel {

    var rows: [SignalScreenerRow] = []
    var isInitialLoading = false
    var searchQuery = ""
    var sortColumn: ScreenerSortColumn = .signalScore
    var sortAscending = false

    private var hasLoaded = false
    private static let cacheWindow: TimeInterval = 24 * 60 * 60  // 24 hours

    private nonisolated static let aggregateDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Displayed Rows (filtered + sorted)

    var displayedRows: [SignalScreenerRow] {
        var filtered = rows
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            filtered = filtered.filter {
                $0.ticker.lowercased().contains(q) || $0.companyName.lowercased().contains(q)
            }
        }
        return filtered.sorted { a, b in
            switch sortColumn {
            case .symbol:
                let cmp = a.ticker.localizedCaseInsensitiveCompare(b.ticker)
                return sortAscending ? cmp == .orderedAscending : cmp == .orderedDescending
            case .marketCap:
                return compareOptionals(a.marketCap, b.marketCap, ascending: sortAscending)
            case .signalScore:
                return compareOptionals(
                    a.signalScore.map { Decimal($0) },
                    b.signalScore.map { Decimal($0) },
                    ascending: sortAscending
                )
            }
        }
    }

    /// Nil values sort to bottom regardless of direction.
    private func compareOptionals(_ a: Decimal?, _ b: Decimal?, ascending: Bool) -> Bool {
        switch (a, b) {
        case (.some(let av), .some(let bv)):
            return ascending ? av < bv : av > bv
        case (.some, .none):
            return true   // non-nil before nil
        case (.none, .some):
            return false  // nil after non-nil
        case (.none, .none):
            return false
        }
    }

    // MARK: - Load

    func loadIfNeeded(
        portfolios: [Portfolio],
        watchlistItems: [WatchlistItem],
        massive: MassiveServiceBox,
        finnhub: FinnhubServiceBox,
        modelContext: ModelContext
    ) {
        guard !hasLoaded else { return }
        hasLoaded = true
        isInitialLoading = true

        // Deduplicate tickers from holdings + watchlist
        var seen = Set<String>()
        var universe: [(ticker: String, name: String)] = []

        for portfolio in portfolios {
            for holding in portfolio.holdings {
                guard let stock = holding.stock else { continue }
                let t = stock.ticker
                if seen.insert(t).inserted {
                    universe.append((t, stock.companyName))
                }
            }
        }
        for item in watchlistItems {
            let t = item.ticker
            if seen.insert(t).inserted {
                universe.append((t, item.companyName))
            }
        }

        guard !universe.isEmpty else {
            isInitialLoading = false
            return
        }

        // Build initial rows (all loading)
        rows = universe.map { SignalScreenerRow(ticker: $0.ticker, companyName: $0.name, isLoading: true) }

        // Look up cached scores from SwiftData
        let cachedStocks: [Stock]
        do {
            var descriptor = FetchDescriptor<Stock>()
            descriptor.fetchLimit = 500
            cachedStocks = try modelContext.fetch(descriptor)
        } catch {
            cachedStocks = []
        }
        let stockMap = Dictionary(cachedStocks.map { ($0.ticker, $0) }, uniquingKeysWith: { a, _ in a })

        // Apply cached scores where fresh enough
        let now = Date.now
        for i in rows.indices {
            if let stock = stockMap[rows[i].ticker],
               let score = stock.signalScore,
               let updatedAt = stock.signalScoreUpdatedAt,
               now.timeIntervalSince(updatedAt) < Self.cacheWindow {
                rows[i].signalScore = score
                rows[i].confidence = SignalScore(value: score, breakdown: [:]).confidence
                rows[i].isLoading = false
            }
        }

        // Fetch stale/new ones
        let staleTickers = rows.filter { $0.isLoading }.map { $0.ticker }
        guard !staleTickers.isEmpty else {
            isInitialLoading = false
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await self.fetchScores(
                tickers: staleTickers,
                massive: massive.service,
                finnhub: finnhub.service,
                modelContext: modelContext,
                stockMap: stockMap
            )
            self.isInitialLoading = false
        }
    }

    // MARK: - Concurrent Fetch

    private func fetchScores(
        tickers: [String],
        massive: any MassiveFetching,
        finnhub: any FinnhubFetching,
        modelContext: ModelContext,
        stockMap: [String: Stock]
    ) async {
        await withTaskGroup(of: (String, Int?, Decimal?, Confidence?).self) { group in
            var inFlight = 0

            for ticker in tickers {
                // Throttle: max 5 concurrent
                if inFlight >= 5 {
                    if let result = await group.next() {
                        applyResult(result, modelContext: modelContext, stockMap: stockMap)
                        inFlight -= 1
                    }
                }

                group.addTask { @Sendable in
                    await self.computeScore(ticker: ticker, massive: massive, finnhub: finnhub)
                }
                inFlight += 1
            }

            for await result in group {
                applyResult(result, modelContext: modelContext, stockMap: stockMap)
            }
        }
        try? modelContext.save()
    }

    private nonisolated func computeScore(
        ticker: String,
        massive: any MassiveFetching,
        finnhub: any FinnhubFetching
    ) async -> (String, Int?, Decimal?, Confidence?) {
        var marketCap: Decimal?
        var dividendYield: Decimal?
        var payoutRatio: Decimal?
        var dailyCloses: [Decimal] = []
        var analystRec: FinnhubRecommendation?

        // Fetch all data concurrently
        async let detailsTask = { try? await massive.fetchTickerDetails(ticker: ticker) }()
        async let priceTask = { try? await massive.fetchPreviousClose(ticker: ticker) }()
        async let divsTask = { try? await massive.fetchDividends(ticker: ticker, limit: 4) }()
        async let financialsTask = { try? await massive.fetchFinancials(ticker: ticker, limit: 2) }()

        let today = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: today) ?? today
        let fromStr = Self.aggregateDateFormatter.string(from: oneYearAgo)
        let toStr = Self.aggregateDateFormatter.string(from: today)

        async let aggsTask = { try? await massive.fetchAggregates(ticker: ticker, from: fromStr, to: toStr) }()
        async let recTask = { try? await finnhub.fetchRecommendationTrends(ticker: ticker) }()

        let details = await detailsTask
        let price = await priceTask
        let divs = await divsTask ?? []
        let financials = await financialsTask ?? []
        let aggs = await aggsTask ?? []
        let recs = await recTask ?? []

        marketCap = details?.marketCap

        // Yield: latest dividend * frequency / price
        if let latest = divs.first, let p = price, p > 0 {
            let freq = Decimal(latest.frequency ?? 4)
            let annual = latest.cashAmount * freq
            dividendYield = (annual / p) * 100
        }

        // Payout ratio: dividend per share / EPS
        if let eps = financials.first?.basicEarningsPerShare, eps > 0,
           let latest = divs.first {
            let freq = Decimal(latest.frequency ?? 4)
            let annualDiv = latest.cashAmount * freq
            payoutRatio = (annualDiv / eps) * 100
        }

        // Daily closes for volatility
        dailyCloses = aggs.map { $0.c }

        // Analyst recommendation (most recent)
        analystRec = recs.first

        // Dividend growth years (count consecutive years with dividends)
        let growthYears: Int? = divs.count >= 2 ? divs.count : nil

        let inputs = SignalInputs(
            dividendYield: dividendYield,
            payoutRatio: payoutRatio,
            dividendGrowthYears: growthYears,
            analystCounts: analystRec,
            dailyCloses: dailyCloses
        )

        let score = SignalScoreCalculator.calculate(from: inputs)
        return (ticker, score?.value, marketCap, score?.confidence)
    }

    private func applyResult(
        _ result: (String, Int?, Decimal?, Confidence?),
        modelContext: ModelContext,
        stockMap: [String: Stock]
    ) {
        let (ticker, score, marketCap, confidence) = result
        if let idx = rows.firstIndex(where: { $0.ticker == ticker }) {
            rows[idx].signalScore = score
            rows[idx].marketCap = marketCap
            rows[idx].confidence = confidence
            rows[idx].isLoading = false
        }

        // Persist to Stock model
        if let stock = stockMap[ticker] {
            stock.signalScore = score
            stock.signalScoreUpdatedAt = .now
        }

        screenerLogger.debug("Scored \(ticker): \(score.map { String($0) } ?? "nil")")
    }
}
