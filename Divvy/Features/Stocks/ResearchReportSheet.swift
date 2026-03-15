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
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    if let target = data.priceTarget, let price = data.currentPrice {
                        priceTargetSection(target: target, currentPrice: price)
                    }
                    if let target = data.priceTarget {
                        bearCaseSection(target: target)
                        bullCaseSection(target: target)
                    }
                    riskFactorsSection
                    disclaimerFooter
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(data.ticker) Research")
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
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.ticker)
                    .font(.title2.bold())
                Spacer()
                Text(Self.displayDateFormatter.string(from: data.generatedAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !data.companyName.isEmpty {
                Text(data.companyName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                if let cap = data.marketCap {
                    Text("Mkt Cap: $\(formatMarketCap(cap))")
                }
                if let rev = data.revenue {
                    Text("Rev: $\(formatMarketCap(rev))")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Price Target

    private func priceTargetSection(target: FinnhubPriceTarget, currentPrice: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(formatCurrency(currentPrice))
                    .font(.largeTitle.bold())

                if currentPrice > 0 {
                    let pct = ((target.targetMean - currentPrice) / currentPrice) * 100
                    let pctValue = (pct as NSDecimalNumber).doubleValue
                    let isUpside = pctValue >= 0
                    Text("\(isUpside ? "+" : "")\(String(format: "%.1f", pctValue))% to consensus")
                        .font(.caption.bold())
                        .foregroundStyle(isUpside ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isUpside ? Color.green : Color.red).opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            let isSingleEstimate = target.targetHigh == target.targetLow

            if isSingleEstimate {
                Text("1 analyst estimate — \(formatCurrency(target.targetMean))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Gradient bar with circle marker and current price tooltip
                GeometryReader { geo in
                    let barWidth = geo.size.width
                    let pos = tickPosition(
                        current: currentPrice,
                        low: target.targetLow,
                        high: target.targetHigh
                    )
                    let markerX = pos * barWidth

                    VStack(spacing: 4) {
                        // Current price tooltip above marker
                        Text(formatCurrency(currentPrice))
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .position(x: markerX, y: 10)

                        ZStack(alignment: .leading) {
                            // Gradient bar
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .yellow, .green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 12)

                            // White circle marker
                            Circle()
                                .fill(.white)
                                .frame(width: 16, height: 16)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                .position(x: markerX, y: 6)
                        }
                        .frame(height: 16)
                    }
                }
                .frame(height: 40)

                // BEAR / TARGET / BULL labels
                HStack(alignment: .top) {
                    targetLabel(title: "BEAR", price: target.targetLow, color: .red)
                    Spacer()
                    targetLabel(title: "TARGET", price: target.targetMean, color: .blue)
                    Spacer()
                    targetLabel(title: "BULL", price: target.targetHigh, color: .green, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func targetLabel(title: String, price: Decimal, color: Color, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            Text(formatCurrency(price))
                .font(.caption2.bold())
        }
    }

    private func tickPosition(current: Decimal, low: Decimal, high: Decimal) -> CGFloat {
        let range = high - low
        guard range > 0 else { return 0.5 }
        let raw = (current - low) / range
        let clamped = min(max(raw, 0), 1)
        return CGFloat((clamped as NSDecimalNumber).doubleValue)
    }

    // MARK: - Bear Case

    private func bearCaseSection(target: FinnhubPriceTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("BEAR CASE")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            Text(formatCurrency(target.targetLow))
                .font(.title2.bold())

            if let date = Self.dateFormatter.date(from: target.lastUpdated) {
                Text("Updated \(Self.displayDateFormatter.string(from: date))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

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
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Bull Case

    private func bullCaseSection(target: FinnhubPriceTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("BULL CASE")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }

            Text(formatCurrency(target.targetHigh))
                .font(.title2.bold())

            if let date = Self.dateFormatter.date(from: target.lastUpdated) {
                Text("Updated \(Self.displayDateFormatter.string(from: date))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

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
        .background(Color.green.opacity(0.12))
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
