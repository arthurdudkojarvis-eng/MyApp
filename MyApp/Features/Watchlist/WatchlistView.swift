import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(\.polygonService) private var polygon

    @Query(sort: \WatchlistItem.addedDate, order: .reverse) private var items: [WatchlistItem]

    @State private var showAddSheet = false
    @State private var newTicker = ""
    @State private var addError: String?
    @State private var isAdding = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Watchlist Empty",
                        systemImage: "eye",
                        description: Text("Add tickers you're researching before committing to a position.")
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            WatchlistRow(item: item)
                            if item.id != items.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Watchlist")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: WatchlistItem.self) { item in
            WatchlistItemDetailView(item: item)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: { newTicker = ""; addError = nil }) {
            AddToWatchlistSheet(
                ticker: $newTicker,
                error: $addError,
                isAdding: $isAdding,
                onAdd: addItem
            )
        }
    }

    // MARK: - Actions

    private static let tickerAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))

    private func addItem() {
        let ticker = newTicker.trimmingCharacters(in: .whitespaces).uppercased()
        guard !ticker.isEmpty else { return }

        guard ticker.count <= 12,
              ticker.unicodeScalars.allSatisfy({ Self.tickerAllowed.contains($0) }) else {
            addError = "Ticker must be 1–12 alphanumeric characters."
            return
        }

        // Prevent duplicates
        if items.contains(where: { $0.ticker == ticker }) {
            addError = "\(ticker) is already in your watchlist."
            return
        }

        let item = WatchlistItem(ticker: ticker)
        modelContext.insert(item)
        showAddSheet = false
    }

}

// MARK: - Watchlist Row

private struct WatchlistRow: View {
    let item: WatchlistItem
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationLink(value: item) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.ticker)
                        .font(.headline)
                    if !item.companyName.isEmpty {
                        Text(item.companyName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Tap to load details")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Text(item.addedDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Watchlist Item Detail

struct WatchlistItemDetailView: View {
    let item: WatchlistItem

    @Environment(\.modelContext) private var modelContext

    // Construct a lightweight result for StockDetailView
    private var searchResult: PolygonTickerSearchResult {
        PolygonTickerSearchResult(
            ticker: item.ticker,
            name: item.companyName.isEmpty ? item.ticker : item.companyName,
            market: "stocks",
            type: nil,
            primaryExchange: nil
        )
    }

    var body: some View {
        StockDetailView(result: searchResult)
    }
}

// MARK: - Add to Watchlist Sheet

private struct AddToWatchlistSheet: View {
    @Binding var ticker: String
    @Binding var error: String?
    @Binding var isAdding: Bool
    let onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ticker symbol (e.g. AAPL)", text: $ticker)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($isFocused)
                        .onChange(of: ticker) { _, _ in error = nil }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add to Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd() }
                        .disabled(ticker.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        WatchlistView()
    }
    .modelContainer(container)
    .environment(settings)
    .environment(StockRefreshService(settings: settings, container: container))
}
