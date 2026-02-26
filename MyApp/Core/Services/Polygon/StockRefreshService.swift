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

    private let polygon: any PolygonFetching
    private let settings: SettingsStore
    private let container: ModelContainer

    init(
        settings: SettingsStore,
        container: ModelContainer = .app,
        polygon: any PolygonFetching = PolygonService()
    ) {
        self.settings = settings
        self.container = container
        self.polygon = polygon
    }

    // MARK: - Public API

    /// Refresh a single ticker. Call after adding a new holding.
    func refresh(ticker: String) async {
        guard settings.hasPolygonAPIKey else {
            logger.info("Skipping refresh for \(ticker): API key not configured.")
            return
        }
        await refreshTicker(ticker, apiKey: settings.polygonAPIKey)
    }

    /// Refresh all stale stocks. Call when the app returns to foreground.
    func refreshStaleStocks() async {
        guard !isRefreshing else { return }
        guard settings.hasPolygonAPIKey else { return }
        let apiKey = settings.polygonAPIKey
        let context = ModelContext(container)
        let staleStocks: [Stock]
        do {
            staleStocks = try context.fetch(FetchDescriptor<Stock>()).filter { $0.isStale }
        } catch {
            logger.error("Failed to fetch stocks: \(error.localizedDescription)")
            return
        }
        guard !staleStocks.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await withTaskGroup(of: Void.self) { group in
            for stock in staleStocks {
                group.addTask { await self.refreshTicker(stock.ticker, apiKey: apiKey) }
            }
        }
    }

    // MARK: - Private

    private func refreshTicker(_ ticker: String, apiKey: String) async {
        let context = ModelContext(container)
        do {
            // Fetch all three endpoints concurrently.
            async let detailsTask   = polygon.fetchTickerDetails(ticker: ticker, apiKey: apiKey)
            async let priceTask     = polygon.fetchPreviousClose(ticker: ticker, apiKey: apiKey)
            async let dividendsTask = polygon.fetchDividends(ticker: ticker, limit: 8, apiKey: apiKey)

            let (details, price, dividends) = try await (detailsTask, priceTask, dividendsTask)

            // Find or create the Stock.
            let descriptor = FetchDescriptor<Stock>(predicate: #Predicate<Stock> { $0.ticker == ticker })
            guard let stock = try context.fetch(descriptor).first else {
                logger.warning("No Stock found for ticker \(ticker) — skipping update.")
                return
            }

            stock.companyName = details.name
            stock.sector      = details.sicDescription ?? stock.sector
            if let p = price  { stock.currentPrice = p }
            stock.lastUpdated = .now

            updateDividendSchedules(stock: stock, dividends: dividends, context: context)
            try context.save()
            logger.info("Refreshed \(ticker)")

        } catch {
            logger.error("Failed to refresh \(ticker): \(error.localizedDescription)")
        }
    }

    private func updateDividendSchedules(
        stock: Stock,
        dividends: [PolygonDividend],
        context: ModelContext
    ) {
        // Delete existing schedules; payments survive via .nullify delete rule.
        for schedule in stock.dividendSchedules { context.delete(schedule) }
        stock.dividendSchedules = []

        for div in dividends {
            guard div.dividendType == "CD",
                  let exDate = dateFormatter.date(from: div.exDividendDate),
                  let freq = div.frequency.flatMap({ DividendFrequency(polygonFrequency: $0) })
            else { continue }

            let payDate      = div.payDate.flatMap { dateFormatter.date(from: $0) } ?? exDate
            let declaredDate = div.declarationDate.flatMap { dateFormatter.date(from: $0) }
            let status: DividendScheduleStatus = declaredDate != nil ? .declared : .estimated

            let schedule = DividendSchedule(
                frequency: freq,
                amountPerShare: div.cashAmount,
                exDate: exDate,
                payDate: payDate,
                declaredDate: declaredDate ?? .now,
                status: status
            )
            schedule.stock = stock
            context.insert(schedule)
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
