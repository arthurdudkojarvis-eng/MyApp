import SwiftUI

struct CryptoBrowserView: View {
    @Environment(\.massiveService) private var massive

    @State private var query = ""
    @State private var results: [MassiveTickerSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView(
                        "Search Crypto",
                        systemImage: "bitcoinsign.circle",
                        description: Text("Type a cryptocurrency name or ticker to look up prices and details.")
                    )
                } else if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = searchError {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { result in
                        NavigationLink {
                            StockDetailView(result: result)
                        } label: {
                            CryptoSearchRowView(result: result)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: "Crypto name or ticker")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    results = []
                    searchError = nil
                    isSearching = false
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }
                    await search(query: trimmed)
                }
            }
        }
    }

    private func search(query: String) async {
        isSearching = true
        searchError = nil
        defer { if !Task.isCancelled { isSearching = false } }
        do {
            let fetched = try await massive.service.fetchTickerSearch(
                query: query, market: "crypto"
            )
            guard !Task.isCancelled else { return }
            // Crypto tickers are "X:BTCUSD", "X:BTCEUR", etc.
            // Prioritize USD pairs, then sort by relevance.
            let upper = query.uppercased()
            results = fetched
                .filter { $0.ticker.hasSuffix("USD") }
                .sorted { a, b in
                    let aExact = a.ticker == "X:\(upper)USD"
                    let bExact = b.ticker == "X:\(upper)USD"
                    if aExact != bExact { return aExact }
                    let aPrefix = a.ticker.hasPrefix("X:\(upper)")
                    let bPrefix = b.ticker.hasPrefix("X:\(upper)")
                    if aPrefix != bPrefix { return aPrefix }
                    return false
                }
        } catch let error as MassiveError {
            guard !Task.isCancelled else { return }
            if case .httpError(let code) = error, code == 403 {
                searchError = "Crypto data is not available on the current API plan."
            } else {
                searchError = error.localizedDescription
            }
            results = []
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error.localizedDescription
            results = []
        }
    }
}

// MARK: - Crypto Search Row

private struct CryptoSearchRowView: View {
    let result: MassiveTickerSearchResult

    /// Strips "X:" prefix for display — "X:BTCUSD" → "BTCUSD"
    private var displayTicker: String {
        result.ticker.hasPrefix("X:") ? String(result.ticker.dropFirst(2)) : result.ticker
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTicker)
                    .font(.headline)
                Text(result.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("USD")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayTicker), \(result.name)")
    }
}

// MARK: - Preview

#Preview {
    CryptoBrowserView()
}
