import SwiftUI

struct ConcentrationRiskCard: View {
    let holdings: [Holding]
    let totalMarketValue: Decimal

    private var topHoldings: [ConcentrationEntry] {
        // Merge by ticker across portfolios
        var byTicker: [String: Decimal] = [:]
        for holding in holdings {
            let ticker = holding.stock?.ticker ?? "—"
            byTicker[ticker, default: 0] += holding.currentValue
        }

        let sorted = byTicker
            .map { ConcentrationEntry(ticker: $0.key, value: $0.value, total: totalMarketValue) }
            .sorted { $0.value > $1.value }

        return Array(sorted.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let entries = topHoldings

            if entries.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "circle.grid.3x3")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No holdings to analyze")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Stacked bar showing concentration
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(colorForIndex(index).gradient)
                                .frame(width: max(4, geo.size.width * entry.fraction))
                        }
                        let top3Fraction = entries.prefix(3).reduce(0.0) { $0 + $1.fraction }
                        if top3Fraction < 1.0 {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        }
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())

                // Top holdings list
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(index < 3 ? colorForIndex(index) : Color(.tertiarySystemFill))
                            .frame(width: 8, height: 8)

                        Text(entry.ticker)
                            .font(.subheadline.bold())
                            .frame(width: 52, alignment: .leading)

                        Spacer()

                        Text(entry.value, format: .currency(code: "USD"))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        Text(entry.percentString)
                            .font(.caption.bold())
                            .monospacedDigit()
                            .foregroundStyle(entry.pct > 30 ? .orange : .primary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                // Risk indicator
                let topPct = entries.first?.pct ?? 0
                if topPct > 30 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Top holding is \(String(format: "%.0f", topPct))% of portfolio")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                }
            }
        }
        .dashboardCard()
    }

    private func colorForIndex(_ index: Int) -> Color {
        [Color.accentColor, .green, .orange][index % 3]
    }
}

// MARK: - Data Model

private struct ConcentrationEntry: Identifiable {
    let ticker: String
    let value: Decimal
    let pct: Double
    let fraction: CGFloat
    let percentString: String

    var id: String { ticker }

    init(ticker: String, value: Decimal, total: Decimal) {
        self.ticker = ticker
        self.value = value
        let p = total > 0 ? NSDecimalNumber(decimal: value / total * 100).doubleValue : 0
        self.pct = p
        self.fraction = CGFloat(total > 0 ? NSDecimalNumber(decimal: value / total).doubleValue : 0)
        self.percentString = String(format: "%.1f%%", p)
    }
}
