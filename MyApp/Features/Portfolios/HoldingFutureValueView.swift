import SwiftUI
import Charts

struct HoldingFutureValueView: View {
    let holding: Holding

    @Environment(\.dismiss) private var dismiss

    @State private var years: Int = 10
    @State private var appreciationRate: Double = 7.0

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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Controls

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
                    Text("Appreciation Rate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Decimal(initialValue), format: .currency(code: "USD"))
                        .font(.subheadline.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Yield on Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .font(.headline)

            Chart(projectionData) { point in
                AreaMark(
                    x: .value("Year", point.year),
                    y: .value("Value", point.withDRIP)
                )
                .foregroundStyle(Color.accentColor.opacity(0.15))

                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Value", point.withDRIP)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Value", point.withoutDRIP)
                )
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
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
                            Text(compactDollar(d)).font(.caption2)
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
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary)
                        .frame(width: 16, height: 3)
                    Text("Without DRIP")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
            summaryCell(label: "Without DRIP", value: compactDollar(finalWithoutDRIP), color: .secondary)
            Divider().frame(height: 50)
            summaryCell(label: "With DRIP", value: compactDollar(finalWithDRIP), color: .accentColor)
            Divider().frame(height: 50)
            summaryCell(label: "DRIP Advantage", value: "+\(compactDollar(dripAdvantage))", color: .green)
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
