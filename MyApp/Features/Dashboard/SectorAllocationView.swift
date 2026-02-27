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

    // MARK: - Sections

    private var chartCard: some View {
        VStack(spacing: 16) {
            Text("Income by Sector")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Chart(sectorData) { slice in
                SectorMark(
                    angle: .value("Income", slice.doubleIncome),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Sector", slice.sector))
                .cornerRadius(4)
            }
            .chartLegend(position: .bottom, alignment: .center, spacing: 8)
            .frame(height: 240)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Annual Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalIncome, format: .currency(code: "USD"))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Sectors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(sectorData.count)")
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var breakdownList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Breakdown")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 12)

            ForEach(sectorData) { slice in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: 4, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(slice.sector)
                            .font(.subheadline.bold())
                        Text(slice.income, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(slice.percentString)%")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                if slice.id != sectorData.last?.id {
                    Divider().padding(.leading)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
