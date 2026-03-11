import SwiftUI

struct UpcomingDividendsCard: View {
    let holdings: [Holding]

    @Environment(\.massiveService) private var massive

    private var upcomingPayments: [UpcomingPayment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Merge same ticker + same pay date across portfolios
        var merged: [String: UpcomingPayment] = [:]
        for holding in holdings {
            guard let stock = holding.stock else { continue }
            for schedule in stock.dividendSchedules where schedule.isUpcoming {
                let payment = schedule.amountPerShare * holding.shares
                let payDay = calendar.startOfDay(for: schedule.payDate)
                let days = max(0, calendar.dateComponents([.day], from: today, to: payDay).day ?? 0)
                let key = "\(stock.ticker)-\(days)"

                if var existing = merged[key] {
                    existing.amount += payment
                    if schedule.isDeclared { existing.isDeclared = true }
                    merged[key] = existing
                } else {
                    merged[key] = UpcomingPayment(
                        ticker: stock.ticker,
                        amount: payment,
                        daysUntil: days,
                        isDeclared: schedule.isDeclared
                    )
                }
            }
        }
        return Array(merged.values.sorted { $0.daysUntil < $1.daysUntil }.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if upcomingPayments.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No upcoming dividends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(upcomingPayments) { payment in
                    HStack(spacing: 8) {
                        CompanyLogoView(
                            branding: nil,
                            ticker: payment.ticker,
                            service: massive.service,
                            size: 22
                        )

                        Text(payment.ticker)
                            .font(.subheadline.bold())
                            .frame(width: 48, alignment: .leading)

                        Text(payment.isDeclared ? "Declared" : "Estimated")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(
                                    (payment.isDeclared ? Color.green : Color.orange).opacity(0.15)
                                )
                            )
                            .foregroundStyle(payment.isDeclared ? .green : .orange)

                        Spacer()

                        Text(payment.amount, format: .currency(code: "USD"))
                            .font(.subheadline.bold())
                            .monospacedDigit()

                        Text("in \(payment.daysUntil)d")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .dashboardCard()
    }
}

// MARK: - Data Model

private struct UpcomingPayment: Identifiable {
    let ticker: String
    var amount: Decimal
    let daysUntil: Int
    var isDeclared: Bool

    var id: String { "\(ticker)-\(daysUntil)" }
}
