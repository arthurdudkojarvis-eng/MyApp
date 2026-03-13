import SwiftUI
import SwiftData
import Charts

struct DRIPSimulatorView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    @State private var years: Int = 10
    @State private var reinvestmentRate: Double = 100
    @State private var selectedYear: Int?
    @State private var animateChart = false
    @State private var showYearBreakdown = false

    private var allHoldings: [Holding] { portfolios.flatMap(\.holdings) }

    // MARK: - Snapshot (computed once per render)

    private var snapshot: DRIPSnapshot {
        let holdings = allHoldings
        let portfolioValue = holdings.reduce(0 as Decimal) { $0 + $1.currentValue }
        let annualIncome = holdings.reduce(0 as Decimal) { $0 + $1.projectedAnnualIncome }
        let portfolioDouble = (portfolioValue as NSDecimalNumber).doubleValue
        let incomeDouble = (annualIncome as NSDecimalNumber).doubleValue
        let yield = portfolioDouble > 0 ? incomeDouble / portfolioDouble : 0
        let reinvestFraction = reinvestmentRate / 100.0

        // With DRIP
        var dripProjections: [YearProjection] = []
        var dripValue = portfolioDouble
        var totalDividends = 0.0
        var totalReinvested = 0.0

        // Year 0 is the starting snapshot (no compounding yet)
        let baseIncome = dripValue * yield
        dripProjections.append(YearProjection(year: 0, annualIncome: baseIncome, portfolioValue: dripValue))

        for year in 1...years {
            let income = dripValue * yield
            let reinvested = income * reinvestFraction
            totalDividends += income
            totalReinvested += reinvested
            dripValue += reinvested
            dripProjections.append(YearProjection(
                year: year,
                annualIncome: dripValue * yield,
                portfolioValue: dripValue,
                reinvestedAmount: reinvested
            ))
        }

        // Without DRIP (0% reinvestment)
        var noDripProjections: [YearProjection] = []
        let noDripValue = portfolioDouble
        let noDripIncome = noDripValue * yield
        for year in 0...years {
            noDripProjections.append(YearProjection(
                year: year,
                annualIncome: noDripIncome,
                portfolioValue: noDripValue
            ))
        }

        // Milestones (capped at 10 to prevent excessive rendering)
        var milestones: [Milestone] = []
        let initialIncome = dripProjections.first?.annualIncome ?? 0
        let maxMilestones = 10
        if initialIncome > 0 {
            var nextMultiple = 2
            outer: for proj in dripProjections where proj.year > 0 {
                while proj.annualIncome >= initialIncome * Double(nextMultiple) {
                    milestones.append(Milestone(
                        year: proj.year,
                        label: "\(nextMultiple)x Income",
                        description: "Dividends reach \(nextMultiple)x your starting income"
                    ))
                    nextMultiple += 1
                    if milestones.count >= maxMilestones { break outer }
                }
            }
        }

        let incomeGrowth: Double = {
            guard initialIncome > 0, let final = dripProjections.last else { return 0 }
            return ((final.annualIncome - initialIncome) / initialIncome) * 100
        }()

        return DRIPSnapshot(
            initialPortfolioValue: portfolioValue,
            initialAnnualIncome: annualIncome,
            averageYield: yield,
            dripProjections: dripProjections,
            noDripProjections: noDripProjections,
            totalDividends: totalDividends,
            totalReinvested: totalReinvested,
            incomeGrowthPercent: incomeGrowth,
            milestones: milestones
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if allHoldings.isEmpty {
                    ContentUnavailableView {
                        Label("No Holdings", systemImage: "arrow.trianglehead.2.clockwise")
                            .symbolRenderingMode(.hierarchical)
                    } description: {
                        Text("Add holdings to a portfolio to run the DRIP simulator.")
                    }
                    .padding(.top, 60)
                } else {
                    let snap = snapshot
                    let selectedProj = selectedYear.flatMap { yr in
                        snap.dripProjections.first { $0.year == yr }
                    }
                    controlsCard(snap)
                    summaryCard(snap)
                    chartCard(snap, selectedProjection: selectedProj)
                    if !snap.milestones.isEmpty {
                        milestonesCard(snap)
                    }
                    metricsCard(snap)
                    if showYearBreakdown {
                        yearBreakdownCard(snap)
                    }
                    noteCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("DRIP Simulator")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: years) { selectedYear = nil }
        .onChange(of: reinvestmentRate) { selectedYear = nil }
    }

    // MARK: - Controls Card

    private func controlsCard(_ snap: DRIPSnapshot) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projection Period")
                        .textStyle(.controlLabel)
                    Text("\(years) years")
                        .textStyle(.rowTitle)
                }
                Spacer()
                Stepper("", value: $years, in: 1...40)
                    .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Reinvestment Rate")
                        .textStyle(.controlLabel)
                    Spacer()
                    Text("\(Int(reinvestmentRate))%")
                        .textStyle(.rowTitle)
                        .monospacedDigit()
                }
                Slider(value: $reinvestmentRate, in: 0...100, step: 5)
                    .tint(.accentColor)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Starting Value")
                        .textStyle(.rowDetail)
                    Text(snap.initialPortfolioValue, format: .currency(code: "USD"))
                        .textStyle(.statValue)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Avg Yield")
                        .textStyle(.rowDetail)
                    Text(snap.averageYield, format: .percent.precision(.fractionLength(2)))
                        .textStyle(.statValue)
                        .foregroundStyle(.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Annual Income")
                        .textStyle(.rowDetail)
                    Text(snap.initialAnnualIncome, format: .currency(code: "USD"))
                        .textStyle(.statValue)
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

    // MARK: - Summary Card

    private func summaryCard(_ snap: DRIPSnapshot) -> some View {
        VStack(spacing: 16) {
            // Final income highlight
            VStack(alignment: .leading, spacing: 4) {
                Text("Year \(years) Annual Income")
                    .textStyle(.controlLabel)
                if let final = snap.dripProjections.last {
                    Text(Decimal(final.annualIncome), format: .currency(code: "USD"))
                        .textStyle(.heroDisplay)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("—")
                        .textStyle(.heroDisplay)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Key results row
            HStack(spacing: 0) {
                ResultMetric(
                    label: "Income Growth",
                    value: snap.incomeGrowthPercent > 0
                        ? String(format: "+%.0f%%", snap.incomeGrowthPercent)
                        : "0%",
                    color: snap.incomeGrowthPercent > 0 ? .green : .secondary
                )
                Spacer()
                ResultMetric(
                    label: "Final Portfolio",
                    value: snap.dripProjections.last.map {
                        Decimal($0.portfolioValue).formatted(.currency(code: "USD"))
                    } ?? "—",
                    color: .primary
                )
                Spacer()
                ResultMetric(
                    label: "Income Multiplier",
                    value: {
                        guard let first = snap.dripProjections.first,
                              let last = snap.dripProjections.last,
                              first.annualIncome > 0 else { return "1x" }
                        let mult = last.annualIncome / first.annualIncome
                        return String(format: "%.1fx", mult)
                    }(),
                    color: .orange
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

    private func chartCard(_ snap: DRIPSnapshot, selectedProjection: YearProjection?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Income Growth")
                    .textStyle(.rowTitle)
                Spacer()
                if let sel = selectedProjection {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Year \(sel.year)")
                            .textStyle(.captionBold)
                            .foregroundStyle(Color.accentColor)
                        Text(Decimal(sel.annualIncome), format: .currency(code: "USD"))
                            .textStyle(.rowDetail)
                            .monospacedDigit()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedYear)

            Chart {
                // Without DRIP baseline (dashed)
                if reinvestmentRate > 0 {
                    ForEach(snap.noDripProjections) { item in
                        LineMark(
                            x: .value("Year", item.year),
                            y: .value("No DRIP", animateChart ? item.annualIncome : snap.noDripProjections.first?.annualIncome ?? 0)
                        )
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                }

                // With DRIP area fill
                ForEach(snap.dripProjections) { item in
                    AreaMark(
                        x: .value("Year", item.year),
                        y: .value("Income", animateChart ? item.annualIncome : snap.dripProjections.first?.annualIncome ?? 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(selectedYear == nil || selectedYear == item.year ? 1.0 : 0.5)
                }

                // With DRIP line
                ForEach(snap.dripProjections) { item in
                    LineMark(
                        x: .value("Year", item.year),
                        y: .value("Income", animateChart ? item.annualIncome : snap.dripProjections.first?.annualIncome ?? 0)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }

                // Selected year indicator
                if let sel = selectedProjection {
                    PointMark(
                        x: .value("Year", sel.year),
                        y: .value("Income", sel.annualIncome)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(60)

                    RuleMark(x: .value("Year", sel.year))
                        .foregroundStyle(Color.accentColor.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartXSelection(value: $selectedYear)
            .chartXAxis {
                let step = max(1, years / 5)
                AxisMarks(values: Array(Swift.stride(from: 0, through: years, by: step))) { value in
                    AxisValueLabel {
                        if let y = value.as(Int.self) {
                            Text("Y\(y)").font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(compactCurrency(d)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 220)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateChart)
            .onAppear { animateChart = true }
            .onDisappear { animateChart = false }

            // Legend
            if reinvestmentRate > 0 {
                HStack(spacing: 16) {
                    legendItem(color: .accentColor, label: "With DRIP", dashed: false)
                    legendItem(color: .secondary.opacity(0.5), label: "Without DRIP", dashed: true)
                }
                .font(.caption2)
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
        .sensoryFeedback(.selection, trigger: selectedYear)
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            if dashed {
                Rectangle()
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 16, height: 1)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: 2)
                    .clipShape(Capsule())
            }
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Milestones Card

    private func milestonesCard(_ snap: DRIPSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Milestones")
                .textStyle(.rowTitle)

            ForEach(Array(snap.milestones.enumerated()), id: \.element.id) { index, milestone in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(milestoneColor(index).opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(milestoneColor(index))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(milestone.label)
                            .textStyle(.statValue)
                        Text("Reached in year \(milestone.year)")
                            .textStyle(.rowDetail)
                    }
                    Spacer()
                    Text("Y\(milestone.year)")
                        .textStyle(.captionBold)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(milestoneColor(index).opacity(0.12))
                        )
                        .foregroundStyle(milestoneColor(index))
                }

                if index < snap.milestones.count - 1 {
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

    private func milestoneColor(_ index: Int) -> Color {
        let colors: [Color] = [.green, .blue, .purple, .orange, .pink]
        return colors[index % colors.count]
    }

    // MARK: - Metrics Card

    private func metricsCard(_ snap: DRIPSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projection Details")
                    .textStyle(.rowTitle)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showYearBreakdown.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showYearBreakdown ? "Hide" : "Year-by-Year")
                            .font(.caption)
                        Image(systemName: showYearBreakdown ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                metricTile(
                    icon: "dollarsign.circle.fill",
                    label: "Total Dividends",
                    value: Decimal(snap.totalDividends).formatted(.currency(code: "USD")),
                    color: .green
                )
                metricTile(
                    icon: "arrow.trianglehead.2.clockwise.rotate.90",
                    label: "Total Reinvested",
                    value: Decimal(snap.totalReinvested).formatted(.currency(code: "USD")),
                    color: .blue
                )
                metricTile(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Value Added",
                    value: {
                        guard let last = snap.dripProjections.last else { return "—" }
                        let added = last.portfolioValue - (snap.initialPortfolioValue as NSDecimalNumber).doubleValue
                        return Decimal(added).formatted(.currency(code: "USD"))
                    }(),
                    color: .purple
                )
                metricTile(
                    icon: "percent",
                    label: "DRIP Advantage",
                    value: {
                        guard reinvestmentRate > 0,
                              let dripFinal = snap.dripProjections.last,
                              let noDripFinal = snap.noDripProjections.last,
                              noDripFinal.annualIncome > 0 else {
                            return reinvestmentRate == 0 ? "0%" : "—"
                        }
                        let advantage = ((dripFinal.annualIncome - noDripFinal.annualIncome) / noDripFinal.annualIncome) * 100
                        return advantage > 0 ? String(format: "+%.0f%%", advantage) : "0%"
                    }(),
                    color: .orange
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

    private func metricTile(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(label)
                    .textStyle(.statLabel)
            }
            Text(value)
                .textStyle(.statValue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    // MARK: - Year Breakdown Card

    private func yearBreakdownCard(_ snap: DRIPSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Year-by-Year Breakdown")
                .textStyle(.rowTitle)

            // Header
            HStack {
                Text("Year").textStyle(.badge).frame(width: 36, alignment: .leading)
                Spacer()
                Text("Income").textStyle(.badge).frame(width: 80, alignment: .trailing)
                Text("Reinvested").textStyle(.badge).frame(width: 80, alignment: .trailing)
                Text("Portfolio").textStyle(.badge).frame(width: 90, alignment: .trailing)
            }
            .foregroundStyle(.secondary)

            Divider()

            ForEach(snap.dripProjections.dropFirst()) { proj in
                let reinvested = proj.reinvestedAmount
                HStack {
                    Text("Y\(proj.year)")
                        .textStyle(.captionBold)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .leading)
                    Spacer()
                    Text(compactCurrency(proj.annualIncome))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                    Text(compactCurrency(reinvested))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.green)
                        .frame(width: 80, alignment: .trailing)
                    Text(compactCurrency(proj.portfolioValue))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                }
                .foregroundStyle(selectedYear == proj.year ? Color.accentColor : .primary)

                if proj.year < years {
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
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Note

    private var noteCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Assumes a constant dividend yield equal to current portfolio average. Reinvested dividends purchase additional shares at current prices. Actual results will vary with price changes and yield fluctuations.")
                .textStyle(.rowDetail)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private func compactCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", locale: Self.posixLocale, value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.1fk", locale: Self.posixLocale, value / 1_000)
        } else {
            return String(format: "$%.0f", locale: Self.posixLocale, value)
        }
    }
}

// MARK: - Result Metric

private struct ResultMetric: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .textStyle(.statLabel)
            Text(value)
                .textStyle(.statValue)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Data Models

private struct DRIPSnapshot {
    let initialPortfolioValue: Decimal
    let initialAnnualIncome: Decimal
    let averageYield: Double
    let dripProjections: [YearProjection]
    let noDripProjections: [YearProjection]
    let totalDividends: Double
    let totalReinvested: Double
    let incomeGrowthPercent: Double
    let milestones: [Milestone]
}

private struct YearProjection: Identifiable {
    let year: Int
    let annualIncome: Double
    let portfolioValue: Double
    var reinvestedAmount: Double = 0  // actual amount reinvested this year

    var id: Int { year }
}

private struct Milestone: Identifiable {
    let year: Int
    let label: String
    let description: String

    var id: String { "\(year)-\(label)" }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        DRIPSimulatorView()
    }
    .modelContainer(container)
    .environment(settings)
}
