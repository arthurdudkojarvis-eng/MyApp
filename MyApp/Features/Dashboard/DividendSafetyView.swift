import SwiftUI
import SwiftData

private let posixLocale = Locale(identifier: "en_US_POSIX")

struct DividendSafetyView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.massiveService) private var massive

    @State private var sortOrder: SortOrder = .risk
    @State private var animateBars = false

    // MARK: - Snapshot (computed once per render)

    private var snapshot: SafetySnapshot {
        let holdings = portfolios.flatMap(\.holdings).filter { $0.stock != nil }
        var assessments: [HoldingAssessment] = []
        var riskCounts: [RiskLevel: Int] = [.conservative: 0, .moderate: 0, .high: 0, .unknown: 0]
        var riskValues: [RiskLevel: Decimal] = [.conservative: 0, .moderate: 0, .high: 0, .unknown: 0]
        var totalValue: Decimal = 0
        var yieldSum = 0.0
        var yieldCount = 0
        var highestYield: HoldingAssessment?
        var lowestYield: HoldingAssessment?

        for holding in holdings {
            let currentYield = (holding.currentYield as NSDecimalNumber).doubleValue
            let yieldOnCost = (holding.yieldOnCost as NSDecimalNumber).doubleValue
            let value = holding.currentValue
            let risk = RiskLevel.from(yield: currentYield)

            let assessment = HoldingAssessment(
                holdingID: holding.id,
                ticker: holding.stock?.ticker ?? "—",
                companyName: holding.stock?.companyName ?? "",
                currentYield: currentYield,
                yieldOnCost: yieldOnCost,
                currentValue: value,
                projectedAnnualIncome: holding.projectedAnnualIncome,
                paymentCount: holding.dividendPayments.count,
                risk: risk
            )
            assessments.append(assessment)

            riskCounts[risk, default: 0] += 1
            riskValues[risk, default: 0] += value
            totalValue += value

            if currentYield > 0 {
                yieldSum += currentYield
                yieldCount += 1
                if highestYield.map({ currentYield > $0.currentYield }) ?? true {
                    highestYield = assessment
                }
                if lowestYield.map({ currentYield < $0.currentYield }) ?? true {
                    lowestYield = assessment
                }
            }
        }

        // Sort assessments
        let sorted: [HoldingAssessment]
        switch sortOrder {
        case .risk:
            sorted = assessments.sorted { $0.risk.sortKey < $1.risk.sortKey || ($0.risk == $1.risk && $0.currentYield > $1.currentYield) }
        case .yield:
            sorted = assessments.sorted { $0.currentYield > $1.currentYield }
        case .value:
            sorted = assessments.sorted { $0.currentValue > $1.currentValue }
        case .ticker:
            sorted = assessments.sorted { $0.ticker < $1.ticker }
        }

        // Portfolio safety score (0-100, weighted by position value)
        // Conservative = 100, Moderate = 60, High = 20, Unknown = 50
        let score: Int
        if totalValue > 0 {
            let weighted =
                ((riskValues[.conservative] ?? 0) as NSDecimalNumber).doubleValue * 100 +
                ((riskValues[.moderate] ?? 0) as NSDecimalNumber).doubleValue * 60 +
                ((riskValues[.high] ?? 0) as NSDecimalNumber).doubleValue * 20 +
                ((riskValues[.unknown] ?? 0) as NSDecimalNumber).doubleValue * 50
            score = Int((weighted / (totalValue as NSDecimalNumber).doubleValue).rounded())
        } else {
            score = 0
        }

        let avgYield = yieldCount > 0 ? yieldSum / Double(yieldCount) : 0

        // Risk distribution slices
        let distribution: [RiskSlice] = RiskLevel.allDisplayed.compactMap { level in
            let count = riskCounts[level] ?? 0
            guard count > 0 else { return nil }
            return RiskSlice(
                risk: level,
                count: count,
                value: riskValues[level] ?? 0,
                fraction: totalValue > 0
                    ? CGFloat((((riskValues[level] ?? 0) / totalValue) as NSDecimalNumber).doubleValue)
                    : 0
            )
        }

        return SafetySnapshot(
            assessments: sorted,
            safetyScore: score,
            averageYield: avgYield,
            totalValue: totalValue,
            highestYield: highestYield,
            lowestYield: lowestYield,
            distribution: distribution
        )
    }

    var body: some View {
        let snap = snapshot
        ScrollView {
            VStack(spacing: 16) {
                if snap.assessments.isEmpty {
                    ContentUnavailableView {
                        Label("No Holdings", systemImage: "shield.lefthalf.filled")
                            .symbolRenderingMode(.hierarchical)
                    } description: {
                        Text("Add holdings to a portfolio to see dividend safety analysis.")
                    }
                    .padding(.top, 60)
                } else {
                    scoreCard(snap)
                    distributionCard(snap)
                    holdingsCard(snap)
                    disclaimerCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dividend Safety")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Safety Score Card

    private func scoreCard(_ snap: SafetySnapshot) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Portfolio Safety Score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(snap.safetyScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(scoreColor(snap.safetyScore))
                        Text("/ 100")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(scoreLabel(snap.safetyScore))
                        .font(.caption)
                        .foregroundStyle(scoreColor(snap.safetyScore))
                }
                Spacer()

                // Circular gauge
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 8)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: animateBars ? CGFloat(snap.safetyScore) / 100 : 0)
                        .stroke(
                            scoreColor(snap.safetyScore),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animateBars)
                    Image(systemName: scoreIcon(snap.safetyScore))
                        .font(.title3)
                        .foregroundStyle(scoreColor(snap.safetyScore))
                }
            }

            Divider()

            // Quick stats
            HStack(spacing: 0) {
                QuickStat(
                    label: "Avg Yield",
                    value: String(format: "%.2f%%", locale: posixLocale, snap.averageYield),
                    color: RiskLevel.from(yield: snap.averageYield).color
                )
                Spacer()
                if let highest = snap.highestYield {
                    QuickStat(
                        label: "Highest",
                        value: "\(highest.ticker) \(String(format: "%.1f%%", locale: posixLocale, highest.currentYield))",
                        color: highest.risk.color
                    )
                }
                Spacer()
                if let lowest = snap.lowestYield {
                    QuickStat(
                        label: "Lowest",
                        value: "\(lowest.ticker) \(String(format: "%.1f%%", locale: posixLocale, lowest.currentYield))",
                        color: lowest.risk.color
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .onAppear {
            guard !animateBars else { return }
            animateBars = true
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        if score >= 40 { return .yellow }
        return .red
    }

    private func scoreLabel(_ score: Int) -> String {
        if score >= 80 { return "Conservative Portfolio" }
        if score >= 60 { return "Moderately Safe" }
        if score >= 40 { return "Mixed Risk" }
        return "Elevated Risk"
    }

    private func scoreIcon(_ score: Int) -> String {
        if score >= 80 { return "shield.checkmark.fill" }
        if score >= 60 { return "shield.lefthalf.filled" }
        if score >= 40 { return "shield" }
        return "exclamationmark.shield.fill"
    }

    // MARK: - Risk Distribution Card

    private func distributionCard(_ snap: SafetySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risk Distribution")
                .font(.headline)

            // Stacked horizontal bar
            if !snap.distribution.isEmpty {
                GeometryReader { geo in
                    let spacing: CGFloat = 2
                    let totalSpacing = spacing * CGFloat(max(0, snap.distribution.count - 1))
                    let available = geo.size.width - totalSpacing
                    HStack(spacing: spacing) {
                        ForEach(snap.distribution) { slice in
                            let width = max(4, available * slice.fraction)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(slice.risk.color.gradient)
                                .frame(width: animateBars ? width : 4)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.8),
                                    value: animateBars
                                )
                        }
                    }
                }
                .frame(height: 14)
                .clipShape(Capsule())
            }

            // Legend with counts
            HStack(spacing: 16) {
                ForEach(snap.distribution) { slice in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(slice.risk.color)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(slice.risk.label)
                                .font(.caption2.bold())
                            Text("\(slice.count) holding\(slice.count == 1 ? "" : "s")")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Holdings Card

    private func holdingsCard(_ snap: SafetySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with sort control
            HStack {
                Text("Holdings")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sortOrder = order
                            }
                        } label: {
                            if sortOrder == order {
                                Label(order.label, systemImage: "checkmark")
                            } else {
                                Text(order.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(sortOrder.label)
                            .font(.caption)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)

            ForEach(Array(snap.assessments.enumerated()), id: \.element.id) { index, assessment in
                SafetyRowView(
                    assessment: assessment,
                    maxYield: snap.highestYield?.currentYield ?? 1,
                    service: massive.service,
                    animateBars: animateBars,
                    animationDelay: min(Double(index) * 0.04, 0.5)
                )

                if index < snap.assessments.count - 1 {
                    Divider().padding(.leading, 62)
                }
            }
        }
        .padding(.bottom)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Disclaimer

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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Safety Row View

private struct SafetyRowView: View {
    let assessment: HoldingAssessment
    let maxYield: Double
    let service: any MassiveFetching
    let animateBars: Bool
    let animationDelay: Double

    var body: some View {
        HStack(spacing: 10) {
            CompanyLogoView(
                branding: nil,
                ticker: assessment.ticker,
                service: service,
                size: 36
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(assessment.ticker)
                        .font(.headline)
                    riskBadge
                }
                if !assessment.companyName.isEmpty {
                    Text(assessment.companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Yield bar
                let fraction = maxYield > 0 ? CGFloat(assessment.currentYield / maxYield) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(assessment.risk.color.opacity(0.1))
                        .frame(height: 4)
                    Capsule()
                        .fill(assessment.risk.color.gradient)
                        .frame(height: 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(
                            x: animateBars ? fraction : 0,
                            anchor: .leading
                        )
                        .animation(
                            .spring(response: 0.55, dampingFraction: 0.78)
                                .delay(animationDelay),
                            value: animateBars
                        )
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f%%", locale: posixLocale, assessment.currentYield))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(assessment.risk.color)
                HStack(spacing: 2) {
                    Text("YoC")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(assessment.yieldOnCost > 0
                         ? String(format: "%.2f%%", locale: posixLocale, assessment.yieldOnCost)
                         : "—")
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if assessment.paymentCount > 0 {
                    Text("\(assessment.paymentCount) payment\(assessment.paymentCount == 1 ? "" : "s")")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assessment.ticker), \(assessment.risk.label) risk, yield \(String(format: "%.2f", locale: posixLocale, assessment.currentYield)) percent")
    }

    private var riskBadge: some View {
        Text(assessment.risk.shortLabel)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(assessment.risk.color.opacity(0.15))
            )
            .foregroundStyle(assessment.risk.color)
    }
}

// MARK: - Quick Stat

private struct QuickStat: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Data Models

private struct SafetySnapshot {
    let assessments: [HoldingAssessment]
    let safetyScore: Int
    let averageYield: Double
    let totalValue: Decimal
    let highestYield: HoldingAssessment?
    let lowestYield: HoldingAssessment?
    let distribution: [RiskSlice]
}

private struct HoldingAssessment: Identifiable {
    let holdingID: UUID
    let ticker: String
    let companyName: String
    let currentYield: Double
    let yieldOnCost: Double
    let currentValue: Decimal
    let projectedAnnualIncome: Decimal
    let paymentCount: Int
    let risk: RiskLevel

    var id: UUID { holdingID }
}

private struct RiskSlice: Identifiable {
    let risk: RiskLevel
    let count: Int
    let value: Decimal
    let fraction: CGFloat

    var id: String { risk.rawValue }
}

private enum RiskLevel: String, CaseIterable {
    case conservative, moderate, high, unknown

    static let allDisplayed: [RiskLevel] = [.conservative, .moderate, .high]

    static func from(yield: Double) -> RiskLevel {
        if yield == 0 { return .unknown }
        if yield > 8 { return .high }
        if yield > 4 { return .moderate }
        return .conservative
    }

    var color: Color {
        switch self {
        case .conservative: return .green
        case .moderate:     return .yellow
        case .high:         return .red
        case .unknown:      return .gray
        }
    }

    var label: String {
        switch self {
        case .conservative: return "Conservative"
        case .moderate:     return "Moderate"
        case .high:         return "High Risk"
        case .unknown:      return "Unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .conservative: return "Safe"
        case .moderate:     return "Mod"
        case .high:         return "High"
        case .unknown:      return "N/A"
        }
    }

    var sortKey: Int {
        switch self {
        case .high: return 0
        case .moderate: return 1
        case .unknown: return 2
        case .conservative: return 3
        }
    }
}

private enum SortOrder: String, CaseIterable, Identifiable {
    case risk, yield, value, ticker

    var id: String { rawValue }

    var label: String {
        switch self {
        case .risk: return "Risk"
        case .yield: return "Yield"
        case .value: return "Value"
        case .ticker: return "Ticker"
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
