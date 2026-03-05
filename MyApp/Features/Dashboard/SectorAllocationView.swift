import SwiftUI
import SwiftData
import Charts

struct SectorAllocationView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    private var allHoldings: [Holding] { portfolios.flatMap(\.holdings) }

    private var sectorData: [SectorSlice] {
        var map: [String: Decimal] = [:]
        for holding in allHoldings {
            let sector = holding.stock.flatMap { $0.sector.isEmpty ? nil : $0.sector } ?? "Unclassified"
            map[sector, default: 0] += holding.projectedAnnualIncome
        }
        let total = map.values.reduce(0, +)
        return map
            .map { SectorSlice(sector: $0.key, income: $0.value, total: total) }
            .sorted { $0.income > $1.income }
    }

    private var totalIncome: Decimal {
        sectorData.reduce(0) { $0 + $1.income }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if allHoldings.isEmpty {
                    ContentUnavailableView(
                        "No Holdings",
                        systemImage: "chart.pie",
                        description: Text("Add holdings to see your sector allocation.")
                    )
                    .padding(.top, 60)
                } else {
                    chartCard
                    breakdownList
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Sector Allocation")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Donut Chart with Center Label

    private var chartCard: some View {
        VStack(spacing: 16) {
            Text("Income by Sector")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Chart(sectorData) { slice in
                    SectorMark(
                        angle: .value("Income", slice.doubleIncome),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Sector", slice.sector))
                    .cornerRadius(5)
                }
                .chartForegroundStyleScale(domain: sectorData.map(\.sector), range: sectorGradientColors)
                .chartLegend(.hidden)
                .frame(height: 220)

                // Center label
                VStack(spacing: 2) {
                    Text(totalIncome, format: .currency(code: "USD"))
                        .font(.title3.bold())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("per year")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }

            // Inline legend chips
            legendChips
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var legendChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(sectorData.enumerated()), id: \.element.id) { index, slice in
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForIndex(index))
                        .frame(width: 8, height: 8)
                    Text(slice.sector)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Progress Bar Breakdown

    private var breakdownList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sectorData.enumerated()), id: \.element.id) { index, slice in
                VStack(alignment: .leading, spacing: 8) {
                    // Header: sector name + percentage
                    HStack {
                        Text(slice.sector)
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(slice.percentString)%")
                            .font(.subheadline.bold())
                            .foregroundStyle(colorForIndex(index))
                            .monospacedDigit()
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(colorForIndex(index).opacity(0.15))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    LinearGradient(
                                        colors: [colorForIndex(index).opacity(0.7), colorForIndex(index)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * slice.fraction, height: 8)
                        }
                    }
                    .frame(height: 8)

                    // Income amount
                    Text(slice.income, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                if index < sectorData.count - 1 {
                    Divider().padding(.leading)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Colors

    private var sectorGradientColors: [Color] {
        sectorData.indices.map { colorForIndex($0) }
    }

    private func colorForIndex(_ index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.30, green: 0.70, blue: 0.95),  // sky blue
            Color(red: 0.35, green: 0.80, blue: 0.55),  // mint green
            Color(red: 0.95, green: 0.60, blue: 0.30),  // warm orange
            Color(red: 0.70, green: 0.45, blue: 0.90),  // soft purple
            Color(red: 0.95, green: 0.40, blue: 0.45),  // coral red
            Color(red: 0.25, green: 0.60, blue: 0.75),  // teal
            Color(red: 0.90, green: 0.75, blue: 0.30),  // gold
            Color(red: 0.55, green: 0.70, blue: 0.35),  // olive
            Color(red: 0.85, green: 0.45, blue: 0.65),  // rose
            Color(red: 0.50, green: 0.55, blue: 0.80),  // indigo
        ]
        return palette[index % palette.count]
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
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
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
