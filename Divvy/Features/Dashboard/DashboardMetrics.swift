import Foundation

/// Pure value-type that aggregates income and value metrics across all portfolios.
/// Instantiate directly from the `@Query`-provided portfolios array inside a view.
struct DashboardMetrics {
    /// Sum of projected annual dividend income across all eligible holdings.
    let projectedAnnualIncome: Decimal

    /// `projectedAnnualIncome / 12`.
    let monthlyEquivalent: Decimal

    /// Sum of `shares × currentPrice` across all eligible holdings.
    let totalMarketValue: Decimal

    /// `projectedAnnualIncome / totalMarketValue` as a fraction (0.035 = 3.5%).
    /// `nil` when `totalMarketValue` is zero (no price data yet).
    let overallYield: Decimal?

    init(portfolios: [Portfolio]) {
        let allHoldings = portfolios.flatMap { $0.holdings }

        // Holding.projectedAnnualIncome and Holding.currentValue already return 0
        // for holdings with no stock, no price, or no dividend schedules.
        let income = allHoldings.reduce(Decimal.zero) { $0 + $1.projectedAnnualIncome }
        let value  = allHoldings.reduce(Decimal.zero) { $0 + $1.currentValue }

        projectedAnnualIncome = income
        monthlyEquivalent     = income / Decimal(12)
        totalMarketValue      = value
        overallYield          = value > 0 ? income / value : nil
    }
}
