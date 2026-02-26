import SwiftUI

struct DividendCalendarRowView: View {
    let schedule: DividendSchedule

    private var ticker: String      { schedule.stock?.ticker      ?? "—" }
    private var companyName: String { schedule.stock?.companyName ?? "—" }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: ticker + company name
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker)
                    .font(.headline)
                Text(companyName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Right column: pay date / amount / frequency + status dot
            VStack(alignment: .trailing, spacing: 2) {
                Text(schedule.payDate, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)

                Text(schedule.amountPerShare, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(schedule.frequency.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Circle()
                        .fill(schedule.status.calendarColor)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel(schedule.status.rawValue.capitalized)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        let payFormatted = schedule.payDate.formatted(.dateTime.month(.wide).day())
        let amount       = schedule.amountPerShare.formatted(.currency(code: "USD"))
        return "\(ticker), \(companyName), pay date \(payFormatted), \(amount) per share, \(schedule.frequency.rawValue), \(schedule.status.rawValue)"
    }
}

// MARK: - Status color

private extension DividendScheduleStatus {
    var calendarColor: Color {
        switch self {
        case .estimated: return .gray
        case .declared:  return .green
        case .paid:      return .blue
        }
    }
}
