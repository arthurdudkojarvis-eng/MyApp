import SwiftUI

struct YieldOverviewCard: View {
    let holdings: [Holding]

    private var snapshot: YieldSnapshot {
        var totalValue = Decimal.zero
        var totalCost = Decimal.zero
        var totalIncome = Decimal.zero
        var highest: (ticker: String, yield: Double)?
        var lowest: (ticker: String, yield: Double)?

        // Merge by ticker to avoid duplicates across portfolios
        var byTicker: [String: (value: Decimal, cost: Decimal, income: Decimal, yield: Double)] = [:]
        for holding in holdings {
            let ticker = holding.stock?.ticker ?? "—"
            let value = holding.currentValue
            let cost = holding.averageCostBasis * holding.shares
            let income = holding.projectedAnnualIncome
            let yld = NSDecimalNumber(decimal: holding.currentYield).doubleValue

            if var existing = byTicker[ticker] {
                existing.value += value
                existing.cost += cost
                existing.income += income
                byTicker[ticker] = existing
            } else {
                byTicker[ticker] = (value: value, cost: cost, income: income, yield: yld)
            }
        }

        for (ticker, data) in byTicker {
            totalValue += data.value
            totalCost += data.cost
            totalIncome += data.income

            if data.yield > 0 {
                if highest == nil || data.yield > highest!.yield {
                    highest = (ticker, data.yield)
                }
                if lowest == nil || data.yield < lowest!.yield {
                    lowest = (ticker, data.yield)
                }
            }
        }

        let currentYield: Double = totalValue > 0
            ? NSDecimalNumber(decimal: totalIncome / totalValue * 100).doubleValue
            : 0
        let yieldOnCost: Double = totalCost > 0
            ? NSDecimalNumber(decimal: totalIncome / totalCost * 100).doubleValue
            : 0

        return YieldSnapshot(
            currentYield: currentYield,
            yieldOnCost: yieldOnCost,
            highest: highest,
            lowest: lowest
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            let snap = snapshot

            // Main yields
            HStack(spacing: 0) {
                YieldMetric(
                    label: "Current Yield",
                    value: String(format: "%.2f%%", snap.currentYield),
                    color: Color.accentColor
                )
                Divider()
                    .frame(height: 36)
                YieldMetric(
                    label: "Yield on Cost",
                    value: String(format: "%.2f%%", snap.yieldOnCost),
                    color: snap.yieldOnCost > snap.currentYield ? .green : .secondary
                )
            }

            if snap.highest != nil || snap.lowest != nil {
                Divider()

                HStack(spacing: 0) {
                    if let high = snap.highest {
                        YieldMetric(
                            label: "Highest",
                            value: "\(high.ticker) \(String(format: "%.1f%%", high.yield))",
                            color: high.yield > 8 ? .red : (high.yield > 4 ? .orange : .green)
                        )
                    }
                    if snap.highest != nil && snap.lowest != nil {
                        Divider()
                            .frame(height: 36)
                    }
                    if let low = snap.lowest {
                        YieldMetric(
                            label: "Lowest",
                            value: "\(low.ticker) \(String(format: "%.1f%%", low.yield))",
                            color: .green
                        )
                    }
                }
            }
        }
        .dashboardCard()
    }
}

// MARK: - Subviews

private struct YieldMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data Model

private struct YieldSnapshot {
    let currentYield: Double
    let yieldOnCost: Double
    let highest: (ticker: String, yield: Double)?
    let lowest: (ticker: String, yield: Double)?
}
