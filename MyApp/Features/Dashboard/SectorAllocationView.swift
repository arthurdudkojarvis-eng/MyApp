import SwiftUI
import SwiftData
import Charts

struct SectorAllocationView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.massiveService) private var massive

    @State private var rawSelectedAngle: Double?
    @State private var animateBars = false

    private var allHoldings: [Holding] { portfolios.flatMap(\.holdings) }

    private func normalizedSector(for holding: Holding) -> String {
        holding.stock.flatMap { $0.sector.isEmpty ? nil : $0.sector } ?? "Unclassified"
    }

    private var sectorData: [SectorSlice] {
        var map: [String: Decimal] = [:]
        for holding in allHoldings {
            map[normalizedSector(for: holding), default: 0] += holding.projectedAnnualIncome
        }
        let total = map.values.reduce(0, +)
        return map
            .filter { $0.value > 0 }
            .map { SectorSlice(sector: $0.key, income: $0.value, total: total) }
            .sorted { $0.income > $1.income }
    }

    private var totalIncome: Decimal {
        sectorData.reduce(0) { $0 + $1.income }
    }

    private var animatedAngleBinding: Binding<Double?> {
        Binding(
            get: { rawSelectedAngle },
            set: { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    rawSelectedAngle = newValue
                }
            }
        )
    }

    private var selectedSector: SectorSlice? {
        guard let rawSelectedAngle else { return nil }
        var cumulative: Double = 0
        for slice in sectorData {
            cumulative += slice.doubleIncome
            if rawSelectedAngle <= cumulative {
                return slice
            }
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if allHoldings.isEmpty {
                    ContentUnavailableView {
                        Label("No Holdings", systemImage: "chart.pie.fill")
                            .symbolRenderingMode(.hierarchical)
                    } description: {
                        Text("Add holdings to a portfolio to see how your income is distributed across sectors.")
                    }
                    .padding(.top, 60)
                } else {
                    chartCard
                    breakdownList
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Sector Allocation")
        .navigationBarTitleDisplayMode(.large)
        .sensoryFeedback(.selection, trigger: selectedSector?.id)
    }

    // MARK: - Donut Chart with Center Label

    private var chartCard: some View {
        VStack(spacing: 16) {
            Text("Income by Sector")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Chart(sectorData) { slice in
                    SectorMark(
                        angle: .value("Income", slice.doubleIncome),
                        innerRadius: .ratio(0.618),
                        outerRadius: selectedSector?.id == slice.id
                            ? .ratio(1.0)
                            : .ratio(selectedSector == nil ? 0.95 : 0.88),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Sector", slice.displayName))
                    .cornerRadius(5)
                    .opacity(selectedSector == nil || selectedSector?.id == slice.id ? 1.0 : 0.35)
                }
                .chartForegroundStyleScale(domain: sectorData.map(\.displayName), range: gradientColors)
                .chartLegend(.hidden)
                .chartAngleSelection(value: animatedAngleBinding)
                .frame(height: 240)

                centerLabel
            }

            legendChips
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

    private var centerLabel: some View {
        VStack(spacing: 3) {
            if let selected = selectedSector,
               let index = sectorData.firstIndex(where: { $0.id == selected.id }) {
                Text(selected.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colorForIndex(index))
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
        .animation(.easeInOut(duration: 0.2), value: selectedSector?.id)
    }

    // MARK: - Legend Chips (tappable pills)

    private var legendChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(sectorData.enumerated()), id: \.element.id) { index, slice in
                let isSelected = selectedSector?.id == slice.id
                let color = colorForIndex(index)
                HStack(spacing: 5) {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                    Text(slice.displayName)
                        .font(.caption2.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? color : .secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.15) : Color(.tertiarySystemFill))
                )
                .contentShape(Capsule())
                .onTapGesture { toggleSelection(for: slice.id, isSelected: isSelected) }
                .animation(.easeInOut(duration: 0.18), value: selectedSector?.id)
            }
        }
    }

    // MARK: - Progress Bar Breakdown

    private var breakdownList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sectorData.enumerated()), id: \.element.id) { index, slice in
                let color = colorForIndex(index)
                let isSelected = selectedSector?.id == slice.id

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(slice.displayName)
                            .font(.subheadline.bold())
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(slice.income, format: .currency(code: "USD"))
                                .font(.subheadline.bold())
                                .monospacedDigit()
                            Text("\(slice.percentString)%")
                                .font(.caption2)
                                .foregroundStyle(color)
                                .monospacedDigit()
                        }
                    }

                    // Animated progress bar (scaleEffect replaces GeometryReader)
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

                    // Expanded company list when sector is selected
                    if isSelected {
                        VStack(spacing: 0) {
                            ForEach(holdingsForSector(slice.sector)) { holding in
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
                        .animation(.easeInOut(duration: 0.2), value: selectedSector?.id)
                )
                .contentShape(Rectangle())
                .onTapGesture { toggleSelection(for: slice.id, isSelected: isSelected) }

                if index < sectorData.count - 1 {
                    Divider().padding(.horizontal)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedSector?.id)
        .onAppear { animateBars = true }
        .onDisappear { animateBars = false }
    }

    // MARK: - Helpers

    private func toggleSelection(for id: String, isSelected: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            rawSelectedAngle = isSelected ? nil : angleForSector(id)
        }
    }

    private func holdingsForSector(_ sector: String) -> [Holding] {
        allHoldings.filter { holding in
            guard holding.projectedAnnualIncome > 0 else { return false }
            return normalizedSector(for: holding) == sector
        }
        .sorted { ($0.stock?.ticker ?? "") < ($1.stock?.ticker ?? "") }
    }

    private func angleForSector(_ id: String) -> Double? {
        var cumulative: Double = 0
        for slice in sectorData {
            if slice.id == id {
                return cumulative + slice.doubleIncome / 2
            }
            cumulative += slice.doubleIncome
        }
        return nil
    }

    // MARK: - Colors (auto-adaptive light/dark via UIColor dynamic provider)

    private static let colorPalette: [Color] = [
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

    private var gradientColors: [Color] {
        sectorData.indices.map { Self.colorPalette[$0 % Self.colorPalette.count] }
    }

    private func colorForIndex(_ index: Int) -> Color {
        Self.colorPalette[index % Self.colorPalette.count]
    }
}

// MARK: - Flow Layout (wrapping horizontal chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> LayoutResult {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            maxWidth = max(maxWidth, x + size.width)
            x += size.width + spacing
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: maxWidth, height: y + rowHeight)
        )
    }
}

// MARK: - Data model

private struct SectorSlice: Identifiable {
    let sector: String
    let income: Decimal
    let total: Decimal

    var id: String { sector }
    var displayName: String {
        sector.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    var doubleIncome: Double { (income as NSDecimalNumber).doubleValue }
    var percent: Decimal { total > 0 ? (income / total) * 100 : 0 }
    var fraction: CGFloat { total > 0 ? CGFloat(((income / total) as NSDecimalNumber).doubleValue) : 0 }
    var percentString: String {
        let d = (percent as NSDecimalNumber).doubleValue
        return String(format: "%.1f", d)
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
