import SwiftUI

struct PortfolioPerformanceCard: View {
    let metrics: DashboardMetrics

    var body: some View {
        VStack(spacing: 12) {
            // Top row: Total Value | Total Cost
            HStack(spacing: 0) {
                MetricColumn(
                    label: "Total Value",
                    value: metrics.totalMarketValue.formatted(.currency(code: "USD"))
                )
                Divider()
                    .frame(height: 36)
                MetricColumn(
                    label: "Total Cost",
                    value: metrics.totalCostBasis.formatted(.currency(code: "USD"))
                )
            }

            Divider()

            // Bottom row: Unrealized Gain
            HStack {
                Text("Unrealized Gain")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(metrics.totalUnrealizedGain, format: .currency(code: "USD"))
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(gainColor)
                    if let pct = metrics.totalUnrealizedGainPercent {
                        Text(formattedPercent(pct))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(gainColor)
                    }
                }
            }
        }
        .dashboardCard()
    }

    private var gainColor: Color {
        if metrics.totalUnrealizedGain > 0 { return .green }
        if metrics.totalUnrealizedGain < 0 { return .red }
        return .secondary
    }

    private func formattedPercent(_ value: Decimal) -> String {
        let d = NSDecimalNumber(decimal: value).doubleValue
        let sign = d >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", d))%"
    }
}

// MARK: - Metric Column

private struct MetricColumn: View {
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
    }
}
