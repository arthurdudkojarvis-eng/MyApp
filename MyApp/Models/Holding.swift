import Foundation
import SwiftData

@Model
final class Holding {
    @Attribute(.unique) var id: UUID
    var shares: Decimal
    var averageCostBasis: Decimal    // per share
    var purchaseDate: Date
    var currency: String             // ISO 4217 — ready for multi-currency
    var externalId: String?          // broker position ID — required for future sync

    // Inverse declared on Portfolio via @Relationship(inverse: \Holding.portfolio).
    // Explicit annotation here makes the delete rule clear: Portfolio deletion does
    // NOT cascade from this side — it cascades from Portfolio.holdings.
    @Relationship(deleteRule: .nullify)
    var portfolio: Portfolio?

    // .nullify: deleting a Holding does NOT delete the Stock.
    // Other holdings (or other portfolios) may reference the same Stock.
    var stock: Stock?

    @Relationship(deleteRule: .cascade, inverse: \DividendPayment.holding)
    var dividendPayments: [DividendPayment] = []

    init(
        shares: Decimal,
        averageCostBasis: Decimal,
        purchaseDate: Date = .now,
        currency: String = "USD"
    ) {
        id = UUID()
        self.shares = shares
        self.averageCostBasis = averageCostBasis
        self.purchaseDate = purchaseDate
        self.currency = currency
    }

    // MARK: - Income Metrics

    /// (annualDividendPerShare / averageCostBasis) × 100
    var yieldOnCost: Decimal {
        guard let annual = stock?.annualDividendPerShare, averageCostBasis > 0 else { return 0 }
        return (annual / averageCostBasis) * 100
    }

    /// annualDividendPerShare × shares
    var projectedAnnualIncome: Decimal {
        guard let annual = stock?.annualDividendPerShare else { return 0 }
        return annual * shares
    }

    var projectedMonthlyIncome: Decimal {
        projectedAnnualIncome / Decimal(12)
    }

    /// Current market value: currentPrice × shares
    var currentValue: Decimal {
        guard let price = stock?.currentPrice else { return 0 }
        return price * shares
    }

    /// Current yield based on market price (not cost basis).
    var currentYield: Decimal {
        guard let stock, stock.currentPrice > 0 else { return 0 }
        return (stock.annualDividendPerShare / stock.currentPrice) * 100
    }

    /// Total dividends actually received from this holding.
    var totalDividendsReceived: Decimal {
        dividendPayments.reduce(0) { $0 + $1.totalAmount }
    }
}
