import SwiftUI

struct TopEarnersCard: View {
    let holdings: [Holding]

    @Environment(\.massiveService) private var massive

    private var topEarners: [MergedEarner] {
        var byTicker: [String: MergedEarner] = [:]
        for holding in holdings {
            let ticker = holding.stock?.ticker ?? "—"
            let income = holding.projectedAnnualIncome
            if var existing = byTicker[ticker] {
                existing.annualIncome += income
                byTicker[ticker] = existing
            } else {
                byTicker[ticker] = MergedEarner(ticker: ticker, annualIncome: income)
            }
        }
        return Array(
            byTicker.values
                .filter { $0.annualIncome > 0 }
                .sorted { $0.annualIncome > $1.annualIncome }
                .prefix(5)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let earners = topEarners
            if earners.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "dollarsign.circle")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No dividend income yet")
                        .textStyle(.controlLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let maxIncome = earners.first?.annualIncome ?? 1

                ForEach(Array(earners.enumerated()), id: \.element.id) { index, earner in
                    HStack(spacing: 8) {
                        CompanyLogoView(
                            branding: nil,
                            ticker: earner.ticker,
                            service: massive.service,
                            size: 22
                        )

                        Text(earner.ticker)
                            .font(.subheadline.bold())
                            .frame(width: 48, alignment: .leading)

                        let fraction = maxIncome > 0
                            ? CGFloat(((earner.annualIncome / maxIncome) as NSDecimalNumber).doubleValue)
                            : 0
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.accentColor.opacity(0.25))
                                .frame(height: 6)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.accentColor.gradient)
                                        .frame(width: geo.size.width * fraction, height: 6)
                                }
                        }
                        .frame(height: 6)

                        Text(earner.annualIncome, format: .currency(code: "USD"))
                            .font(.caption.bold())
                            .monospacedDigit()
                            .frame(minWidth: 60, alignment: .trailing)
                    }
                }
            }
        }
        .dashboardCard()
    }
}

// MARK: - Data Model

private struct MergedEarner: Identifiable {
    let ticker: String
    var annualIncome: Decimal

    var id: String { ticker }
}
