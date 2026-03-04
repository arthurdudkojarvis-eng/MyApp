import SwiftUI
import Charts

struct DividendIncomeHistoryView: View {
    let portfolio: Portfolio
    @Environment(\.dismiss) private var dismiss

    @State private var grouping: IncomeGrouping = .monthly

    private var paidPayments: [DividendPayment] {
        portfolio.holdings.flatMap(\.dividendPayments)
    }

    private var monthlyData: [IncomeBar] {
        let cal = Calendar.current
        var byMonth: [String: Decimal] = [:]
        var monthKeys: [String] = []

        for payment in paidPayments {
            let comps = cal.dateComponents([.year, .month], from: payment.receivedDate)
            let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
            byMonth[key, default: .zero] += payment.totalAmount
            if !monthKeys.contains(key) { monthKeys.append(key) }
        }

        // Fill in the last 12 months (even if $0)
        let now = Date.now
        var allKeys: [String] = []
        for offset in (0..<12).reversed() {
            if let date = cal.date(byAdding: .month, value: -offset, to: now) {
                let comps = cal.dateComponents([.year, .month], from: date)
                let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
                allKeys.append(key)
            }
        }
        // Merge user's keys that are older
        for key in monthKeys where !allKeys.contains(key) {
            allKeys.append(key)
        }
        allKeys.sort()

        return allKeys.map { key in
            IncomeBar(label: formatMonthLabel(key), amount: ((byMonth[key] ?? Decimal.zero) as NSDecimalNumber).doubleValue, sortKey: key)
        }
    }

    private var yearlyData: [IncomeBar] {
        let cal = Calendar.current
        var byYear: [String: Decimal] = [:]

        for payment in paidPayments {
            let year = cal.component(.year, from: payment.receivedDate)
            let key = "\(year)"
            byYear[key, default: .zero] += payment.totalAmount
        }

        let currentYear = cal.component(.year, from: .now)
        for y in max(currentYear - 4, (byYear.keys.compactMap { Int($0) }.min() ?? currentYear))...currentYear {
            let key = "\(y)"
            if byYear[key] == nil { byYear[key] = .zero }
        }

        return byYear.sorted { $0.key < $1.key }.map { key, value in
            IncomeBar(label: key, amount: (value as NSDecimalNumber).doubleValue, sortKey: key)
        }
    }

    private var displayData: [IncomeBar] {
        grouping == .monthly ? monthlyData : yearlyData
    }

    private var totalReceived: Decimal {
        paidPayments.reduce(.zero) { $0 + $1.totalAmount }
    }

    var body: some View {
        NavigationStack {
            Group {
                if paidPayments.isEmpty {
                    ContentUnavailableView(
                        "No Dividend History",
                        systemImage: "chart.bar",
                        description: Text("Received dividend payments will appear here after they are marked as paid.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            groupingPicker
                            chartCard
                            totalCard
                            detailList
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Income History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Views

    private var groupingPicker: some View {
        Picker("Grouping", selection: $grouping) {
            Text("Monthly").tag(IncomeGrouping.monthly)
            Text("Yearly").tag(IncomeGrouping.yearly)
        }
        .pickerStyle(.segmented)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dividend Income")
                .font(.headline)

            Chart(displayData) { bar in
                BarMark(
                    x: .value("Period", bar.label),
                    y: .value("Amount", bar.amount)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(d >= 1000 ? "$\(Int(d / 1000))k" : "$\(Int(d))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            Text(s).font(.caption2)
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

    private var totalCard: some View {
        HStack {
            Text("Total Received")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(totalReceived, format: .currency(code: "USD"))
                .font(.headline)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var detailList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Payments by Stock")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 12)

            let byTicker = Dictionary(grouping: paidPayments) { $0.holding?.stock?.ticker ?? "Unknown" }
            let sorted = byTicker.sorted { $0.key < $1.key }

            ForEach(sorted, id: \.key) { ticker, payments in
                HStack {
                    Text(ticker)
                        .font(.subheadline.bold())
                    Spacer()
                    let total = payments.reduce(Decimal.zero) { $0 + $1.totalAmount }
                    Text(total, format: .currency(code: "USD"))
                        .font(.subheadline)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if ticker != sorted.last?.key {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers

    private func formatMonthLabel(_ key: String) -> String {
        // "2026-03" → "Mar"
        let parts = key.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else { return key }
        let symbols = Calendar.current.shortMonthSymbols
        guard month >= 1, month <= 12 else { return key }
        return symbols[month - 1]
    }
}

// MARK: - Supporting types

private enum IncomeGrouping {
    case monthly, yearly
}

private struct IncomeBar: Identifiable {
    let label: String
    let amount: Double
    let sortKey: String
    var id: String { sortKey }
}
