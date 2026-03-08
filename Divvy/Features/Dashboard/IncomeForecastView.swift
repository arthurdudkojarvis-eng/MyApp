import SwiftUI
import SwiftData
import Charts

struct IncomeForecastView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.massiveService) private var massive

    @State private var selectedMonth: String?
    @State private var animateBars = false

    private var allHoldings: [Holding] { portfolios.flatMap(\.holdings) }

    // Computed once per render, all derived properties reference this cached value
    private var forecast: ForecastSnapshot {
        let holdings = allHoldings
        let calendar = Calendar.current
        let monthStart = calendar.startOfMonth(for: .now)

        let months: [MonthForecast] = (0..<12).map { offset in
            let date = calendar.date(byAdding: .month, value: offset, to: monthStart) ?? monthStart
            var income = Decimal(0)
            var contribMap: [String: HoldingContribution] = [:]

            for holding in holdings {
                var holdingIncome = Decimal(0)
                let upcoming = holding.stock?.dividendSchedules.filter { $0.isUpcoming } ?? []
                if upcoming.isEmpty {
                    holdingIncome = holding.projectedMonthlyIncome
                } else {
                    let matched = upcoming.filter {
                        calendar.isDate($0.payDate, equalTo: date, toGranularity: .month)
                    }
                    holdingIncome = matched.reduce(Decimal(0)) { $0 + $1.amountPerShare * holding.shares }
                }
                income += holdingIncome
                if holdingIncome > 0 {
                    let ticker = holding.stock?.ticker ?? "—"
                    if var existing = contribMap[ticker] {
                        existing.amount += holdingIncome
                        contribMap[ticker] = existing
                    } else {
                        contribMap[ticker] = HoldingContribution(
                            ticker: ticker,
                            companyName: holding.stock?.companyName ?? "",
                            amount: holdingIncome,
                            currency: holding.currency
                        )
                    }
                }
            }
            let label = date.formatted(.dateTime.month(.abbreviated))
            return MonthForecast(
                offset: offset,
                label: label,
                date: date,
                income: income,
                isCurrentMonth: offset == 0,
                contributors: contribMap.values.sorted { $0.amount > $1.amount }
            )
        }

        let total = months.reduce(Decimal(0)) { $0 + $1.income }

        // Top contributors across all months
        var annualMap: [String: HoldingContribution] = [:]
        for month in months {
            for c in month.contributors {
                if var existing = annualMap[c.ticker] {
                    existing.amount += c.amount
                    annualMap[c.ticker] = existing
                } else {
                    annualMap[c.ticker] = c
                }
            }
        }
        let top = Array(annualMap.values.sorted { $0.amount > $1.amount }.prefix(5))

        // Quarterly
        let quarters: [QuarterSummary] = stride(from: 0, to: 12, by: 3).map { start in
            let slice = Array(months[start..<min(start + 3, 12)])
            let qTotal = slice.reduce(Decimal(0)) { $0 + $1.income }
            return QuarterSummary(label: "Q\(start / 3 + 1)", total: qTotal, months: slice)
        }

        return ForecastSnapshot(
            months: months,
            total: total,
            average: total / 12,
            best: months.max { $0.income < $1.income },
            topContributors: top,
            quarters: quarters
        )
    }

    private var selectedForecast: MonthForecast? {
        guard let selectedMonth else { return nil }
        return forecast.months.first { $0.label == selectedMonth }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if allHoldings.isEmpty {
                    ContentUnavailableView {
                        Label("No Holdings", systemImage: "chart.bar.fill")
                            .symbolRenderingMode(.hierarchical)
                    } description: {
                        Text("Add holdings to a portfolio to see your income forecast.")
                    }
                    .padding(.top, 60)
                } else {
                    let snap = forecast
                    summaryCard(snap)
                    chartCard(snap)
                    if !snap.topContributors.isEmpty {
                        contributorsCard(snap)
                    }
                    quarterlyCard(snap)
                    noteCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Income Forecast")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary Card

    private func summaryCard(_ snap: ForecastSnapshot) -> some View {
        VStack(spacing: 16) {
            // Main total
            VStack(alignment: .leading, spacing: 4) {
                Text("12-Month Projection")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(snap.total, format: .currency(code: "USD"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Stats row
            HStack(spacing: 0) {
                SummaryMetric(
                    label: "Monthly Avg",
                    value: snap.average.formatted(.currency(code: "USD")),
                    icon: "calendar"
                )
                Spacer()
                if let best = snap.best, best.income > 0 {
                    SummaryMetric(
                        label: "Best Month",
                        value: "\(best.label) \(best.income.formatted(.currency(code: "USD")))",
                        icon: "arrow.up.circle.fill",
                        iconColor: .green
                    )
                }
                Spacer()
                SummaryMetric(
                    label: "Holdings",
                    value: "\(allHoldings.count)",
                    icon: "briefcase"
                )
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

    // MARK: - Chart Card

    private func chartCard(_ snap: ForecastSnapshot) -> some View {
        let currentMonthLabels = Set(snap.months.filter(\.isCurrentMonth).map(\.label))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Monthly Breakdown")
                    .font(.headline)
                Spacer()
                if let selected = selectedForecast {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(selected.label)
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                        Text(selected.income, format: .currency(code: "USD"))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedMonth)

            Chart(snap.months) { item in
                BarMark(
                    x: .value("Month", item.label),
                    y: .value("Income", animateBars ? item.doubleIncome : 0)
                )
                .foregroundStyle(
                    item.isCurrentMonth
                        ? Color.accentColor.gradient
                        : Color.accentColor.opacity(0.55).gradient
                )
                .cornerRadius(5)
                .opacity(selectedMonth == nil || selectedMonth == item.label ? 1.0 : 0.35)

                if let selected = selectedForecast, selected.label == item.label {
                    RuleMark(x: .value("Month", item.label))
                        .foregroundStyle(Color.accentColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, spacing: 4) {
                            Text(item.income, format: .currency(code: "USD"))
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor)
                                )
                                .foregroundStyle(.white)
                        }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text("$\(Int(d))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                                .fontWeight(currentMonthLabels.contains(label) ? .bold : .regular)
                                .foregroundStyle(currentMonthLabels.contains(label) ? Color.accentColor : .secondary)
                        }
                    }
                }
            }
            .frame(height: 220)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateBars)
            .onAppear { animateBars = true }
            .onDisappear { animateBars = false }

            // Selected month breakdown
            if let selected = selectedForecast, !selected.contributors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    Text("\(selected.label) Contributors")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(Array(selected.contributors.prefix(5))) { contrib in
                        HStack(spacing: 8) {
                            CompanyLogoView(
                                branding: nil,
                                ticker: contrib.ticker,
                                service: massive.service,
                                size: 24
                            )
                            Text(contrib.ticker)
                                .font(.caption.bold())
                            Spacer()
                            Text(contrib.amount, format: .currency(code: contrib.currency))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.25), value: selectedMonth)
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
        .sensoryFeedback(.selection, trigger: selectedMonth)
    }

    // MARK: - Top Contributors Card

    private func contributorsCard(_ snap: ForecastSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Contributors")
                .font(.headline)

            let maxAmount = snap.topContributors.first?.amount ?? 1

            ForEach(Array(snap.topContributors.enumerated()), id: \.element.id) { index, contrib in
                HStack(spacing: 10) {
                    CompanyLogoView(
                        branding: nil,
                        ticker: contrib.ticker,
                        service: massive.service,
                        size: 32
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contrib.ticker)
                            .font(.subheadline.bold())
                        if !contrib.companyName.isEmpty {
                            Text(contrib.companyName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(contrib.amount, format: .currency(code: contrib.currency))
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }

                // Progress bar
                let fraction = maxAmount > 0
                    ? CGFloat(((contrib.amount / maxAmount) as NSDecimalNumber).doubleValue)
                    : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.6), Color.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(
                            x: animateBars ? fraction : 0,
                            anchor: .leading
                        )
                        .animation(
                            .spring(response: 0.55, dampingFraction: 0.78)
                                .delay(Double(index) * 0.07),
                            value: animateBars
                        )
                }

                if index < snap.topContributors.count - 1 {
                    Divider()
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

    // MARK: - Quarterly Card

    private func quarterlyCard(_ snap: ForecastSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quarterly Breakdown")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(snap.quarters) { quarter in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(quarter.label)
                                .font(.subheadline.bold())
                            Spacer()
                            if snap.total > 0 {
                                let pct = (quarter.total / snap.total) * 100
                                let pctDouble = (pct as NSDecimalNumber).doubleValue
                                Text("\(String(format: "%.0f", pctDouble))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        Text(quarter.total, format: .currency(code: "USD"))
                            .font(.title3.bold().monospacedDigit())
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            ForEach(quarter.months) { m in
                                Text(m.label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
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
    }

    // MARK: - Note

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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Summary Metric

private struct SummaryMetric: View {
    let label: String
    let value: String
    let icon: String
    var iconColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Data Models

private struct ForecastSnapshot {
    let months: [MonthForecast]
    let total: Decimal
    let average: Decimal
    let best: MonthForecast?
    let topContributors: [HoldingContribution]
    let quarters: [QuarterSummary]
}

private struct MonthForecast: Identifiable {
    let offset: Int
    let label: String
    let date: Date
    var income: Decimal
    let isCurrentMonth: Bool
    let contributors: [HoldingContribution]

    var id: Int { offset }
    var doubleIncome: Double { (income as NSDecimalNumber).doubleValue }
}

private struct HoldingContribution: Identifiable {
    let ticker: String
    let companyName: String
    var amount: Decimal
    let currency: String

    var id: String { ticker }
}

private struct QuarterSummary: Identifiable {
    let label: String
    let total: Decimal
    let months: [MonthForecast]

    var id: String { label }
}

// MARK: - Calendar Helper

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
