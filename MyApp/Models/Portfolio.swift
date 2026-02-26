import Foundation
import SwiftData

@Model
final class Portfolio {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var currency: String    // ISO 4217, e.g. "USD" — ready for multi-currency

    @Relationship(deleteRule: .cascade, inverse: \Holding.portfolio)
    var holdings: [Holding] = []

    init(name: String, currency: String = "USD") {
        id = UUID()
        self.name = name
        createdAt = .now
        self.currency = currency
    }

    var projectedAnnualIncome: Decimal {
        holdings.reduce(0) { $0 + $1.projectedAnnualIncome }
    }

    var projectedMonthlyIncome: Decimal {
        projectedAnnualIncome / Decimal(12)
    }

    // MARK: - Performance

    var totalMarketValue: Decimal {
        holdings.reduce(0) { $0 + $1.currentValue }
    }

    /// Sum of (averageCostBasis × shares) across all holdings.
    var totalCostBasis: Decimal {
        holdings.reduce(0) { $0 + $1.averageCostBasis * $1.shares }
    }

    var totalUnrealizedGain: Decimal {
        holdings.reduce(0) { $0 + $1.unrealizedGain }
    }

    /// Portfolio-level unrealized gain percent using aggregate cost basis.
    var totalUnrealizedGainPercent: Decimal? {
        let cost = totalCostBasis
        guard cost > 0 else { return nil }
        return (totalUnrealizedGain / cost) * 100
    }
}
