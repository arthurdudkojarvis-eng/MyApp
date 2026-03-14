import SwiftUI
import SwiftData
import Charts
import UIKit
import OSLog

private let detailLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.divvy.Divvy",
                                  category: "StockDetailView")

// MARK: - MarketCapRange

enum MarketCapRange: String, CaseIterable, Identifiable {
    case any   = "Any"
    case mega  = "Mega"    // >= 200B
    case large = "Large"   // 10B–200B
    case mid   = "Mid"     // 2B–10B
    case small = "Small"   // 300M–2B
    case micro = "Micro"   // < 300M

    var id: String { rawValue }

    func matches(marketCap: Decimal?) -> Bool {
        guard self != .any else { return true }
        guard let mc = marketCap else { return false }
        switch self {
        case .any:   return true
        case .mega:  return mc >= 200_000_000_000
        case .large: return mc >= 10_000_000_000 && mc < 200_000_000_000
        case .mid:   return mc >= 2_000_000_000 && mc < 10_000_000_000
        case .small: return mc >= 300_000_000 && mc < 2_000_000_000
        case .micro: return mc < 300_000_000
        }
    }
}

// MARK: - Sector Chips

private let sectorChips: [String] = [
    "Technology", "Healthcare", "Finance", "Energy",
    "Consumer Cyclical", "Industrials", "Real Estate",
    "Utilities", "Communication", "Materials"
]

// MARK: - StockBrowserView

struct StockBrowserView: View {
    @Environment(\.massiveService) private var massive
    @Environment(\.finnhubService) private var finnhub

    @State private var query = ""
    @State private var results: [MassiveTickerSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var showTips = false
    @State private var showScreener = false
    @State private var stocksPage = 0
    @State private var screenerViewModel: SignalScreenerViewModel?

    // STORY-043: Filter state
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
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            TabView(selection: $stocksPage) {
                searchPage.tag(0)
                screenerPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
    }

    // MARK: - Search Page

    private var searchPage: some View {
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
            .searchable(text: $query, prompt: "Ticker or company name")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Button {
                            showTips = true
                        } label: {
                            Image(systemName: "lightbulb")
                        }
                        .accessibilityLabel("Stock tips")

                        Button {
                            showScreener = true
                        } label: {
                            Image(systemName: "sparkle.magnifyingglass")
                        }
                        .accessibilityLabel("Stock screener")
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
                StockTipsView()
            }
            .sheet(isPresented: $showScreener) {
                StockScreenerView()
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

    // MARK: - Screener Page

    private var screenerPage: some View {
        NavigationStack {
            SignalScreenerContentView(viewModel: ensureScreenerViewModel())
        }
    }

    private func ensureScreenerViewModel() -> SignalScreenerViewModel {
        if let vm = screenerViewModel { return vm }
        let vm = SignalScreenerViewModel()
        screenerViewModel = vm
        return vm
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
                    StockSearchRowView(result: result)
                }
            }

            if isEnriching {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading details…")
                        .textStyle(.rowDetail)
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
                Text("Sector").textStyle(.captionBold).foregroundStyle(.secondary)
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
                Text("Market Cap").textStyle(.captionBold).foregroundStyle(.secondary)
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
                    .textStyle(.captionBold)
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
            let upper = query.uppercased()
            results = fetched.sorted { a, b in
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
                // Skip tickers we already have details for (unless yield is now needed)
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
                        // Compute yield: latest dividend * frequency / price
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

// MARK: - Shared Helpers

func formatMarketCap(_ value: Decimal) -> String {
    let d = (value as NSDecimalNumber).doubleValue
    switch d {
    case 1_000_000_000_000...: return String(format: "%.1fT", d / 1_000_000_000_000)
    case 1_000_000_000...:     return String(format: "%.1fB", d / 1_000_000_000)
    case 1_000_000...:         return String(format: "%.1fM", d / 1_000_000)
    default:                   return value.formatted(.currency(code: "USD"))
    }
}

// MARK: - Search Row

private struct StockSearchRowView: View {
    let result: MassiveTickerSearchResult

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(result.ticker)
                        .textStyle(.tickerSymbol)
                    // STORY-026: Security-type badge (CS / ETF / PFD / etc.)
                    if let type = result.type, !type.isEmpty {
                        Text(type)
                            .textStyle(.badge)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                Text(result.name)
                    .textStyle(.rowDetail)
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
        // STORY-026: Include type in accessibility label when present
        .accessibilityLabel([result.ticker, result.name, result.type].compactMap { $0 }.joined(separator: ", "))
    }
}

// MARK: - Chart Range

enum ChartRange: String, CaseIterable, Identifiable {
    case oneDay = "1D"
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case ytd = "YTD"
    case oneYear = "1Y"
    case threeYears = "3Y"
    case fiveYears = "5Y"

    var id: String { rawValue }

    var label: String { rawValue }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    var dateRange: (from: String, to: String) {
        let today = Date()
        let from: Date
        switch self {
        case .oneDay:      from = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        case .oneWeek:     from = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        case .oneMonth:    from = Calendar.current.date(byAdding: .month, value: -1, to: today) ?? today
        case .threeMonths: from = Calendar.current.date(byAdding: .month, value: -3, to: today) ?? today
        case .sixMonths:   from = Calendar.current.date(byAdding: .month, value: -6, to: today) ?? today
        case .ytd:         from = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: today), month: 1, day: 1)) ?? today
        case .oneYear:     from = Calendar.current.date(byAdding: .year, value: -1, to: today) ?? today
        case .threeYears:  from = Calendar.current.date(byAdding: .year, value: -3, to: today) ?? today
        case .fiveYears:   from = Calendar.current.date(byAdding: .year, value: -5, to: today) ?? today
        }
        return (Self.dateFormatter.string(from: from), Self.dateFormatter.string(from: today))
    }
}

// MARK: - Indicator Data

struct IndicatorData {
    var sma: Decimal?
    var ema: Decimal?
    var rsi: Decimal?
    var macdValue: Decimal?
    var macdSignal: Decimal?
    var macdHistogram: Decimal?

    static let empty = IndicatorData()

    var rsiLabel: String? {
        guard let rsi else { return nil }
        let val = (rsi as NSDecimalNumber).doubleValue
        if val >= 70 { return "Overbought" }
        if val <= 30 { return "Oversold" }
        return "Neutral"
    }

    var macdTrend: String? {
        guard let h = macdHistogram else { return nil }
        return h > 0 ? "Bullish" : h < 0 ? "Bearish" : "Neutral"
    }
}

// MARK: - Stock Detail

struct StockDetailView: View {
    let result: MassiveTickerSearchResult

    @Environment(\.modelContext) private var modelContext
    @Environment(StockRefreshService.self) private var stockRefresh
    @Environment(\.massiveService) private var massive
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    // Filtered to only the current ticker so SwiftData doesn't load the entire watchlist.
    @Query private var watchlistItems: [WatchlistItem]

    init(result: MassiveTickerSearchResult) {
        self.result = result
        let ticker = result.ticker
        _watchlistItems = Query(filter: #Predicate<WatchlistItem> { $0.ticker == ticker })
    }

    @State private var details: MassiveTickerDetails?
    @State private var currentPrice: Decimal?
    @State private var dividends: [MassiveDividend] = []
    @State private var financials: [MassiveFinancial] = []
    @State private var priceHistory: [MassiveAggregate] = []
    @State private var selectedChartRange: ChartRange = .threeMonths
    @State private var relatedTickers: [String] = []
    @State private var splits: [MassiveSplit] = []
    @State private var indicators: IndicatorData = .empty
    @State private var priceTarget: FinnhubPriceTarget?
    @Environment(\.finnhubService) private var finnhub
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showDescription = false

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
    private var latestFinancial: MassiveFinancial? { financials.first }

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

    // STORY-027: Real payout ratio from financials endpoint.
    // Formula: (annualDividendPerShare / dilutedEarningsPerShare) * 100
    // Returns nil when either input is missing or EPS is non-positive (avoids divide-by-zero
    // and nonsensical ratios for loss-making companies).
    private var payoutRatio: Decimal? {
        guard let annual = annualDividendPerShare,
              let eps = latestFinancial?.dilutedEarningsPerShare,
              eps > 0 else { return nil }
        return (annual / eps) * 100
    }

    // MARK: - Risk Analysis (STORY-061)

    private var revenueGrowthYoY: Decimal? {
        guard financials.count >= 2,
              let current = financials[0].revenues,
              let previous = financials[1].revenues,
              previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    private var debtToEquity: Decimal? {
        guard let liabilities = latestFinancial?.liabilities,
              let equity = latestFinancial?.equity,
              equity > 0 else { return nil }
        return liabilities / equity
    }

    private var dividendGrowthStreak: Int? {
        let regulars = dividends.filter { $0.dividendType == "CD" }
        guard !regulars.isEmpty else { return nil }

        // Group by year, take the last payment per year as the representative amount.
        var amountByYear: [Int: Decimal] = [:]
        let calendar = Calendar.current
        for div in regulars {
            guard let date = Self.exDateFormatter.date(from: div.exDividendDate) else { continue }
            let year = calendar.component(.year, from: date)
            // Dividends are sorted desc; first seen per year is the most recent payment.
            if amountByYear[year] == nil {
                amountByYear[year] = div.cashAmount
            }
        }

        let sortedYears = amountByYear.keys.sorted(by: >)
        guard sortedYears.count >= 2 else { return 0 }

        var streak = 0
        for i in 0..<(sortedYears.count - 1) {
            let currentYear = sortedYears[i]
            let previousYear = sortedYears[i + 1]
            guard currentYear - previousYear == 1 else { break }
            guard let currentAmount = amountByYear[currentYear],
                  let previousAmount = amountByYear[previousYear],
                  currentAmount > previousAmount else { break }
            streak += 1
        }
        return streak
    }

    private var riskInputs: RiskInputs {
        RiskInputs(
            payoutRatio: payoutRatio,
            dividendYield: dividendYield,
            revenueGrowthYoY: revenueGrowthYoY,
            debtToEquity: debtToEquity,
            eps: latestFinancial?.dilutedEarningsPerShare,
            dividendGrowthStreak: dividendGrowthStreak
        )
    }

    private var riskFactors: [RiskFactor] {
        RiskRuleEngine.evaluate(riskInputs)
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
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
            } else if let error = loadError {
                ContentUnavailableView {
                    Label("Could Not Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        loadError = nil
                        isLoading = true
                        Task { await load() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                // Hero banner sits outside padding for full-width bleed
                heroBanner

                VStack(spacing: 20) {
                    priceChartSection
                    criteriaGrid
                    indicatorsSection
                    analystTargetSection
                    RiskFactorsCard(factors: riskFactors)
                    ResearchReportCard(
                        ticker: result.ticker,
                        companyName: details?.name ?? result.name,
                        marketCap: details?.marketCap,
                        revenue: latestFinancial?.revenues,
                        eps: latestFinancial?.dilutedEarningsPerShare,
                        currentPrice: currentPrice,
                        dividendYield: dividendYield,
                        payoutRatio: payoutRatio,
                        priceTarget: priceTarget,
                        riskFactors: riskFactors
                    )
                    if !relatedTickers.isEmpty {
                        relatedCompaniesSection
                    }
                    if !splits.isEmpty {
                        splitHistorySection
                    }
                    addRemoveButton
                    watchlistButton
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(result.ticker)
        .navigationBarTitleDisplayMode(.inline)
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

    private var heroBanner: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 8) {
                CompanyLogoView(
                    branding: details?.branding,
                    ticker: result.ticker,
                    service: massive.service,
                    size: 72
                )

                if let sector = details?.sicDescription, !sector.isEmpty {
                    Text(sector)
                        .textStyle(.rowDetail)
                }

                HStack(spacing: 6) {
                    Text(details?.name ?? result.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    if let desc = details?.description, !desc.isEmpty {
                        Button {
                            showDescription.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .popover(isPresented: $showDescription) {
                            ScrollView {
                                Text(desc)
                                    .font(.subheadline)
                                    .padding()
                            }
                            .frame(idealWidth: 320, idealHeight: 300)
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
    }

    private var criteriaGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            CriteriaCell(
                label: "Price (15-min delay)",
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
            // STORY-027: Real financials cells
            CriteriaCell(
                label: "Payout Ratio",
                value: payoutRatio.map {
                    "\(($0 as NSDecimalNumber).doubleValue.formatted(.number.precision(.fractionLength(1))))%"
                } ?? "—"
            )
            CriteriaCell(
                label: "EPS (diluted)",
                value: latestFinancial?.dilutedEarningsPerShare.map {
                    $0.formatted(.currency(code: "USD").precision(.fractionLength(2)))
                } ?? "—"
            )
            CriteriaCell(
                label: "Revenue (TTM)",
                value: latestFinancial?.revenues.map { formatMarketCap($0) } ?? "—"
            )
        }
    }

    // MARK: - Price Chart (STORY-028)

    private var priceChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price History").textStyle(.sectionTitle)

            Picker("Range", selection: $selectedChartRange) {
                ForEach(ChartRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedChartRange) { _, _ in
                Task { await loadPriceChart() }
            }

            if priceHistory.isEmpty {
                Text("No price data available")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(priceHistory, id: \.t) { bar in
                    LineMark(
                        x: .value("Date", Date(timeIntervalSince1970: TimeInterval(bar.t) / 1000)),
                        y: .value("Price", (bar.c as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(Color.accentColor)

                    AreaMark(
                        x: .value("Date", Date(timeIntervalSince1970: TimeInterval(bar.t) / 1000)),
                        y: .value("Price", (bar.c as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Technical Indicators (STORY-029)

    private var indicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Indicators").textStyle(.sectionTitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                indicatorCell(
                    label: "SMA (20)",
                    value: indicators.sma.map { $0.formatted(.currency(code: "USD")) }
                )
                indicatorCell(
                    label: "EMA (20)",
                    value: indicators.ema.map { $0.formatted(.currency(code: "USD")) }
                )
                indicatorCell(
                    label: "RSI (14)",
                    value: indicators.rsi.map {
                        "\(($0 as NSDecimalNumber).doubleValue.formatted(.number.precision(.fractionLength(1))))"
                    },
                    subtitle: indicators.rsiLabel
                )
                indicatorCell(
                    label: "MACD",
                    value: indicators.macdValue.map {
                        ($0 as NSDecimalNumber).doubleValue.formatted(.number.precision(.fractionLength(2)))
                    },
                    subtitle: indicators.macdTrend
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func indicatorCell(label: String, value: String?, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .textStyle(.rowDetail)
            Text(value ?? "—")
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(subtitle == "Overbought" || subtitle == "Bearish" ? .red :
                                    subtitle == "Oversold" || subtitle == "Bullish" ? .green : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Analyst Targets (STORY-059)

    @ViewBuilder
    private var analystTargetSection: some View {
        if let target = priceTarget, let price = currentPrice, target.targetMean > 0 {
            AnalystTargetCard(target: target, currentPrice: price)
        }
    }

    // MARK: - Related Companies (STORY-030)

    private var relatedCompaniesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Stocks").textStyle(.sectionTitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(relatedTickers.prefix(10), id: \.self) { ticker in
                        NavigationLink {
                            StockDetailView(result: MassiveTickerSearchResult(
                                ticker: ticker, name: ticker, market: "stocks",
                                type: nil, primaryExchange: nil
                            ))
                        } label: {
                            Text(ticker)
                                .textStyle(.captionBold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Split History (STORY-031)

    private var splitHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stock Splits").textStyle(.sectionTitle)

            ForEach(splits.prefix(5), id: \.executionDate) { split in
                HStack {
                    Text(split.executionDate)
                        .font(.subheadline)
                    Spacer()
                    Text("\(formatSplitRatio(split.splitFrom)):\(formatSplitRatio(split.splitTo))")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatSplitRatio(_ value: Decimal) -> String {
        let d = (value as NSDecimalNumber).doubleValue
        if d == d.rounded() {
            return "\(Int(d))"
        }
        return d.formatted(.number.precision(.fractionLength(0...2)))
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
        let api = massive.service
        let ticker = result.ticker

        // Ticker details are required for the page to render.
        // Price is fetched concurrently but allowed to fail gracefully
        // (the snapshot endpoint is rate-limited more aggressively).
        do {
            async let detailsTask = api.fetchTickerDetails(ticker: ticker)
            async let priceTask: Decimal? = try? api.fetchPreviousClose(ticker: ticker)
            (details, currentPrice) = try await (detailsTask, priceTask)
        } catch {
            loadError = error.localizedDescription
            isLoading = false
            return
        }
        isLoading = false
        reloadExistingStock()

        // Secondary fetches — all run concurrently, each fails gracefully.
        async let dividendsTask: [MassiveDividend] = {
            do { return try await api.fetchDividends(ticker: ticker, limit: 13) }
            catch { detailLogger.warning("Dividend fetch failed: \(error.localizedDescription)"); return [] }
        }()
        async let financialsTask: [MassiveFinancial] = {
            do { return try await api.fetchFinancials(ticker: ticker, limit: 2) }
            catch { detailLogger.warning("Financials fetch failed: \(error.localizedDescription)"); return [] }
        }()
        async let splitsTask: [MassiveSplit] = {
            do { return try await api.fetchSplits(ticker: ticker) }
            catch { detailLogger.warning("Splits fetch failed: \(error.localizedDescription)"); return [] }
        }()
        async let relatedTask: [String] = {
            do { return try await api.fetchRelatedCompanies(ticker: ticker) }
            catch { detailLogger.warning("Related companies fetch failed: \(error.localizedDescription)"); return [] }
        }()
        async let indicatorsTask: IndicatorData = {
            await loadIndicators(api: api, ticker: ticker)
        }()
        async let priceTargetTask: FinnhubPriceTarget? = {
            await loadPriceTarget(ticker: ticker)
        }()

        (dividends, financials, splits, relatedTickers, indicators, priceTarget) =
            await (dividendsTask, financialsTask, splitsTask, relatedTask, indicatorsTask, priceTargetTask)

        // Load initial price chart
        await loadPriceChart()
    }

    private func loadPriceChart() async {
        let range = selectedChartRange.dateRange
        do {
            priceHistory = try await massive.service.fetchAggregates(
                ticker: result.ticker, from: range.from, to: range.to
            )
        } catch {
            detailLogger.warning("Price chart fetch failed: \(error.localizedDescription)")
            priceHistory = []
        }
    }

    private func loadIndicators(api: any MassiveFetching, ticker: String) async -> IndicatorData {
        async let smaTask: Decimal? = {
            (try? await api.fetchTechnicalIndicator(type: .sma, ticker: ticker))?.first?.value
        }()
        async let emaTask: Decimal? = {
            (try? await api.fetchTechnicalIndicator(type: .ema, ticker: ticker))?.first?.value
        }()
        async let rsiTask: Decimal? = {
            (try? await api.fetchTechnicalIndicator(type: .rsi, ticker: ticker))?.first?.value
        }()
        async let macdTask: MassiveIndicatorValue? = {
            (try? await api.fetchTechnicalIndicator(type: .macd, ticker: ticker))?.first
        }()

        let (sma, ema, rsi, macd) = await (smaTask, emaTask, rsiTask, macdTask)
        return IndicatorData(
            sma: sma, ema: ema, rsi: rsi,
            macdValue: macd?.value, macdSignal: macd?.signal, macdHistogram: macd?.histogram
        )
    }

    private func reloadExistingStock() {
        let ticker = result.ticker
        let descriptor = FetchDescriptor<Stock>(
            predicate: #Predicate<Stock> { $0.ticker == ticker }
        )
        existingStock = try? modelContext.fetch(descriptor).first
    }

    // MARK: - Price Target Cache (STORY-059)

    private static let lastUpdatedParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func loadPriceTarget(ticker: String) async -> FinnhubPriceTarget? {
        // Check SwiftData cache first (normalise to uppercase to match stored keys)
        let t = ticker.uppercased()
        let descriptor = FetchDescriptor<PriceTargetCache>(
            predicate: #Predicate<PriceTargetCache> { $0.ticker == t }
        )
        if let cached = try? modelContext.fetch(descriptor).first, !cached.isExpired {
            return FinnhubPriceTarget(
                targetHigh: cached.targetHigh,
                targetLow: cached.targetLow,
                targetMean: cached.targetMean,
                targetMedian: cached.targetMedian,
                lastUpdated: Self.lastUpdatedParser.string(from: cached.lastUpdated)
            )
        }
        do {
            let target = try await finnhub.service.fetchPriceTarget(ticker: ticker)
            savePriceTargetCache(ticker: ticker, target: target)
            return target
        } catch {
            detailLogger.warning("Price target fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func savePriceTargetCache(ticker: String, target: FinnhubPriceTarget) {
        let lastUpdated = Self.lastUpdatedParser.date(from: target.lastUpdated) ?? .now
        let t = ticker.uppercased()
        let descriptor = FetchDescriptor<PriceTargetCache>(
            predicate: #Predicate<PriceTargetCache> { $0.ticker == t }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.targetHigh = target.targetHigh
            existing.targetLow = target.targetLow
            existing.targetMean = target.targetMean
            existing.targetMedian = target.targetMedian
            existing.lastUpdated = lastUpdated
            existing.fetchedAt = .now
        } else {
            let cache = PriceTargetCache(
                ticker: ticker,
                targetHigh: target.targetHigh,
                targetLow: target.targetLow,
                targetMean: target.targetMean,
                targetMedian: target.targetMedian,
                lastUpdated: lastUpdated
            )
            modelContext.insert(cache)
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
                .textStyle(.rowDetail)
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
                            .textStyle(.rowDetail)
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
        .environment(StockRefreshService(container: container))
}
