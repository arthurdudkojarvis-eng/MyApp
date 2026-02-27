import SwiftUI
import SwiftData
import Charts

struct IncomeForecastView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    private var allHoldings: [Holding] { portfolios.flatMap(\.holdings) }

    private var forecastData: [MonthForecast] {
        let calendar = Calendar.current
        let monthStart = calendar.startOfMonth(for: .now)

        return (0..<12).map { offset in
            let date = calendar.date(byAdding: .month, value: offset, to: monthStart) ?? monthStart
            var income = Decimal(0)

            for holding in allHoldings {
                let upcoming = holding.stock?.dividendSchedules.filter { $0.isUpcoming } ?? []
                if upcoming.isEmpty {
                    // No upcoming schedules — spread projected income evenly
                    income += holding.projectedMonthlyIncome
                } else {
                    // Sum from schedules whose pay date falls this month
                    let matched = upcoming.filter {
                        calendar.isDate($0.payDate, equalTo: date, toGranularity: .month)
                    }
                    income += matched.reduce(Decimal(0)) { $0 + $1.amountPerShare * holding.shares }
                }
            }
            let label = date.formatted(.dateTime.month(.abbreviated))
            return MonthForecast(label: label, date: date, income: income)
        }
    }

    private var totalProjected: Decimal {
        forecastData.reduce(0) { $0 + $1.income }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                chartCard
                noteCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Income Forecast")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("12-Month Projection")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(totalProjected, format: .currency(code: "USD"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("projected dividend income")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Breakdown")
                .font(.headline)

            if allHoldings.isEmpty {
                ContentUnavailableView(
                    "No Holdings",
                    systemImage: "chart.bar",
                    description: Text("Add holdings to see your income forecast.")
                )
                .frame(height: 200)
            } else {
                Chart(forecastData) { item in
                    BarMark(
                        x: .value("Month", item.label),
                        y: .value("Income", item.doubleIncome)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text("$\(Int(d))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var noteCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Uses declared dividend schedules where available, otherwise distributes projected income evenly across months. Actual payments may vary.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Data model

private struct MonthForecast: Identifiable {
    let label: String
    let date: Date
    let income: Decimal

    var id: String { label }
    var doubleIncome: Double { (income as NSDecimalNumber).doubleValue }
}

// MARK: - Calendar helper

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        IncomeForecastView()
    }
    .modelContainer(container)
    .environment(settings)
}
