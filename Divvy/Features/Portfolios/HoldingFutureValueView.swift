import SwiftUI
import Charts

struct HoldingFutureValueView: View {
    let holding: Holding

    @Environment(\.dismiss) private var dismiss

    @State private var years: Int = 10
    @State private var appreciationRate: Double = 7.0
    @State private var infoText: String?

    private var ticker: String { holding.stock?.ticker ?? "—" }

    private var initialValue: Double {
        (holding.currentValue as NSDecimalNumber).doubleValue
    }

    private var annualYield: Double {
        let yoc = (holding.yieldOnCost as NSDecimalNumber).doubleValue
        return yoc / 100.0
    }

    private var projectionData: [FutureValuePoint] {
        var withDRIP = initialValue
        var withoutDRIP = initialValue
        let rate = appreciationRate / 100.0
        var points: [FutureValuePoint] = []

        for year in 0...years {
            points.append(FutureValuePoint(
                year: year,
                withDRIP: withDRIP,
                withoutDRIP: withoutDRIP
            ))
            // Without DRIP: price appreciation only, dividends taken as cash
            withoutDRIP *= (1 + rate)

            // With DRIP: appreciation + reinvested dividends compound
            let dividends = withDRIP * annualYield
            withDRIP = withDRIP * (1 + rate) + dividends
        }
        return points
    }

    private var finalWithDRIP: Double { projectionData.last?.withDRIP ?? 0 }
    private var finalWithoutDRIP: Double { projectionData.last?.withoutDRIP ?? 0 }
    private var dripAdvantage: Double { finalWithDRIP - finalWithoutDRIP }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    controlsCard
                    if initialValue > 0 {
                        chartCard
                        summaryCards
                    } else {
                        ContentUnavailableView(
                            "No Price Data",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Price data is needed to project future value.")
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Future Value — \(ticker)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("What does this mean?", isPresented: Binding(
            get: { infoText != nil },
            set: { if !$0 { infoText = nil } }
        )) {
            Button("Got it", role: .cancel) { infoText = nil }
        } message: {
            Text(infoText ?? "")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Controls

    private var controlsCard: some View {
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
                    Text("Appreciation Rate")
                        .textStyle(.controlLabel)
                    Spacer()
                    Text("\(String(format: "%.1f", appreciationRate))%")
                        .font(.headline)
                        .monospacedDigit()
                }
                Slider(value: $appreciationRate, in: 0...15, step: 0.5)
                    .tint(.accentColor)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Value")
                        .textStyle(.rowDetail)
                    Text(Decimal(initialValue), format: .currency(code: "USD"))
                        .font(.subheadline.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Yield on Cost")
                        .textStyle(.rowDetail)
                    Text("\(String(format: "%.2f", annualYield * 100))%")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Growth Projection")
                .textStyle(.sectionTitle)

            Chart(projectionData) { point in
                AreaMark(
                    x: .value("Year", point.year),
                    y: .value("Value", point.withDRIP),
                    series: .value("Series", "With DRIP")
                )
                .foregroundStyle(Color.accentColor.opacity(0.15))

                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Value", point.withDRIP),
                    series: .value("Series", "With DRIP")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Value", point.withoutDRIP),
                    series: .value("Series", "Without DRIP")
                )
                .foregroundStyle(.gray)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
            .chartXAxis {
                let step = max(1, years / 5)
                AxisMarks(values: Array(Swift.stride(from: 0, through: years, by: step))) { value in
                    AxisValueLabel {
                        if let y = value.as(Int.self) {
                            Text("Y\(y)").textStyle(.chartAxis)
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
                            Text(compactDollar(d)).textStyle(.chartAxis)
                        }
                    }
                }
            }
            .frame(height: 200)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 3)
                    Text("With DRIP")
                        .textStyle(.statLabel)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray)
                        .frame(width: 16, height: 3)
                    Text("Without DRIP")
                        .textStyle(.statLabel)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("Growth chart showing \(ticker) value over \(years) years with and without dividend reinvestment")
    }

    // MARK: - Summary

    private var summaryCards: some View {
        HStack(spacing: 0) {
            summaryCell(
                label: "Without DRIP",
                value: compactDollar(finalWithoutDRIP),
                color: .secondary,
                info: "Projected value if you take dividends as cash and only benefit from stock price appreciation. No dividends are reinvested."
            )
            Divider().frame(height: 50)
            summaryCell(
                label: "With DRIP",
                value: compactDollar(finalWithDRIP),
                color: .accentColor,
                info: "Projected value if you reinvest all dividends back into the same stock (Dividend Reinvestment Plan). Dividends buy more shares, which generate more dividends — creating a compounding snowball effect."
            )
            Divider().frame(height: 50)
            summaryCell(
                label: "DRIP Advantage",
                value: "+\(compactDollar(dripAdvantage))",
                color: .green,
                info: "The extra money you would earn by reinvesting dividends instead of taking them as cash. This grows significantly over longer time periods due to compound interest."
            )
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summaryCell(label: String, value: String, color: Color, info: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack(spacing: 2) {
                Text(label)
                    .textStyle(.statLabel)
                Button {
                    infoText = info
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func compactDollar(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.1f", value / 1_000_000))M"
        } else if value >= 1_000 {
            return "$\(String(format: "%.1f", value / 1_000))k"
        }
        return "$\(Int(value))"
    }
}

// MARK: - Data model

private struct FutureValuePoint: Identifiable {
    let year: Int
    let withDRIP: Double
    let withoutDRIP: Double
    var id: Int { year }
}
