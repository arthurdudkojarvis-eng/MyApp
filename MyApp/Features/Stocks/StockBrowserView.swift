import SwiftUI
import SwiftData

// MARK: - StockBrowserView

struct StockBrowserView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.polygonService) private var polygon

    @State private var query = ""
    @State private var results: [PolygonTickerSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView(
                        "Search Stocks",
                        systemImage: "magnifyingglass",
                        description: Text("Type a ticker or company name to look up a stock.")
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
                            StockSearchRowView(result: result)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Stocks")
            .searchable(text: $query, prompt: "Ticker or company name")
            .onChange(of: query) { _, newValue in
                // Cancel the previous in-flight search before starting a new one.
                // The 350 ms sleep absorbs fast keystrokes so we only hit the API
                // once the user has paused — important for FMP's free tier (250 req/day).
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    results = []
                    searchError = nil
                    isSearching = false     // cancel may leave spinner visible
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
        guard settings.hasAPIKey else {
            searchError = "Add an FMP API key in Settings to search stocks."
            return
        }
        isSearching = true
        searchError = nil
        // Only reset the spinner if this task ran to completion (not cancelled).
        // A cancelled task skips the reset so the newer task's defer handles it —
        // preventing the spinner from flickering off while the next search is running.
        defer { if !Task.isCancelled { isSearching = false } }
        do {
            let fetched = try await polygon.service.fetchTickerSearch(
                query: query, apiKey: settings.fmpAPIKey
            )
            // Discard stale responses superseded by a newer query.
            guard !Task.isCancelled else { return }
            // Re-sort: exact ticker match first, then starts-with, then FMP's order.
            let upper = query.uppercased()
            results = fetched.sorted { a, b in
                let aExact = a.ticker == upper
                let bExact = b.ticker == upper
                if aExact != bExact { return aExact }
                let aPrefix = a.ticker.hasPrefix(upper)
                let bPrefix = b.ticker.hasPrefix(upper)
                if aPrefix != bPrefix { return aPrefix }
                return false // preserve FMP order within each tier
            }
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error.localizedDescription
            results = []
        }
    }
}

// MARK: - Search Row

private struct StockSearchRowView: View {
    let result: PolygonTickerSearchResult

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

// MARK: - Stock Detail

struct StockDetailView: View {
    let result: PolygonTickerSearchResult

    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(StockRefreshService.self) private var stockRefresh
    @Environment(\.polygonService) private var polygon
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    // Filtered to only the current ticker so SwiftData doesn't load the entire watchlist.
    @Query private var watchlistItems: [WatchlistItem]

    init(result: PolygonTickerSearchResult) {
        self.result = result
        let ticker = result.ticker
        _watchlistItems = Query(filter: #Predicate<WatchlistItem> { $0.ticker == ticker })
    }

    @State private var details: PolygonTickerDetails?
    @State private var currentPrice: Decimal?
    @State private var dividends: [PolygonDividend] = []
    @State private var isLoading = true
    @State private var loadError: String?

    /// Loaded once on appear; refreshed after the add-holding sheet dismisses.
    @State private var existingStock: Stock?

    /// Set by the portfolio picker; cleared after it is captured into `addHoldingPortfolio`.
    @State private var selectedPortfolio: Portfolio?
    @State private var showPortfolioPicker = false
    /// `sheet(item:)` captures the portfolio value at presentation time, preventing a blank
    /// sheet if the backing state is mutated during the dismiss animation.
    @State private var addHoldingPortfolio: Portfolio?
    @State private var showHoldingPicker = false

    // MARK: - Static helpers

    private static let exDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Computed display values

    private var existingHoldings: [Holding] { existingStock?.holdings ?? [] }
    private var isAlreadyAdded: Bool { !existingHoldings.isEmpty }
    private var watchlistItem: WatchlistItem? { watchlistItems.first }

    private var annualDividendPerShare: Decimal? {
        let regulars = dividends.filter { $0.dividendType == "CD" }
        guard let latest = regulars.first else { return nil }

        // Use the explicit frequency when provided.
        if let freq = latest.frequency, freq > 0 {
            return latest.cashAmount * Decimal(freq)
        }

        // Infer frequency from how many regular payments occurred in the trailing 12 months.
        let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let recentCount = regulars.filter {
            Self.exDateFormatter.date(from: $0.exDividendDate).map { $0 >= cutoff } ?? false
        }.count

        if recentCount > 0 {
            return latest.cashAmount * Decimal(recentCount)
        }

        // Last resort: show one payment's amount (annual-equivalent unknown).
        return latest.cashAmount
    }

    private var dividendYield: Decimal? {
        guard let annual = annualDividendPerShare,
              let price = currentPrice, price > 0 else { return nil }
        return (annual / price) * 100
    }

    private var nextExDate: String? {
        let today = Date()
        return dividends
            .filter { $0.dividendType == "CD" }
            .compactMap { Self.exDateFormatter.date(from: $0.exDividendDate) }
            .filter { $0 >= today }
            .sorted()
            .first
            .map { Self.exDateFormatter.string(from: $0) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = loadError {
                    ContentUnavailableView(
                        "Could Not Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    headerSection
                    criteriaGrid
                    if let desc = details?.description, !desc.isEmpty {
                        descriptionSection(desc)
                    }
                    addRemoveButton
                    watchlistButton
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(result.ticker)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        // Reload existingStock after the add-holding sheet is dismissed so the
        // button state updates without requiring a full view reload.
        .sheet(isPresented: $showPortfolioPicker, onDismiss: {
            // Capture the chosen portfolio before clearing it, then defer the second
            // sheet presentation to let iOS 17 fully settle the first dismissal.
            if let portfolio = selectedPortfolio {
                let captured = portfolio
                selectedPortfolio = nil
                Task { @MainActor in addHoldingPortfolio = captured }
            }
        }) {
            PortfolioPickerSheet(portfolios: portfolios) { portfolio in
                selectedPortfolio = portfolio
                showPortfolioPicker = false
            }
        }
        // sheet(item:) captures the portfolio value at presentation time so the content
        // closure never sees nil during the dismiss animation — eliminating the blank sheet.
        .sheet(item: $addHoldingPortfolio, onDismiss: {
            reloadExistingStock()
        }) { portfolio in
            AddHoldingView(portfolio: portfolio, initialTicker: result.ticker)
        }
        .sheet(isPresented: $showHoldingPicker) {
            HoldingPickerSheet(holdings: existingHoldings)
        }
        .navigationDestination(for: Holding.self) { holding in
            HoldingDetailView(holding: holding)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(details?.name ?? result.name)
                .font(.title2.bold())
            if let sector = details?.sicDescription, !sector.isEmpty {
                Text(sector)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var criteriaGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            CriteriaCell(
                label: "Current Price",
                value: currentPrice.map { $0.formatted(.currency(code: "USD")) } ?? "—"
            )
            CriteriaCell(
                label: "Dividend Yield",
                value: dividendYield.map {
                    "\(($0 as NSDecimalNumber).doubleValue.formatted(.number.precision(.fractionLength(2))))%"
                } ?? "—"
            )
            CriteriaCell(
                label: "Annual Div / Share",
                value: annualDividendPerShare.map { $0.formatted(.currency(code: "USD")) } ?? "—"
            )
            CriteriaCell(label: "Next Ex-Date", value: nextExDate ?? "—")
            CriteriaCell(
                label: "Market Cap",
                value: details?.marketCap.map { formatMarketCap($0) } ?? "—"
            )
            CriteriaCell(label: "Sector", value: details?.sicDescription ?? "—")
        }
    }

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About").font(.headline)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var addRemoveButton: some View {
        Group {
            if isAlreadyAdded {
                if existingHoldings.count == 1, let holding = existingHoldings.first {
                    // Single holding — navigate directly.
                    NavigationLink(value: holding) {
                        Text("View Holding")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Multiple holdings across portfolios — show picker.
                    Button {
                        showHoldingPicker = true
                    } label: {
                        Text("View \(existingHoldings.count) Holdings")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            } else {
                Button {
                    if portfolios.count == 1, let only = portfolios.first {
                        addHoldingPortfolio = only
                    } else if portfolios.isEmpty {
                        // no-op — button is disabled
                    } else {
                        showPortfolioPicker = true
                    }
                } label: {
                    Text(portfolios.isEmpty ? "Create a Portfolio First" : "Add to Portfolio")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(portfolios.isEmpty ? Color.secondary : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(portfolios.isEmpty)
            }
        }
    }

    private var watchlistButton: some View {
        Button {
            if let item = watchlistItem {
                modelContext.delete(item)
            } else {
                let name = details?.name ?? result.name
                let item = WatchlistItem(ticker: result.ticker, companyName: name)
                modelContext.insert(item)
            }
        } label: {
            Label(
                watchlistItem != nil ? "In Watchlist" : "Add to Watchlist",
                systemImage: watchlistItem != nil ? "eye.fill" : "eye"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .foregroundStyle(watchlistItem != nil ? Color.accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityHint(watchlistItem != nil ? "Removes this stock from your watchlist" : "Adds this stock to your watchlist")
        .accessibilityAddTraits(watchlistItem != nil ? .isSelected : [])
    }

    // MARK: - Data loading

    private func load() async {
        guard settings.hasAPIKey else {
            loadError = "Add an FMP API key in Settings."
            isLoading = false
            return
        }
        // Fetch details and price together — these are required for the page to render.
        do {
            async let detailsTask = polygon.service.fetchTickerDetails(ticker: result.ticker, apiKey: settings.fmpAPIKey)
            async let priceTask   = polygon.service.fetchPreviousClose(ticker: result.ticker, apiKey: settings.fmpAPIKey)
            (details, currentPrice) = try await (detailsTask, priceTask)
        } catch {
            loadError = error.localizedDescription
            isLoading = false
            return
        }
        isLoading = false
        reloadExistingStock()

        // Fetch dividends separately — failure shows "—" rather than hiding the whole page.
        // Limit 13 covers one full year for monthly payers plus one extra record.
        dividends = (try? await polygon.service.fetchDividends(
            ticker: result.ticker, limit: 13, apiKey: settings.fmpAPIKey
        )) ?? []
    }

    private func reloadExistingStock() {
        let ticker = result.ticker
        let descriptor = FetchDescriptor<Stock>(
            predicate: #Predicate<Stock> { $0.ticker == ticker }
        )
        existingStock = try? modelContext.fetch(descriptor).first
    }

    // MARK: - Helpers

    private func formatMarketCap(_ value: Decimal) -> String {
        let d = (value as NSDecimalNumber).doubleValue
        switch d {
        case 1_000_000_000_000...: return String(format: "%.1fT", d / 1_000_000_000_000)
        case 1_000_000_000...:     return String(format: "%.1fB", d / 1_000_000_000)
        case 1_000_000...:         return String(format: "%.1fM", d / 1_000_000)
        default:                   return value.formatted(.currency(code: "USD"))
        }
    }
}

// MARK: - Criteria Cell

private struct CriteriaCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Portfolio Picker Sheet

private struct PortfolioPickerSheet: View {
    let portfolios: [Portfolio]
    let onSelect: (Portfolio) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(portfolios) { portfolio in
                Button {
                    onSelect(portfolio)
                } label: {
                    HStack {
                        Text(portfolio.name)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Choose Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Holding Picker Sheet (multiple holdings of same stock)

private struct HoldingPickerSheet: View {
    let holdings: [Holding]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(holdings) { holding in
                NavigationLink(value: holding) {
                    HStack {
                        Text(holding.portfolio?.name ?? "Unknown Portfolio")
                        Spacer()
                        Text("\(holding.shares.description) shares")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: Holding.self) { holding in
                HoldingDetailView(holding: holding)
            }
            .navigationTitle("Choose Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return StockBrowserView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(settings: settings, container: container))
}
