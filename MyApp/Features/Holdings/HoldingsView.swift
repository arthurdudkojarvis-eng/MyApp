import SwiftUI
import SwiftData

struct HoldingsView: View {
    @Query(sort: \Portfolio.name) private var portfolios: [Portfolio]

    var body: some View {
        NavigationStack {
            Group {
                if portfolios.isEmpty {
                    // STORY-004: Add Portfolio prompt
                    ContentUnavailableView(
                        "No portfolios yet",
                        systemImage: "square.stack",
                        description: Text("Create a portfolio to start tracking your holdings.")
                    )
                } else {
                    // STORY-006: Holdings list goes here
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
                        // STORY-004/005: Add holding or portfolio
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    HoldingsView()
        .modelContainer(.preview)
}
