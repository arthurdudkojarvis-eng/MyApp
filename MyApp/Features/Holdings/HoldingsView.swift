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
    @State private var showAddHolding = false

    var body: some View {
        Section {
            if portfolio.holdings.isEmpty {
                Text("No holdings yet")
                    .foregroundStyle(.secondary)
            } else {
                // STORY-006: Holding rows go here
                ForEach(portfolio.holdings) { holding in
                    Text(holding.stock?.ticker ?? "—")
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
        }
        .sheet(isPresented: $showAddHolding) {
            AddHoldingView(portfolio: portfolio)
        }
    }
}

#Preview {
    HoldingsView()
        .modelContainer(.preview)
}
