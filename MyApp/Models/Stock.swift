import Foundation
import SwiftData

@Model
final class Stock {
    @Attribute(.unique) var ticker: String
    var companyName: String
    var sector: String
    var currentPrice: Decimal
    var currency: String        // ISO 4217 — ready for multi-currency
    var lastUpdated: Date
    var externalId: String?     // broker/data-provider ID — required for future sync

    @Relationship(deleteRule: .cascade, inverse: \DividendSchedule.stock)
    var dividendSchedules: [DividendSchedule] = []

    // Explicit inverse so behaviour on Stock deletion is documented.
    // .nullify: deleting a Stock nullifies Holding.stock, does not delete Holding.
    @Relationship(deleteRule: .nullify, inverse: \Holding.stock)
    var holdings: [Holding] = []

    init(
        ticker: String,
        companyName: String = "",
        sector: String = "",
        currentPrice: Decimal = 0,
        currency: String = "USD"
    ) {
        self.ticker = ticker.uppercased()
        self.companyName = companyName
        self.sector = sector
        self.currentPrice = currentPrice
        self.currency = currency
        lastUpdated = .now
    }

    // MARK: - Income Projections

    /// Most recent declared dividend, falling back to estimated then most recent paid.
    /// Returns the annualised amount per share, or 0 if no schedules exist.
    var annualDividendPerShare: Decimal {
        let anchor = dividendSchedules.first(withStatus: .declared)
            ?? dividendSchedules.first(withStatus: .estimated)
            ?? dividendSchedules.sorted(by: { $0.exDate > $1.exDate }).first
        guard let anchor else { return 0 }
        return anchor.amountPerShare * Decimal(anchor.frequency.paymentsPerYear)
    }

    // MARK: - Upcoming Dates

    var nextExDate: Date? {
        dividendSchedules
            .filter { $0.isUpcoming }
            .sorted { $0.exDate < $1.exDate }
            .first?.exDate
    }

    var nextPayDate: Date? {
        dividendSchedules
            .filter { $0.payDate >= .now }
            .sorted { $0.payDate < $1.payDate }
            .first?.payDate
    }

    // MARK: - Staleness

    private static let staleThresholdHours = -24

    var isStale: Bool {
        let threshold = Calendar.current.date(
            byAdding: .hour,
            value: Self.staleThresholdHours,
            to: .now
        ) ?? .distantPast  // conservative: treat as stale if date math fails
        return lastUpdated < threshold
    }
}

// MARK: - Helpers

private extension [DividendSchedule] {
    func first(withStatus status: DividendScheduleStatus) -> DividendSchedule? {
        filter { $0.status == status }
            .sorted { $0.exDate > $1.exDate }
            .first
    }
}
