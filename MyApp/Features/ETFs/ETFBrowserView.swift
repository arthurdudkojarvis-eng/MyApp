import SwiftUI

struct ETFBrowserView: View {
    @Environment(\.massiveService) private var massive

    @State private var query = ""
    @State private var results: [MassiveTickerSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var showTips = false

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView(
                        "Search ETFs",
                        systemImage: "chart.pie",
                        description: Text("Type an ETF ticker or name to look up exchange-traded funds.")
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
                            ETFSearchRowView(result: result)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("ETFs")
            .searchable(text: $query, prompt: "ETF ticker or name")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTips = true
                    } label: {
                        Image(systemName: "lightbulb")
                    }
                    .accessibilityLabel("ETF tips")
                }
            }
            .sheet(isPresented: $showTips) {
                ETFTipsView()
            }
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
                query: query
            )
            guard !Task.isCancelled else { return }
            let etfOnly = fetched.filter { $0.type?.uppercased() == "ETF" }
            let upper = query.uppercased()
            results = etfOnly.sorted { a, b in
                let aExact = a.ticker == upper
                let bExact = b.ticker == upper
                if aExact != bExact { return aExact }
                let aPrefix = a.ticker.hasPrefix(upper)
                let bPrefix = b.ticker.hasPrefix(upper)
                if aPrefix != bPrefix { return aPrefix }
                return false
            }
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error.localizedDescription
            results = []
        }
    }
}

// MARK: - ETF Search Row

private struct ETFSearchRowView: View {
    let result: MassiveTickerSearchResult

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.ticker)
                    .font(.headline)
                Text(result.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let exchange = result.primaryExchange {
                Text(exchange)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.ticker), \(result.name)")
    }
}

// MARK: - Preview

#Preview {
    ETFBrowserView()
}
