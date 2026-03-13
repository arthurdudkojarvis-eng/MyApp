import SwiftUI

struct HealthScoreCard: View {
    let holdings: [Holding]
    let metrics: DashboardMetrics

    @State private var animateRing = false

    private var score: HealthScore {
        // 1. Yield Score (0-100): target 2-6% average yield on cost
        let yocValues = holdings.compactMap { h -> Double? in
            let yoc = NSDecimalNumber(decimal: h.yieldOnCost).doubleValue
            return yoc > 0 ? yoc : nil
        }
        let avgYoC = yocValues.isEmpty ? 0 : yocValues.reduce(0, +) / Double(yocValues.count)
        let yieldScore: Int
        if avgYoC == 0 {
            yieldScore = 0
        } else if avgYoC >= 2 && avgYoC <= 6 {
            yieldScore = 100
        } else if avgYoC < 2 {
            yieldScore = Int(avgYoC / 2 * 100)
        } else {
            // >6%: gradually penalize
            yieldScore = max(20, Int(100 - (avgYoC - 6) * 10))
        }

        // 2. Diversification Score (0-100): unique tickers, 10-30 is ideal
        let uniqueTickers = Set(holdings.compactMap { $0.stock?.ticker }).count
        let diversScore: Int
        if uniqueTickers == 0 {
            diversScore = 0
        } else if uniqueTickers >= 10 && uniqueTickers <= 30 {
            diversScore = 100
        } else if uniqueTickers < 10 {
            diversScore = uniqueTickers * 10
        } else {
            diversScore = max(70, 100 - (uniqueTickers - 30) * 2)
        }

        // 3. Performance Score (0-100): unrealized gain %
        let gainPct: Double
        if let pct = metrics.totalUnrealizedGainPercent {
            gainPct = NSDecimalNumber(decimal: pct).doubleValue
        } else {
            gainPct = 0
        }
        let perfScore: Int
        if gainPct >= 10 {
            perfScore = 100
        } else if gainPct >= 0 {
            perfScore = 50 + Int(gainPct * 5)
        } else if gainPct >= -20 {
            perfScore = max(10, 50 + Int(gainPct * 2))
        } else {
            perfScore = 10
        }

        // 4. Income Consistency Score (0-100): based on payment count
        let totalPayments = holdings.reduce(0) { $0 + $1.dividendPayments.count }
        let consistencyScore = min(100, totalPayments * 5)

        // Weighted average
        let total = Double(yieldScore) * 0.3
            + Double(diversScore) * 0.25
            + Double(perfScore) * 0.25
            + Double(consistencyScore) * 0.2
        let finalScore = Int(total.rounded())

        return HealthScore(
            overall: finalScore,
            yieldScore: yieldScore,
            diversificationScore: diversScore,
            performanceScore: perfScore,
            consistencyScore: consistencyScore
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            if holdings.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("Add holdings to see health score")
                        .textStyle(.controlLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let s = score

                HStack(spacing: 16) {
                    // Main ring
                    ZStack {
                        Circle()
                            .stroke(Color(.tertiarySystemFill), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: animateRing ? CGFloat(s.overall) / 100 : 0)
                            .stroke(
                                scoreColor(s.overall),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animateRing)

                        VStack(spacing: 0) {
                            Text("\(s.overall)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(scoreColor(s.overall))
                            Text("/ 100")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 68, height: 68)

                    // Component breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        ScoreRow(label: "Yield", score: s.yieldScore, color: scoreColor(s.yieldScore))
                        ScoreRow(label: "Diversity", score: s.diversificationScore, color: scoreColor(s.diversificationScore))
                        ScoreRow(label: "Gain", score: s.performanceScore, color: scoreColor(s.performanceScore))
                        ScoreRow(label: "Consistency", score: s.consistencyScore, color: scoreColor(s.consistencyScore))
                    }
                }
                .onAppear { animateRing = true }
                .onDisappear { animateRing = false }
            }
        }
        .dashboardCard()
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        if score >= 40 { return .yellow }
        return .red
    }
}

// MARK: - Score Row

private struct ScoreRow: View {
    let label: String
    let score: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .textStyle(.statLabel)
                .frame(width: 68, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 4)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 4)
                }
            }
            .frame(height: 4)
            Text("\(score)")
                .textStyle(.badge)
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

// MARK: - Data Model

private struct HealthScore {
    let overall: Int
    let yieldScore: Int
    let diversificationScore: Int
    let performanceScore: Int
    let consistencyScore: Int
}
