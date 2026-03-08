import Foundation
import SwiftData
import Observation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.divvy.Divvy",
                            category: "StockRefreshService")

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    return f
}()

@MainActor
@Observable
final class StockRefreshService {
    private(set) var isRefreshing = false
    private(set) var lastRefreshError: String?

    func dismissRefreshError() { lastRefreshError = nil }

    private let massive: any MassiveFetching
    private let container: ModelContainer
    /// Optional delay between consecutive ticker refreshes. Defaults to zero
    /// because the Massive paid plan offers unlimited API calls. Override in tests
    /// or set to a non-zero value if switching to a rate-limited tier.
    private let interTickerDelay: Duration

    init(
        container: ModelContainer = .app,
        massive: any MassiveFetching = MassiveService(),
        interTickerDelay: Duration = .milliseconds(0)
    ) {
        self.container = container
        self.massive = massive
        self.interTickerDelay = interTickerDelay
    }

    // MARK: - Public API

    /// Refresh a single ticker. Call after adding a new holding.
    /// No-ops if a bulk refresh is already in progress to avoid concurrent
    /// writes from two independent ModelContext instances.
    func refresh(ticker: String) async {
        guard !isRefreshing else {
            logger.info("Skipping single-ticker refresh for \(ticker): bulk refresh in progress.")
            return
        }
        await refreshTicker(ticker)
    }

    /// Refresh all stale stocks. Call when the app returns to foreground.
    /// Checks market status first and skips refresh when the market is closed (STORY-034).
    /// Uses grouped daily endpoint for batch price fetch when multiple tickers are stale (STORY-035).
    func refreshStaleStocks() async {
        guard !isRefreshing else { return }
        lastRefreshError = nil   // clear previous error on every new refresh attempt

        // STORY-034: Check market status — skip refresh when market is closed.
        // Fail-open: if the status check fails, proceed with refresh anyway.
        let shouldSkip = await checkMarketClosed()
        if shouldSkip {
            logger.info("Market is closed — skipping stale stock refresh.")
            return
        }

        // Push the staleness filter into SwiftData instead of fetching all stocks
        // and filtering in Swift — avoids loading every Stock into memory.
        guard let cutoff = Calendar.current.date(
            byAdding: .hour, value: Stock.staleThresholdHours, to: .now
        ) else {
            logger.error("Date arithmetic failed computing staleness cutoff — skipping refresh.")
            return
        }
        let context = ModelContext(container)
        let staleStocks: [Stock]
        do {
            let descriptor = FetchDescriptor<Stock>(
                predicate: #Predicate<Stock> { $0.lastUpdated < cutoff }
            )
            staleStocks = try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch stale stocks: \(error.localizedDescription)")
            return
        }
        guard !staleStocks.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // STORY-035: Batch price fetch via grouped daily when multiple stale tickers.
        // Single call replaces N per-ticker snapshot calls.
        let batchPrices: [String: Decimal]
        if staleStocks.count >= 2 {
            batchPrices = await fetchBatchPrices()
        } else {
            batchPrices = [:]
        }

        for (index, stock) in staleStocks.enumerated() {
            await refreshTicker(stock.ticker, batchPrice: batchPrices[stock.ticker])
            if index < staleStocks.count - 1 {
                do {
                    try await Task.sleep(for: interTickerDelay)
                } catch {
                    break
                }
            }
        }
    }

    // MARK: - Private

    /// STORY-034: Check if the market is currently closed.
    /// Returns true only when we get a definitive "closed" status.
    /// Fails open (returns false) on network errors so refresh proceeds.
    private func checkMarketClosed() async -> Bool {
        do {
            let status = try await massive.fetchMarketStatus()
            return status.market.lowercased() == "closed"
        } catch {
            logger.warning("Market status check failed — proceeding with refresh: \(error.localizedDescription)")
            return false
        }
    }

    /// STORY-035: Fetch all ticker prices in one API call using the grouped daily endpoint.
    /// Returns a dictionary of ticker → close price. Falls back to empty on failure.
    private func fetchBatchPrices() async -> [String: Decimal] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let dateStr = dateFormatter.string(from: yesterday)
        do {
            let bars = try await massive.fetchGroupedDaily(date: dateStr)
            var prices: [String: Decimal] = [:]
            for bar in bars {
                prices[bar.ticker] = bar.c
            }
            logger.info("Batch price fetch: \(prices.count) tickers loaded.")
            return prices
        } catch {
            logger.warning("Grouped daily fetch failed — falling back to per-ticker: \(error.localizedDescription)")
            return [:]
        }
    }

    private func refreshTicker(_ ticker: String, batchPrice: Decimal? = nil) async {
        let context = ModelContext(container)
        do {
            // If we already have a batch price, skip the per-ticker snapshot call.
            let detailsTask = Task { try await massive.fetchTickerDetails(ticker: ticker) }
            let priceTask: Task<Decimal?, Error>
            if let batchPrice {
                priceTask = Task { batchPrice }
            } else {
                priceTask = Task { try await massive.fetchPreviousClose(ticker: ticker) }
            }
            let details = try await detailsTask.value
            let price = try await priceTask.value

            // Find or create the Stock.
            // NOTE: `stock` and its relationships are live objects from this same
            // `context`; all mutations below must target the same context.
            let descriptor = FetchDescriptor<Stock>(predicate: #Predicate<Stock> { $0.ticker == ticker })
            guard let stock = try context.fetch(descriptor).first else {
                logger.warning("No Stock found for ticker \(ticker) — skipping update.")
                return
            }

            stock.companyName = details.name
            stock.sector      = details.sicDescription ?? stock.sector
            if let p = price  { stock.currentPrice = p }
            stock.lastUpdated = .now

            // Fetch dividends separately so a network hiccup doesn't discard the
            // price/name update already written above.
            do {
                let dividends = try await massive.fetchDividends(ticker: ticker, limit: 8)
                updateDividendSchedules(stock: stock, dividends: dividends, context: context)
            } catch {
                logger.warning("Dividend fetch failed for \(ticker): \(error.localizedDescription)")
            }
            try context.save()
            logger.info("Refreshed \(ticker)")

        } catch {
            logger.error("Failed to refresh \(ticker): \(error.localizedDescription)")
            // Report the first failure; subsequent failures are logged but not shown
            // to the user to avoid overwriting a message the user hasn't seen yet.
            if lastRefreshError == nil {
                lastRefreshError = "Could not refresh \(ticker). Check your connection."
            }
        }
    }

    private func updateDividendSchedules(
        stock: Stock,
        dividends: [MassiveDividend],
        context: ModelContext
    ) {
        // Build a lookup of existing schedules keyed by ex-date string so we can
        // update them in place instead of delete-and-reinsert. Updating in place
        // preserves DividendPayment.dividendSchedule links — the delete rule is
        // .nullify, so delete-and-reinsert would orphan any logged payments.
        var existingByExDate: [String: DividendSchedule] = [:]
        for schedule in stock.dividendSchedules {
            existingByExDate[dateFormatter.string(from: schedule.exDate)] = schedule
        }

        // Tracks which ex-dates were present in this API response (for cleanup).
        var touchedExDates: Set<String> = []

        for div in dividends {
            guard div.dividendType == "CD",
                  let exDate = dateFormatter.date(from: div.exDividendDate),
                  let freq = div.frequency.flatMap({ DividendFrequency(massiveFrequency: $0) })
            else { continue }

            let exDateKey = div.exDividendDate

            // Guard against duplicate ex-dates in the same API response (e.g., a
            // data anomaly or two distributions on the same date). Keep the first.
            guard !touchedExDates.contains(exDateKey) else {
                logger.warning("Duplicate ex-date \(exDateKey) for \(stock.ticker) — skipping.")
                continue
            }

            let payDate      = div.payDate.flatMap { dateFormatter.date(from: $0) } ?? exDate
            let declaredDate = div.declarationDate.flatMap { dateFormatter.date(from: $0) }
            let status: DividendScheduleStatus = declaredDate != nil ? .declared : .estimated

            if let existing = existingByExDate[exDateKey] {
                // Update in place — keeps payment links intact.
                existing.frequency      = freq
                existing.amountPerShare = div.cashAmount
                existing.payDate        = payDate
                existing.declaredDate   = declaredDate ?? existing.declaredDate
                existing.status         = status
            } else {
                let schedule = DividendSchedule(
                    frequency: freq,
                    amountPerShare: div.cashAmount,
                    exDate: exDate,
                    payDate: payDate,
                    // .distantPast signals "no declaration date known" for estimated records;
                    // avoids falsely stamping the current time as a declared date.
                    declaredDate: declaredDate ?? .distantPast,
                    status: status
                )
                schedule.stock = stock
                context.insert(schedule)
            }
            touchedExDates.insert(exDateKey)
        }

        // Delete schedules whose ex-date no longer appears in the API response.
        for (exDateKey, schedule) in existingByExDate where !touchedExDates.contains(exDateKey) {
            context.delete(schedule)
        }
    }
}

// MARK: - DividendFrequency ← Massive frequency integer

private extension DividendFrequency {
    init?(massiveFrequency: Int) {
        switch massiveFrequency {
        case 1:  self = .annual
        case 2:  self = .semiAnnual
        case 4:  self = .quarterly
        case 12: self = .monthly
        default: return nil
        }
    }
}
