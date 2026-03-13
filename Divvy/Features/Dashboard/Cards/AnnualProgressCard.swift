import SwiftUI

struct AnnualProgressCard: View {
    let holdings: [Holding]

    private var snapshot: ProgressSnapshot {
        let calendar = Calendar.current
        let now = Date.now
        let year = calendar.component(.year, from: now)

        // YTD income from actual dividend payments this year
        var ytdIncome = Decimal.zero
        for holding in holdings {
            for payment in holding.dividendPayments {
                if calendar.component(.year, from: payment.receivedDate) == year {
                    ytdIncome += payment.totalAmount
                }
            }
        }

        // Projected annual income
        let projectedAnnual = holdings.reduce(Decimal.zero) { $0 + $1.projectedAnnualIncome }

        // Progress fraction
        let progress: Double
        if projectedAnnual > 0 {
            progress = min(1.0, NSDecimalNumber(decimal: ytdIncome / projectedAnnual).doubleValue)
        } else {
            progress = 0
        }

        // Days elapsed / remaining
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
        let totalDays = calendar.dateComponents([.day], from: startOfYear, to: endOfYear).day ?? 365
        let elapsedDays = calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 0
        let timeProgress = totalDays > 0 ? Double(elapsedDays) / Double(totalDays) : 0

        return ProgressSnapshot(
            ytdIncome: ytdIncome,
            projectedAnnual: projectedAnnual,
            progress: progress,
            timeProgress: timeProgress,
            daysRemaining: totalDays - elapsedDays
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let snap = snapshot

            // YTD vs Projected
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("YTD Earned")
                        .textStyle(.rowDetail)
                    Text(snap.ytdIncome, format: .currency(code: "USD"))
                        .textStyle(.statValue)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 36)

                VStack(spacing: 4) {
                    Text("Annual Target")
                        .textStyle(.rowDetail)
                    Text(snap.projectedAnnual, format: .currency(code: "USD"))
                        .textStyle(.statValue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(height: 8)

                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.accentColor.gradient)
                            .frame(width: geo.size.width * snap.progress, height: 8)
                    }
                    .frame(height: 8)

                    // Time marker
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(width: 1.5, height: 14)
                            .offset(x: geo.size.width * snap.timeProgress - 0.75)
                    }
                    .frame(height: 14)
                }

                HStack {
                    Text("\(Int(snap.progress * 100))% earned")
                        .textStyle(.badge)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Text("\(snap.daysRemaining)d remaining")
                        .textStyle(.statLabel)
                        .monospacedDigit()
                }
            }
        }
        .dashboardCard()
    }
}

// MARK: - Data Model

private struct ProgressSnapshot {
    let ytdIncome: Decimal
    let projectedAnnual: Decimal
    let progress: Double
    let timeProgress: Double
    let daysRemaining: Int
}
