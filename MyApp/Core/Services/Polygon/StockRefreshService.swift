import Foundation
import SwiftData
import Observation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.myapp.MyApp",
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

    private let polygon: any PolygonFetching
    private let settings: SettingsStore
    private let container: ModelContainer
    /// Optional delay between consecutive ticker refreshes. Defaults to zero
    /// (unlimited API calls on Polygon Starter). Can be overridden in tests.
    private let interTickerDelay: Duration

    init(
        settings: SettingsStore,
        container: ModelContainer = .app,
        polygon: any PolygonFetching = PolygonService(),
        interTickerDelay: Duration = .milliseconds(0)
    ) {
        self.settings = settings
        self.container = container
        self.polygon = polygon
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
        guard settings.hasAPIKey else {
            logger.info("Skipping refresh for \(ticker): API key not configured.")
            return
        }
        await refreshTicker(ticker, apiKey: settings.apiKey)
    }

    /// Refresh all stale stocks. Call when the app returns to foreground.
    /// Tickers are refreshed sequentially with an optional `interTickerDelay` between each.
    func refreshStaleStocks() async {
        guard !isRefreshing else { return }
        guard settings.hasAPIKey else { return }
        lastRefreshError = nil   // clear previous error on every new refresh attempt
        let apiKey = settings.apiKey

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
        for (index, stock) in staleStocks.enumerated() {
            await refreshTicker(stock.ticker, apiKey: apiKey)
            // Sleep between tickers (not after the last one).
            // Propagate cancellation so the loop stops when the parent task is cancelled.
            if index < staleStocks.count - 1 {
                do {
                    try await Task.sleep(for: interTickerDelay)
                } catch {
                    break   // CancellationError — stop processing remaining tickers.
                }
            }
        }
    }

    // MARK: - Private

    private func refreshTicker(_ ticker: String, apiKey: String) async {
        let context = ModelContext(container)
        do {
            // Fetch details and price concurrently — required for a useful refresh.
            async let detailsTask = polygon.fetchTickerDetails(ticker: ticker, apiKey: apiKey)
            async let priceTask   = polygon.fetchPreviousClose(ticker: ticker, apiKey: apiKey)
            let (details, price) = try await (detailsTask, priceTask)

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
                let dividends = try await polygon.fetchDividends(ticker: ticker, limit: 8, apiKey: apiKey)
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
                lastRefreshError = "Could not refresh \(ticker). Check your connection or API key."
            }
        }
    }

    private func updateDividendSchedules(
        stock: Stock,
        dividends: [PolygonDividend],
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
                  let freq = div.frequency.flatMap({ DividendFrequency(polygonFrequency: $0) })
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

// MARK: - DividendFrequency ← Polygon frequency integer

private extension DividendFrequency {
    init?(polygonFrequency: Int) {
        switch polygonFrequency {
        case 1:  self = .annual
        case 2:  self = .semiAnnual
        case 4:  self = .quarterly
        case 12: self = .monthly
        default: return nil
        }
    }
}
