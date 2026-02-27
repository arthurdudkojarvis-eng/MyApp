import SwiftUI
import SwiftData
import Charts

struct DRIPSimulatorView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]

    @State private var years: Int = 10
    @State private var reinvestmentRate: Double = 100

    private var allHoldings: [Holding] { portfolios.flatMap(\.holdings) }

    private var initialMonthlyIncome: Decimal {
        allHoldings.reduce(0) { $0 + $1.projectedMonthlyIncome }
    }

    private var initialAnnualIncome: Decimal { initialMonthlyIncome * 12 }

    private var initialPortfolioValue: Decimal {
        allHoldings.reduce(0) { $0 + $1.currentValue }
    }

    private var averageYield: Double {
        let value = (initialPortfolioValue as NSDecimalNumber).doubleValue
        let income = (initialAnnualIncome as NSDecimalNumber).doubleValue
        guard value > 0 else { return 0 }
        return income / value
    }

    /// Year-by-year projection. Reinvested dividends compound at the same average yield.
    private var projectionData: [YearProjection] {
        var results: [YearProjection] = []
        var portfolioValue = (initialPortfolioValue as NSDecimalNumber).doubleValue
        let reinvestFraction = reinvestmentRate / 100.0

        for year in 0...years {
            let annualIncome = portfolioValue * averageYield
            results.append(YearProjection(year: year, annualIncome: annualIncome, portfolioValue: portfolioValue))
            let reinvested = annualIncome * reinvestFraction
            portfolioValue += reinvested
        }
        return results
    }

    private var finalProjection: YearProjection? { projectionData.last }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                controlsCard
                if !allHoldings.isEmpty {
                    resultsCard
                    chartCard
                    holdingsNoteCard
                } else {
                    ContentUnavailableView(
                        "No Holdings",
                        systemImage: "arrow.trianglehead.2.clockwise",
                        description: Text("Add holdings to run the DRIP simulator.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("DRIP Simulator")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var controlsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projection Period")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(years) years")
                        .font(.headline)
                }
                Spacer()
                Stepper("", value: $years, in: 1...40)
                    .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Reinvestment Rate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(reinvestmentRate))%")
                        .font(.headline)
                        .monospacedDigit()
                }
                Slider(value: $reinvestmentRate, in: 0...100, step: 5)
                    .tint(.accentColor)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Starting Portfolio Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(initialPortfolioValue, format: .currency(code: "USD"))
                        .font(.subheadline.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Current Annual Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(initialAnnualIncome, format: .currency(code: "USD"))
                        .font(.subheadline.bold())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var resultsCard: some View {
        HStack(spacing: 0) {
            resultCell(
                label: "Year \(years) Income",
                value: finalProjection.map {
                    Decimal($0.annualIncome).formatted(.currency(code: "USD"))
                } ?? "—",
                isHighlighted: true
            )
            Divider().frame(height: 60)
            resultCell(
                label: "Growth",
                value: incomeGrowthLabel,
                isHighlighted: false
            )
            Divider().frame(height: 60)
            resultCell(
                label: "Portfolio Value",
                value: finalProjection.map {
                    Decimal($0.portfolioValue).formatted(.currency(code: "USD"))
                } ?? "—",
                isHighlighted: false
            )
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var incomeGrowthLabel: String {
        guard let final = finalProjection else { return "—" }
        let initial = (initialAnnualIncome as NSDecimalNumber).doubleValue
        guard initial > 0 else { return "—" }
        let growth = ((final.annualIncome - initial) / initial) * 100
        return String(format: "+%.0f%%", growth)
    }

    private func resultCell(label: String, value: String, isHighlighted: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(isHighlighted ? Color.accentColor : .primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Annual Income Growth")
                .font(.headline)

            Chart(projectionData) { item in
                AreaMark(
                    x: .value("Year", item.year),
                    y: .value("Income", item.annualIncome)
                )
                .foregroundStyle(Color.accentColor.opacity(0.2))

                LineMark(
                    x: .value("Year", item.year),
                    y: .value("Income", item.annualIncome)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis {
                let step = max(1, years / 5)
                AxisMarks(values: Array(Swift.stride(from: 0, through: years, by: step))) { value in
                    AxisValueLabel {
                        if let y = value.as(Int.self) {
                            Text("Y\(y)").font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            let label = d >= 1000 ? "$\(Int(d / 1000))k" : "$\(Int(d))"
                            Text(label).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var holdingsNoteCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Assumes a constant dividend yield equal to current portfolio average. Reinvested dividends purchase additional shares at current prices. Actual results will vary with price changes and yield fluctuations.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Data model

private struct YearProjection: Identifiable {
    let year: Int
    let annualIncome: Double
    let portfolioValue: Double

    var id: Int { year }
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
