import SwiftUI
import SwiftData

// MARK: - IncomeHeroView

struct IncomeHeroView: View {
    let metrics: DashboardMetrics
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            primaryRow
            Divider().padding(.vertical, 14)
            secondaryRow
            refreshRow
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    // MARK: - Rows

    /// Annual income (large) + monthly equivalent side by side.
    private var primaryRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metrics.projectedAnnualIncome, format: .currency(code: "USD"))
                    .font(.largeTitle.bold())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityLabel("Annual income \(metrics.projectedAnnualIncome.formatted(.currency(code: "USD")))")
                Text("Annual Income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 2) {
                Text(metrics.monthlyEquivalent, format: .currency(code: "USD"))
                    .font(.title2.bold())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Monthly income \(metrics.monthlyEquivalent.formatted(.currency(code: "USD")))")
                Text("per month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Portfolio value and yield in equal-width columns.
    private var secondaryRow: some View {
        HStack(spacing: 0) {
            MetricCell(
                label: "Portfolio Value",
                value: metrics.totalMarketValue.formatted(.currency(code: "USD"))
            )
            Divider()
                .frame(height: 36)
                .accessibilityHidden(true)
            MetricCell(
                label: "Overall Yield",
                value: yieldString
            )
        }
    }

    /// Shows a refresh spinner while updating, otherwise a delayed-data notice.
    private var refreshRow: some View {
        Group {
            if isRefreshing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.75)
                    Text("Refreshing…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Refreshing data")
            } else {
                Text("Prices delayed 15 min")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Prices are delayed 15 minutes")
            }
        }
        .frame(height: 20)   // fixed height prevents card from resizing during cross-fade
        .padding(.top, 10)
        .animation(.easeInOut(duration: 0.2), value: isRefreshing)
    }

    // MARK: - Helpers

    private var yieldString: String {
        guard let yield = metrics.overallYield else { return "--" }
        return yield.formatted(.percent.precision(.fractionLength(2)))
    }
}

// MARK: - MetricCell

private struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Previews

#Preview("With data") {
    let container = ModelContainer.preview

    let portfolio = Portfolio(name: "Main")
    container.mainContext.insert(portfolio)

    let stock = Stock(ticker: "AAPL", companyName: "Apple Inc.", currentPrice: 185)
    container.mainContext.insert(stock)

    let schedule = DividendSchedule(
        frequency: .quarterly, amountPerShare: Decimal(string: "0.25")!,
        exDate: .now, payDate: .now, declaredDate: .now, status: .declared
    )
    schedule.stock = stock
    container.mainContext.insert(schedule)

    let holding = Holding(shares: 100, averageCostBasis: 150)
    holding.stock = stock
    holding.portfolio = portfolio
    container.mainContext.insert(holding)

    return IncomeHeroView(
        metrics: DashboardMetrics(portfolios: [portfolio]),
        isRefreshing: false
    )
    .modelContainer(container)
}

#Preview("Refreshing") {
    IncomeHeroView(
        metrics: DashboardMetrics(portfolios: []),
        isRefreshing: true
    )
}

#Preview("Empty") {
    IncomeHeroView(
        metrics: DashboardMetrics(portfolios: []),
        isRefreshing: false
    )
}
