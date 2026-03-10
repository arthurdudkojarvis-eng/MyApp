import SwiftUI
import Charts

struct DividendGrowthCard: View {
    let holdings: [Holding]

    private var monthlyTotals: [MonthTotal] {
        let calendar = Calendar.current
        let now = Date.now

        // Collect all dividend payments across all holdings
        var byMonth: [DateComponents: Decimal] = [:]
        for holding in holdings {
            for payment in holding.dividendPayments {
                let comps = calendar.dateComponents([.year, .month], from: payment.receivedDate)
                byMonth[comps, default: 0] += payment.totalAmount
            }
        }

        // Build last 6 months
        return (0..<6).reversed().map { offset in
            let date = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            let comps = calendar.dateComponents([.year, .month], from: date)
            let amount = byMonth[comps] ?? 0
            return MonthTotal(
                offset: -offset,
                label: date.formatted(.dateTime.month(.abbreviated)),
                amount: amount
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let data = monthlyTotals
            let totalReceived = data.reduce(Decimal.zero) { $0 + $1.amount }

            if totalReceived == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.forward")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No dividend payments recorded yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Trend indicator
                let recent3 = data.suffix(3).reduce(Decimal.zero) { $0 + $1.amount }
                let older3 = data.prefix(3).reduce(Decimal.zero) { $0 + $1.amount }
                let trend: TrendDirection = older3 == 0
                    ? (recent3 > 0 ? .up : .flat)
                    : (recent3 > older3 ? .up : (recent3 < older3 ? .down : .flat))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("6-Month Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(totalReceived, format: .currency(code: "USD"))
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: trend.icon)
                            .font(.caption.bold())
                        Text(trend.label)
                            .font(.caption.bold())
                    }
                    .foregroundStyle(trend.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(trend.color.opacity(0.12))
                    )
                }

                // Sparkline chart
                Chart(data) { item in
                    BarMark(
                        x: .value("Month", item.label),
                        y: .value("Income", item.doubleAmount)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.6).gradient)
                    .cornerRadius(3)
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .frame(height: 80)
            }
        }
        .dashboardCard()
    }
}

// MARK: - Data Models

private struct MonthTotal: Identifiable {
    let offset: Int
    let label: String
    let amount: Decimal

    var id: Int { offset }
    var doubleAmount: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

private enum TrendDirection {
    case up, down, flat

    var icon: String {
        switch self {
        case .up:   return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .up:   return "Growing"
        case .down: return "Declining"
        case .flat: return "Steady"
        }
    }

    var color: Color {
        switch self {
        case .up:   return .green
        case .down: return .red
        case .flat: return .secondary
        }
    }
}
