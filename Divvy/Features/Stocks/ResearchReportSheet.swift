import SwiftUI

struct ResearchReportData: Identifiable {
    let id = UUID()
    let ticker: String
    let companyName: String
    let generatedAt: Date
    let marketCap: Decimal?
    let revenue: Decimal?
    let eps: Decimal?
    let currentPrice: Decimal?
    let dividendYield: Decimal?
    let payoutRatio: Decimal?
    let priceTarget: FinnhubPriceTarget?
    let bullPoints: [String]
    let bearPoints: [String]
    let riskFactors: [RiskFactor]
}

struct ResearchReportSheet: View {
    let data: ResearchReportData
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    metricsRow
                    if let target = data.priceTarget, let price = data.currentPrice {
                        priceTargetSection(target: target, currentPrice: price)
                    }
                    bullCaseSection
                    bearCaseSection
                    riskFactorsSection
                    disclaimerFooter
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(data.ticker)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.blue)
                .clipShape(Capsule())

            if !data.companyName.isEmpty {
                Text(data.companyName)
                    .font(.title2.bold())
            }

            Text("AI Research Report")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Generated \(Self.dateFormatter.string(from: data.generatedAt))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Key Metrics

    private var metricsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let cap = data.marketCap {
                    metricCapsule("Mkt Cap", formatMarketCap(cap))
                }
                if let rev = data.revenue {
                    metricCapsule("Revenue", formatMarketCap(rev))
                }
                if let eps = data.eps {
                    metricCapsule("EPS", formatCurrency(eps))
                }
                if let yield = data.dividendYield {
                    metricCapsule("Yield", formatPercent(yield))
                }
                if let payout = data.payoutRatio {
                    metricCapsule("Payout", formatPercent(payout))
                }
            }
        }
    }

    private func metricCapsule(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Price Target

    private func priceTargetSection(target: FinnhubPriceTarget, currentPrice: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price Target").textStyle(.sectionTitle)

            let isSingleEstimate = target.targetHigh == target.targetLow

            if isSingleEstimate {
                Text(formatCurrency(target.targetMean))
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                Text("1 analyst estimate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                // Mean label above bar
                Text(formatCurrency(target.targetMean))
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)

                // Gradient bar with current price tick
                GeometryReader { geo in
                    let barWidth = geo.size.width
                    let tickPos = tickPosition(
                        current: currentPrice,
                        low: target.targetLow,
                        high: target.targetHigh
                    )

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.red, .gray, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 12)

                        Rectangle()
                            .fill(.primary)
                            .frame(width: 2, height: 20)
                            .offset(x: tickPos * barWidth - 1)
                    }
                }
                .frame(height: 20)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Low")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(target.targetLow))
                            .font(.caption2.bold())
                    }
                    Spacer()
                    VStack {
                        Text("Current")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(currentPrice))
                            .font(.caption2.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("High")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(target.targetHigh))
                            .font(.caption2.bold())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tickPosition(current: Decimal, low: Decimal, high: Decimal) -> CGFloat {
        let range = high - low
        guard range > 0 else { return 0.5 }
        let raw = (current - low) / range
        let clamped = min(max(raw, 0), 1)
        return CGFloat((clamped as NSDecimalNumber).doubleValue)
    }

    // MARK: - Bull Case

    private var bullCaseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bull Case", systemImage: "arrow.up.right")
                .font(.headline)
                .foregroundStyle(.green)

            if data.bullPoints.isEmpty {
                Text("No bull case points available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(data.bullPoints.enumerated()), id: \.offset) { index, point in
                    numberedRow(index + 1, text: point, color: .green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Bear Case

    private var bearCaseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bear Case", systemImage: "arrow.down.right")
                .font(.headline)
                .foregroundStyle(.red)

            if data.bearPoints.isEmpty {
                Text("No bear case points available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(data.bearPoints.enumerated()), id: \.offset) { index, point in
                    numberedRow(index + 1, text: point, color: .red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func numberedRow(_ number: Int, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Risk Factors

    private var riskFactorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Risk Factors").textStyle(.sectionTitle)
                Spacer()
                if !data.riskFactors.isEmpty, let severity = data.riskFactors.map(\.severity).max() {
                    Text("\(data.riskFactors.count) \(severity.label)")
                        .textStyle(.microBadge)
                        .foregroundStyle(severityColor(severity))
                }
            }

            if data.riskFactors.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("No major risks detected")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            } else {
                ForEach(data.riskFactors) { factor in
                    riskRow(factor)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func riskRow(_ factor: RiskFactor) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(factor.severity.label)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(severityColor(factor.severity))
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.title)
                    .font(.subheadline.bold())
                Text(factor.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func severityColor(_ severity: RiskSeverity) -> Color {
        switch severity {
        case .critical: .red
        case .high:     .orange
        case .medium:   .yellow
        case .low:      .green
        }
    }

    // MARK: - Footer

    private var disclaimerFooter: some View {
        Text("AI-generated analysis. Not financial advice.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    // MARK: - Formatters

    private func formatCurrency(_ value: Decimal) -> String {
        value.formatted(.currency(code: "USD"))
    }

    private func formatPercent(_ value: Decimal) -> String {
        let d = (value as NSDecimalNumber).doubleValue
        return String(format: "%.1f%%", d)
    }
}
