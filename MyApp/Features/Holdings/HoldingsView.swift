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
                            Section(portfolio.name) {
                                // STORY-005/006: Holdings per portfolio
                                Text("No holdings yet")
                                    .foregroundStyle(.secondary)
                            }
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

#Preview {
    HoldingsView()
        .modelContainer(.preview)
}
