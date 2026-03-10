import SwiftUI

private let sectorChips: [String] = [
    "Technology", "Healthcare", "Finance", "Energy",
    "Consumer Cyclical", "Industrials", "Real Estate",
    "Utilities", "Communication", "Materials"
]

struct ETFBrowserView: View {
    @Environment(\.massiveService) private var massive

    @State private var query = ""
    @State private var results: [MassiveTickerSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var showTips = false
    @State private var showScreener = false

    // Filter state
    @State private var showFilters = false
    @State private var selectedSector: String?
    @State private var minDividendYield: Double = 0
    @State private var marketCapRange: MarketCapRange = .any
    @State private var enrichedDetails: [String: MassiveTickerDetails] = [:]
    @State private var enrichedYields: [String: Decimal] = [:]
    @State private var isEnriching = false
    @State private var enrichTask: Task<Void, Never>?

    private var hasActiveFilters: Bool {
        selectedSector != nil || minDividendYield > 0 || marketCapRange != .any
    }

    private var filteredResults: [MassiveTickerSearchResult] {
        guard hasActiveFilters else { return results }
        return results.filter { result in
            let details = enrichedDetails[result.ticker]

            // Sector filter
            if let sector = selectedSector {
                guard let sic = details?.sicDescription,
                      sic.localizedCaseInsensitiveContains(sector) else { return false }
            }

            // Market cap filter
            if marketCapRange != .any {
                guard marketCapRange.matches(marketCap: details?.marketCap) else { return false }
            }

            // Yield filter
            if minDividendYield > 0 {
                guard let yield = enrichedYields[result.ticker],
                      (yield as NSDecimalNumber).doubleValue >= minDividendYield else { return false }
            }

            return true
        }
    }

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
                    let displayed = filteredResults
                    if displayed.isEmpty && hasActiveFilters {
                        ContentUnavailableView(
                            "No Matches",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Try adjusting your filters.")
                        )
                    } else {
                        resultsList(displayed)
                    }
                }
            }
            .searchable(text: $query, prompt: "ETF ticker or name")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Button {
                            showTips = true
                        } label: {
                            Image(systemName: "lightbulb")
                        }
                        .accessibilityLabel("ETF tips")

                        Button {
                            showScreener = true
                        } label: {
                            Image(systemName: "sparkle.magnifyingglass")
                        }
                        .accessibilityLabel("ETF screener")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { showFilters.toggle() }
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .sheet(isPresented: $showTips) {
                ETFTipsView()
            }
            .sheet(isPresented: $showScreener) {
                ETFScreenerView()
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

    // MARK: - Results List

    @ViewBuilder
    private func resultsList(_ displayed: [MassiveTickerSearchResult]) -> some View {
        List {
            if showFilters {
                filterSection
            }

            ForEach(displayed) { result in
                NavigationLink {
                    StockDetailView(result: result)
                } label: {
                    ETFSearchRowView(result: result)
                }
            }

            if isEnriching {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading details…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        Section {
            // Sector chips
            VStack(alignment: .leading, spacing: 6) {
                Text("Sector").font(.caption.bold()).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sectorChips, id: \.self) { sector in
                            Button {
                                withAnimation {
                                    selectedSector = selectedSector == sector ? nil : sector
                                }
                                triggerEnrichIfNeeded()
                            } label: {
                                Text(sector)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedSector == sector ? Color.accentColor : Color(.tertiarySystemFill))
                                    .foregroundStyle(selectedSector == sector ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Market cap picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Market Cap").font(.caption.bold()).foregroundStyle(.secondary)
                Picker("Market Cap", selection: $marketCapRange) {
                    ForEach(MarketCapRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: marketCapRange) { _, _ in triggerEnrichIfNeeded() }
            }

            // Dividend yield slider
            VStack(alignment: .leading, spacing: 6) {
                Text("Min Dividend Yield: \(minDividendYield, specifier: "%.1f")%")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Slider(value: $minDividendYield, in: 0...15, step: 0.5)
                    .onChange(of: minDividendYield) { _, _ in triggerEnrichIfNeeded() }
            }

            // Clear all
            if hasActiveFilters {
                Button("Clear All Filters", role: .destructive) {
                    withAnimation {
                        selectedSector = nil
                        minDividendYield = 0
                        marketCapRange = .any
                    }
                }
                .font(.caption)
            }
        } header: {
            Text("Filters")
        }
    }

    // MARK: - Search

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
            if showFilters && hasActiveFilters {
                triggerEnrichIfNeeded()
            }
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error.localizedDescription
            results = []
        }
    }

    // MARK: - Enrichment Pipeline

    private func triggerEnrichIfNeeded() {
        guard showFilters, !results.isEmpty else { return }
        enrichTask?.cancel()
        enrichTask = Task { await enrichResults() }
    }

    private func enrichResults() async {
        isEnriching = true
        defer { if !Task.isCancelled { isEnriching = false } }

        let api = massive.service
        let toEnrich = Array(results.prefix(20))
        let needYield = minDividendYield > 0

        await withTaskGroup(of: (String, MassiveTickerDetails?, Decimal?).self) { group in
            for result in toEnrich {
                let hasDetails = enrichedDetails[result.ticker] != nil
                let hasYield = enrichedYields[result.ticker] != nil
                if hasDetails && (!needYield || hasYield) { continue }

                group.addTask { @Sendable in
                    let ticker = result.ticker
                    var details: MassiveTickerDetails?
                    var yield: Decimal?

                    if !hasDetails {
                        details = try? await api.fetchTickerDetails(ticker: ticker)
                    }

                    if needYield && !hasYield {
                        let divs = (try? await api.fetchDividends(ticker: ticker, limit: 4)) ?? []
                        let price = try? await api.fetchPreviousClose(ticker: ticker)

                        if let latest = divs.first, let p = price, p > 0 {
                            let freq = Decimal(latest.frequency ?? 4)
                            let annual = latest.cashAmount * freq
                            yield = (annual / p) * 100
                        }
                    }

                    return (ticker, details, yield)
                }
            }

            for await (ticker, details, yield) in group {
                guard !Task.isCancelled else { return }
                if let details { enrichedDetails[ticker] = details }
                if let yield { enrichedYields[ticker] = yield }
            }
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
