import SwiftUI

struct UpcomingDividendsCard: View {
    let holdings: [Holding]

    private var upcomingPayments: [UpcomingPayment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var payments: [UpcomingPayment] = []
        for holding in holdings {
            guard let stock = holding.stock else { continue }
            let upcoming = stock.dividendSchedules.filter { $0.isUpcoming }
            for schedule in upcoming {
                let payment = schedule.amountPerShare * holding.shares
                let payDay = calendar.startOfDay(for: schedule.payDate)
                let days = calendar.dateComponents([.day], from: today, to: payDay).day ?? 0
                payments.append(UpcomingPayment(
                    ticker: stock.ticker,
                    amount: payment,
                    daysUntil: max(0, days),
                    isDeclared: schedule.isDeclared
                ))
            }
        }
        return Array(payments.sorted { $0.daysUntil < $1.daysUntil }.prefix(5))
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
                        Text(payment.ticker)
                            .font(.subheadline.bold())
                            .frame(width: 52, alignment: .leading)

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
    let amount: Decimal
    let daysUntil: Int
    let isDeclared: Bool

    var id: String { "\(ticker)-\(daysUntil)" }
}
