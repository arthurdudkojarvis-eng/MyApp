import SwiftUI
import SwiftData

struct HoldingDetailView: View {
    let holding: Holding

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    private var stock: Stock? { holding.stock }

    var body: some View {
        List {
            // MARK: Position
            Section("Position") {
                LabeledRow("Ticker", value: stock?.ticker ?? "—")
                if let name = stock?.companyName, !name.isEmpty {
                    LabeledRow("Company", value: name)
                }
                LabeledRow("Shares", value: holding.shares.formatted())
                LabeledRow("Cost Basis / Share",
                           value: holding.averageCostBasis.formatted(.currency(code: holding.currency)))
                LabeledRow("Purchase Date",
                           value: holding.purchaseDate.formatted(date: .abbreviated, time: .omitted))
            }

            // MARK: Market
            Section("Market") {
                if let price = stock?.currentPrice, price > 0 {
                    LabeledRow("Current Price",
                               value: price.formatted(.currency(code: holding.currency)))
                    LabeledRow("Current Value",
                               value: holding.currentValue.formatted(.currency(code: holding.currency)))
                    LabeledRow("Current Yield",
                               value: "\(holding.currentYield.formatted(.number.precision(.fractionLength(2))))%")
                } else {
                    HStack {
                        Text("Market data")
                        Spacer()
                        Text("Not loaded yet")
                            .textStyle(.controlLabel)
                    }
                }
            }

            // MARK: Income
            Section("Dividend Income") {
                if holding.projectedAnnualIncome > 0 {
                    LabeledRow("Yield on Cost",
                               value: "\(holding.yieldOnCost.formatted(.number.precision(.fractionLength(2))))%")
                    LabeledRow("Projected / Year",
                               value: holding.projectedAnnualIncome.formatted(.currency(code: holding.currency)))
                    LabeledRow("Projected / Month",
                               value: holding.projectedMonthlyIncome.formatted(.currency(code: holding.currency)))
                } else {
                    HStack {
                        Text("Dividend data")
                        Spacer()
                        Text("Not loaded yet")
                            .textStyle(.controlLabel)
                    }
                }
            }

            // MARK: Delete
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Holding")
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(stock?.ticker ?? "Holding")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditHoldingView(holding: holding)
        }
        .confirmationDialog(
            "Delete \(stock?.ticker ?? "this holding")?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Holding", role: .destructive) {
                modelContext.delete(holding)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the holding and its dividend payment history.")
        }
    }
}

// MARK: - Labeled Row

private struct LabeledRow: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    let container = ModelContainer.preview
    let stock = Stock(ticker: "AAPL", companyName: "Apple Inc.", currentPrice: 185)
    let holding = Holding(shares: 10, averageCostBasis: 150)
    holding.stock = stock
    container.mainContext.insert(stock)
    container.mainContext.insert(holding)
    return NavigationStack {
        HoldingDetailView(holding: holding)
    }
    .modelContainer(container)
}
