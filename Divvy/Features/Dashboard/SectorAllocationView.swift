import SwiftUI
import SwiftData
import Charts

struct SectorAllocationView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.massiveService) private var massive

    @State private var rawSelectedAngle: Double?
    @State private var animateBars = false
    @State private var showInfo = false

    private var allHoldings: [Holding] { portfolios.flatMap(\.holdings) }

    private func normalizedSector(for holding: Holding) -> String {
        guard let stock = holding.stock, !stock.sector.isEmpty else { return "Unclassified" }
        return stock.sector
    }

    private var sectorData: [SectorSlice] {
        var incomeMap: [String: Decimal] = [:]
        var countMap: [String: Int] = [:]
        for holding in allHoldings {
            let sector = normalizedSector(for: holding)
            incomeMap[sector, default: 0] += holding.projectedAnnualIncome
            countMap[sector, default: 0] += 1
        }
        let total = incomeMap.values.reduce(0, +)
        return incomeMap
            .filter { $0.value > 0 }
            .map { SectorSlice(sector: $0.key, income: $0.value, total: total, holdingCount: countMap[$0.key] ?? 0) }
            .sorted { $0.income > $1.income }
    }

    // MARK: - Diversification Metrics

    /// HHI-based diversification score (0–100). Percent values are on 0–100 scale,
    /// so max HHI = 10000 (single sector). Score = 100 * (1 - HHI/10000).
    private static func diversificationScore(from slices: [SectorSlice]) -> Int {
        guard !slices.isEmpty else { return 0 }
        let hhi = slices.reduce(0.0) { sum, slice in
            let pct = NSDecimalNumber(decimal: slice.percent).doubleValue
            return sum + pct * pct
        }
        return max(0, min(100, Int((100.0 * (1.0 - hhi / 10000.0)).rounded())))
    }

    private static func topSectorConcentration(from slices: [SectorSlice]) -> Double {
        guard let top = slices.first else { return 0 }
        return NSDecimalNumber(decimal: top.percent).doubleValue
    }

    private static func top3Concentration(from slices: [SectorSlice]) -> Double {
        slices.prefix(3).reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.percent).doubleValue }
    }

    private var uniqueHoldingCount: Int {
        Set(allHoldings.compactMap { $0.stock?.ticker }).count
    }

    private func selectedSector(from slices: [SectorSlice]) -> SectorSlice? {
        guard let rawSelectedAngle else { return nil }
        var cumulative: Double = 0
        for slice in slices {
            cumulative += slice.doubleIncome
            if rawSelectedAngle <= cumulative {
                return slice
            }
        }
        return slices.last
    }

    private func holdingsBySector() -> [String: [Holding]] {
        Dictionary(
            grouping: allHoldings.filter { $0.projectedAnnualIncome > 0 },
            by: { normalizedSector(for: $0) }
        ).mapValues { $0.sorted { ($0.stock?.ticker ?? "") < ($1.stock?.ticker ?? "") } }
    }

    var body: some View {
        let slices = sectorData
        let selected = selectedSector(from: slices)
        let score = Self.diversificationScore(from: slices)
        let topConc = Self.topSectorConcentration(from: slices)
        let top3Conc = Self.top3Concentration(from: slices)
        let totalIncome = slices.reduce(Decimal.zero) { $0 + $1.income }
        let grouped = holdingsBySector()

        ScrollView {
            VStack(spacing: 16) {
                if allHoldings.isEmpty {
                    ContentUnavailableView {
                        Label("No Holdings", systemImage: "chart.pie.fill")
                            .symbolRenderingMode(.hierarchical)
                    } description: {
                        Text("Add holdings to a portfolio to see how your income is distributed across sectors.")
                    }
                    .padding(.top, 60)
                } else {
                    diversificationCard(
                        slices: slices, score: score,
                        topConc: topConc, top3Conc: top3Conc
                    )
                    chartCard(slices: slices, selected: selected, totalIncome: totalIncome)
                    breakdownList(
                        slices: slices, selected: selected,
                        grouped: grouped
                    )
                    disclaimerCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Sector Allocation")
        .navigationBarTitleDisplayMode(.large)
        .sensoryFeedback(.selection, trigger: selected?.id)
        .sheet(isPresented: $showInfo) {
            SectorAllocationInfoSheet()
        }
    }

    // MARK: - Diversification Score Card

    private func diversificationCard(
        slices: [SectorSlice], score: Int,
        topConc: Double, top3Conc: Double
    ) -> some View {
        let color = Self.scoreColor(for: score)

        return VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Diversification Score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            showInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("What is the diversification score?")
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(color)
                        Text("/ 100")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(Self.scoreLabel(for: score))
                        .font(.caption)
                        .foregroundStyle(color)
                }
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 8)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: animateBars ? CGFloat(score) / 100 : 0)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animateBars)
                    Image(systemName: Self.scoreIcon(for: score))
                        .font(.title3)
                        .foregroundStyle(color)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Diversification gauge, \(score) out of 100, \(Self.scoreLabel(for: score))")
            }

            Divider()

            HStack(spacing: 0) {
                QuickStat(
                    label: "Sectors",
                    value: "\(slices.count)",
                    color: .primary
                )
                Spacer()
                QuickStat(
                    label: "Top Sector",
                    value: topConc > 0
                        ? String(format: "%.1f%%", topConc)
                        : "—",
                    color: topConc > 50 ? .orange : .green
                )
                Spacer()
                QuickStat(
                    label: "Top 3",
                    value: top3Conc > 0
                        ? String(format: "%.0f%%", top3Conc)
                        : "—",
                    color: top3Conc > 80 ? .orange : .green
                )
                Spacer()
                QuickStat(
                    label: "Holdings",
                    value: "\(uniqueHoldingCount)",
                    color: .primary
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
        .onAppear {
            guard !animateBars else { return }
            animateBars = true
        }
        .onDisappear { animateBars = false }
    }

    private static func scoreColor(for score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        if score >= 25 { return .orange.opacity(0.8) }
        return .red
    }

    private static func scoreLabel(for score: Int) -> String {
        if score >= 75 { return "Well Diversified" }
        if score >= 50 { return "Moderately Diversified" }
        if score >= 25 { return "Concentrated" }
        return "Highly Concentrated"
    }

    private static func scoreIcon(for score: Int) -> String {
        if score >= 75 { return "checkmark.shield.fill" }
        if score >= 50 { return "shield.lefthalf.filled" }
        if score >= 25 { return "shield" }
        return "exclamationmark.shield.fill"
    }

    // MARK: - Donut Chart with Center Label

    private func chartCard(
        slices: [SectorSlice], selected: SectorSlice?, totalIncome: Decimal
    ) -> some View {
        let animatedBinding = Binding<Double?>(
            get: { rawSelectedAngle },
            set: { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    rawSelectedAngle = newValue
                }
            }
        )

        return ZStack {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Income", slice.doubleIncome),
                    innerRadius: .ratio(0.618),
                    outerRadius: selected?.id == slice.id
                        ? .ratio(1.0)
                        : .ratio(selected == nil ? 0.95 : 0.88),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Sector", slice.displayName))
                .cornerRadius(5)
                .opacity(selected == nil || selected?.id == slice.id ? 1.0 : 0.35)
            }
            .chartForegroundStyleScale(
                domain: slices.map(\.displayName),
                range: slices.indices.map { Self.colorPalette[$0 % Self.colorPalette.count] }
            )
            .chartLegend(.hidden)
            .chartAngleSelection(value: animatedBinding)
            .frame(height: 240)

            centerLabel(slices: slices, selected: selected, totalIncome: totalIncome)
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

    // MARK: - Center Label (reactive to selection)

    private func centerLabel(
        slices: [SectorSlice], selected: SectorSlice?, totalIncome: Decimal
    ) -> some View {
        VStack(spacing: 3) {
            if let selected,
               let index = slices.firstIndex(where: { $0.id == selected.id }) {
                Text(selected.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Self.colorForIndex(index))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                Text(selected.income, format: .currency(code: "USD"))
                    .font(.title3.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(selected.percentString)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text(totalIncome, format: .currency(code: "USD"))
                    .font(.title3.bold().monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("Annual Income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 120)
        .animation(.easeInOut(duration: 0.2), value: selected?.id)
    }

    // MARK: - Progress Bar Breakdown

    private func breakdownList(
        slices: [SectorSlice], selected: SectorSlice?,
        grouped: [String: [Holding]]
    ) -> some View {
        let sliceCount = slices.count

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sector Breakdown")
                    .font(.headline)
                Spacer()
                Text("\(sliceCount) sector\(sliceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)

            ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                let color = Self.colorForIndex(index)
                let isSelected = selected?.id == slice.id

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                            Text(slice.displayName)
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(slice.income, format: .currency(code: "USD"))
                                .font(.subheadline.bold())
                                .monospacedDigit()
                            HStack(spacing: 4) {
                                Text("\(slice.percentString)%")
                                    .font(.caption2)
                                    .foregroundStyle(color)
                                    .monospacedDigit()
                                Text("\(slice.holdingCount) holding\(slice.holdingCount == 1 ? "" : "s")")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(color.opacity(0.12))
                            .frame(height: 8)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.7), color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(
                                x: animateBars ? slice.fraction : 0,
                                anchor: .leading
                            )
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.78)
                                    .delay(Double(index) * 0.07),
                                value: animateBars
                            )
                    }

                    if isSelected {
                        VStack(spacing: 0) {
                            ForEach(grouped[slice.sector] ?? []) { holding in
                                if let stock = holding.stock {
                                    HStack(spacing: 10) {
                                        CompanyLogoView(
                                            branding: nil,
                                            ticker: stock.ticker,
                                            service: massive.service,
                                            size: 30
                                        )
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(stock.ticker)
                                                .font(.caption.bold())
                                            if !stock.companyName.isEmpty {
                                                Text(stock.companyName)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Text(holding.projectedAnnualIncome, format: .currency(code: holding.currency))
                                            .font(.caption.bold())
                                            .monospacedDigit()
                                            .foregroundStyle(color)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? color.opacity(0.08) : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture { toggleSelection(for: slice.id, in: slices, isSelected: isSelected) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(slice.displayName), \(slice.percentString) percent, \(slice.holdingCount) holding\(slice.holdingCount == 1 ? "" : "s")")

                if index < sliceCount - 1 {
                    Divider().padding(.horizontal)
                }
            }
        }
        .padding(.bottom)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected?.id)
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Sector allocation is based on projected annual dividend income, not market value. Holdings without sector data are grouped as \"Unclassified\". Diversification does not guarantee against loss.")
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

    // MARK: - Helpers

    private func toggleSelection(for id: String, in slices: [SectorSlice], isSelected: Bool) {
        // animatedAngleBinding's setter handles animation; no wrapping here
        rawSelectedAngle = isSelected ? nil : angleForSector(id, in: slices)
    }

    private func angleForSector(_ id: String, in slices: [SectorSlice]) -> Double? {
        var cumulative: Double = 0
        for slice in slices {
            if slice.id == id {
                return cumulative + slice.doubleIncome / 2
            }
            cumulative += slice.doubleIncome
        }
        return nil
    }

    // MARK: - Colors (auto-adaptive light/dark via UIColor dynamic provider)

    static let colorPalette: [Color] = [
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.78, blue: 1.00, alpha: 1)
            : UIColor(red: 0.20, green: 0.60, blue: 0.90, alpha: 1)
        }),  // sky
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.32, green: 0.88, blue: 0.60, alpha: 1)
            : UIColor(red: 0.18, green: 0.72, blue: 0.44, alpha: 1)
        }),  // mint
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.70, blue: 0.36, alpha: 1)
            : UIColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1)
        }),  // amber
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 0.56, blue: 1.00, alpha: 1)
            : UIColor(red: 0.62, green: 0.38, blue: 0.88, alpha: 1)
        }),  // violet
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.50, blue: 0.56, alpha: 1)
            : UIColor(red: 0.92, green: 0.30, blue: 0.38, alpha: 1)
        }),  // coral
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.72, blue: 0.90, alpha: 1)
            : UIColor(red: 0.18, green: 0.56, blue: 0.72, alpha: 1)
        }),  // teal
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.82, blue: 0.30, alpha: 1)
            : UIColor(red: 0.88, green: 0.68, blue: 0.12, alpha: 1)
        }),  // gold
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.80, blue: 0.38, alpha: 1)
            : UIColor(red: 0.44, green: 0.62, blue: 0.24, alpha: 1)
        }),  // olive
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.54, blue: 0.76, alpha: 1)
            : UIColor(red: 0.82, green: 0.36, blue: 0.60, alpha: 1)
        }),  // rose
        Color(UIColor { tc in tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.64, blue: 0.96, alpha: 1)
            : UIColor(red: 0.40, green: 0.46, blue: 0.78, alpha: 1)
        }),  // indigo
    ]

    static func colorForIndex(_ index: Int) -> Color {
        colorPalette[index % colorPalette.count]
    }
}

// MARK: - Quick Stat

private struct QuickStat: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Sector Allocation Info Sheet

private struct SectorAllocationInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    infoSection(
                        icon: "chart.pie.fill",
                        color: .blue,
                        title: "What Is Sector Allocation?",
                        body: "Sector allocation shows how your projected dividend income is distributed across different market sectors like Technology, Healthcare, Financial Services, and more. It helps you understand where your income is coming from."
                    )

                    infoSection(
                        icon: "arrow.triangle.branch",
                        color: .green,
                        title: "Why Diversify?",
                        body: "Spreading income across multiple sectors reduces the impact of a downturn in any single industry. If one sector cuts dividends, income from other sectors can help cushion the blow. A well-diversified portfolio is more resilient to economic shifts."
                    )

                    infoSection(
                        icon: "gauge.with.needle.fill",
                        color: .orange,
                        title: "Diversification Score",
                        body: "The score (0\u{2013}100) is based on the Herfindahl-Hirschman Index (HHI), which measures concentration. A portfolio with income evenly spread across many sectors scores high, while one dominated by a single sector scores low."
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Score Ranges")
                            .font(.subheadline.bold())
                        scoreRow(color: .green, label: "75\u{2013}100: Well Diversified",
                                 description: "Income is spread across many sectors. No single sector dominates your dividend stream.")
                        scoreRow(color: .orange, label: "50\u{2013}74: Moderately Diversified",
                                 description: "A few sectors contribute the majority of income. Consider broadening exposure.")
                        scoreRow(color: .orange.opacity(0.8), label: "25\u{2013}49: Concentrated",
                                 description: "Income is heavily weighted toward one or two sectors. A sector downturn could significantly impact your income.")
                        scoreRow(color: .red, label: "0\u{2013}24: Highly Concentrated",
                                 description: "Nearly all income comes from a single sector. This carries significant sector-specific risk.")
                    }

                    infoSection(
                        icon: "lightbulb.fill",
                        color: .yellow,
                        title: "Tips for Better Diversification",
                        body: "Look for dividend-paying stocks in sectors you're underweight. Utilities, Consumer Staples, Healthcare, and REITs are traditional dividend sectors. ETFs can provide instant sector diversification."
                    )

                    infoSection(
                        icon: "info.circle.fill",
                        color: .secondary,
                        title: "Limitations",
                        body: "This analysis is based on projected annual dividend income, not market value or total return. Sector classifications come from market data providers and may not always reflect a company's full business. Diversification does not guarantee against loss."
                    )
                }
                .padding()
            }
            .navigationTitle("About This Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoSection(icon: String, color: Color, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.bold())
            }
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func scoreRow(color: Color, label: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.caption.bold())
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 16)
        }
    }
}

// MARK: - Data model

private struct SectorSlice: Identifiable {
    let sector: String
    let displayName: String
    let income: Decimal
    let total: Decimal
    let holdingCount: Int
    let doubleIncome: Double
    let percent: Decimal
    let fraction: CGFloat
    let percentString: String

    var id: String { sector }

    init(sector: String, income: Decimal, total: Decimal, holdingCount: Int) {
        self.sector = sector
        self.income = income
        self.total = total
        self.holdingCount = holdingCount

        // Pre-compute derived values once at init
        self.displayName = sector.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        self.doubleIncome = NSDecimalNumber(decimal: income).doubleValue
        self.percent = total > 0 ? (income / total) * 100 : 0
        let fractionValue = total > 0 ? NSDecimalNumber(decimal: income / total).doubleValue : 0
        self.fraction = CGFloat(fractionValue)
        self.percentString = String(format: "%.1f", NSDecimalNumber(decimal: self.percent).doubleValue)
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        SectorAllocationView()
    }
    .modelContainer(container)
    .environment(settings)
}
