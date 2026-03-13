import SwiftUI

struct IncomeFrequencyCard: View {
    let holdings: [Holding]

    private var breakdown: [FrequencyBucket] {
        // Deduplicate by ticker — use the frequency from the stock's anchor schedule
        var byTicker: [String: DividendFrequency] = [:]
        for holding in holdings {
            guard let stock = holding.stock,
                  let schedule = stock.dividendSchedules.first else { continue }
            byTicker[stock.ticker] = schedule.frequency
        }

        var counts: [DividendFrequency: Int] = [:]
        for freq in byTicker.values {
            counts[freq, default: 0] += 1
        }

        let total = counts.values.reduce(0, +)
        return DividendFrequency.allCases.compactMap { freq in
            guard let count = counts[freq], count > 0 else { return nil }
            return FrequencyBucket(
                frequency: freq,
                count: count,
                fraction: total > 0 ? Double(count) / Double(total) : 0
            )
        }
        .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let buckets = breakdown
            if buckets.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No dividend schedules yet")
                        .textStyle(.controlLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(buckets) { bucket in
                    HStack(spacing: 10) {
                        Image(systemName: bucket.icon)
                            .font(.caption)
                            .foregroundStyle(bucket.color)
                            .frame(width: 20)

                        Text(bucket.label)
                            .font(.subheadline)
                            .frame(width: 90, alignment: .leading)

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(bucket.color.opacity(0.15))
                                .frame(height: 6)
                            GeometryReader { geo in
                                Capsule()
                                    .fill(bucket.color.gradient)
                                    .frame(width: geo.size.width * bucket.fraction, height: 6)
                            }
                            .frame(height: 6)
                        }

                        Text("\(bucket.count)")
                            .textStyle(.statValue)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .dashboardCard()
    }
}

// MARK: - Data Model

private struct FrequencyBucket: Identifiable {
    let frequency: DividendFrequency
    let count: Int
    let fraction: Double

    var id: String { frequency.rawValue }

    var label: String { frequency.rawValue }

    var icon: String {
        switch frequency {
        case .monthly:    return "arrow.clockwise"
        case .quarterly:  return "calendar"
        case .semiAnnual: return "calendar.badge.clock"
        case .annual:     return "calendar.circle"
        }
    }

    var color: Color {
        switch frequency {
        case .monthly:    return .green
        case .quarterly:  return .blue
        case .semiAnnual: return .orange
        case .annual:     return .purple
        }
    }
}
