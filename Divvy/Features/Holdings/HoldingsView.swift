import SwiftUI
import SwiftData

struct HoldingsView: View {
    @Query(sort: \Portfolio.name) private var portfolios: [Portfolio]
    @State private var showAddPortfolio = false

    var body: some View {
        NavigationStack {
            Group {
                if portfolios.isEmpty {
                    ContentUnavailableView(
                        "No portfolios yet",
                        systemImage: "square.stack",
                        description: Text("Tap + to create your first portfolio.")
                    )
                } else {
                    List {
                        ForEach(portfolios) { portfolio in
                            PortfolioSectionView(portfolio: portfolio)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationDestination(for: Holding.self) { holding in
                        HoldingDetailView(holding: holding)
                    }
                }
            }
            .navigationTitle("Holdings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPortfolio = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add portfolio")
                }
            }
            .sheet(isPresented: $showAddPortfolio) {
                AddPortfolioView()
            }
        }
    }
}

// MARK: - Portfolio Section

private struct PortfolioSectionView: View {
    let portfolio: Portfolio
    @Environment(\.modelContext) private var modelContext
    @State private var showAddHolding = false

    private var sortedHoldings: [Holding] {
        portfolio.holdings.sorted { ($0.stock?.ticker ?? "") < ($1.stock?.ticker ?? "") }
    }

    var body: some View {
        Section {
            if portfolio.holdings.isEmpty {
                Text("No holdings yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedHoldings) { holding in
                    NavigationLink(value: holding) {
                        HoldingRowView(holding: holding)
                    }
                }
                .onDelete { offsets in
                    // Snapshot before mutation — sortedHoldings is computed and
                    // would re-evaluate after each delete, shifting indices.
                    let snapshot = sortedHoldings
                    for index in offsets {
                        modelContext.delete(snapshot[index])
                    }
                }
            }
        } header: {
            HStack {
                Text(portfolio.name)
                Spacer()
                Button {
                    showAddHolding = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add holding to \(portfolio.name)")
            }
            .textCase(nil)
        } footer: {
            if portfolio.projectedMonthlyIncome > 0 {
                Text("Projected \(portfolio.projectedMonthlyIncome.formatted(.currency(code: portfolio.currency)))/mo")
                    .font(.footnote)
            }
        }
        .sheet(isPresented: $showAddHolding) {
            AddHoldingView(portfolio: portfolio)
        }
    }
}

// MARK: - Holding Row

private struct HoldingRowView: View {
    let holding: Holding

    private var ticker: String { holding.stock?.ticker ?? "—" }
    private var companyName: String { holding.stock?.companyName ?? "" }
    private var sharesText: String {
        "\(holding.shares.formatted()) shares"
    }
    private var valueText: String {
        let value = holding.currentValue
        guard value > 0 else { return "—" }
        return value.formatted(.currency(code: holding.currency))
    }
    private var yieldText: String? {
        let y = holding.yieldOnCost
        guard y > 0 else { return nil }
        return "\(y.formatted(.number.precision(.fractionLength(1))))% YOC"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Leading: ticker + company
            VStack(alignment: .leading, spacing: 2) {
                Text(ticker)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !companyName.isEmpty {
                    Text(companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Trailing: shares + value/yield
            VStack(alignment: .trailing, spacing: 2) {
                Text(sharesText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if let yieldText {
                    Text(yieldText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(valueText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [ticker]
        if !companyName.isEmpty { parts.append(companyName) }
        parts.append(sharesText)
        if let yt = yieldText {
            parts.append(yt)
        } else {
            parts.append(valueText)
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Decimal formatting helper

private extension Decimal {
    // Static to avoid allocating a new NumberFormatter on every row render.
    private static let shareFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        return f
    }()

    func formatted() -> String {
        let n = NSDecimalNumber(decimal: self)
        return Decimal.shareFormatter.string(from: n) ?? n.stringValue
    }
}

#Preview {
    HoldingsView()
        .modelContainer(.preview)
}
