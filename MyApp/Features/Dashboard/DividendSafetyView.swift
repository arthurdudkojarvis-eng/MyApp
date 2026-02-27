import SwiftUI
import SwiftData

struct DividendSafetyView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    private var allHoldings: [Holding] {
        portfolios.flatMap(\.holdings)
            .filter { $0.stock != nil }
            .sorted { ($0.stock?.ticker ?? "") < ($1.stock?.ticker ?? "") }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if allHoldings.isEmpty {
                    ContentUnavailableView(
                        "No Holdings",
                        systemImage: "shield.lefthalf.filled",
                        description: Text("Add holdings to see dividend safety analysis.")
                    )
                    .padding(.top, 60)
                } else {
                    legendCard
                    holdingsList
                    disclaimerCard
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dividend Safety")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var legendCard: some View {
        HStack(spacing: 16) {
            riskLabel(color: .green, text: "Conservative (<4%)")
            riskLabel(color: .yellow, text: "Moderate (4–8%)")
            riskLabel(color: .red, text: "High (>8%)")
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func riskLabel(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var holdingsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(allHoldings, id: \.id) { holding in
                SafetyRow(holding: holding)
                if holding.id != allHoldings.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Risk level is estimated from current dividend yield on market price. High-yield stocks may indicate elevated cut risk. Always research fundamentals including payout ratio and earnings coverage.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Safety Row

private struct SafetyRow: View {
    let holding: Holding

    private var ticker: String { holding.stock?.ticker ?? "—" }
    private var name: String { holding.stock?.companyName ?? "" }
    private var yieldOnCost: Decimal { holding.yieldOnCost }
    private var currentYield: Decimal { holding.currentYield }
    private var paymentCount: Int { holding.dividendPayments.count }

    private var riskLevel: RiskLevel {
        let y = (currentYield as NSDecimalNumber).doubleValue
        if y == 0 { return .unknown }
        if y > 8 { return .high }
        if y > 4 { return .moderate }
        return .conservative
    }

    var body: some View {
        HStack(spacing: 12) {
            riskDot
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker).font(.headline)
                if !name.isEmpty {
                    Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                metricRow(label: "Yield", value: yieldString(currentYield))
                metricRow(label: "YoC", value: yieldString(yieldOnCost))
                metricRow(label: "Payments", value: "\(paymentCount)")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ticker), current yield \(yieldString(currentYield)), yield on cost \(yieldString(yieldOnCost)), \(paymentCount) payments received")
    }

    private var riskDot: some View {
        Circle()
            .fill(riskLevel.color)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
        }
    }

    private func yieldString(_ decimal: Decimal) -> String {
        let d = (decimal as NSDecimalNumber).doubleValue
        if d == 0 { return "—" }
        return String(format: "%.2f%%", d)
    }
}

// MARK: - Risk Level

private enum RiskLevel {
    case conservative, moderate, high, unknown

    var color: Color {
        switch self {
        case .conservative: return .green
        case .moderate:     return .yellow
        case .high:         return .red
        case .unknown:      return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        DividendSafetyView()
    }
    .modelContainer(container)
    .environment(settings)
}
