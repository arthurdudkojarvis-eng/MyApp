import SwiftUI
import SwiftData

// MARK: - Sector Opportunity Data

private struct SectorOpportunity: Identifiable {
    let sector: String
    let tickers: [MassiveTickerSearchResult]
    var id: String { sector }
}

private let sectorSuggestions: [String: [MassiveTickerSearchResult]] = [
    "Utilities": [
        MassiveTickerSearchResult(ticker: "NEE", name: "NextEra Energy", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "DUK", name: "Duke Energy", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "SO", name: "Southern Company", market: "stocks", type: "CS", primaryExchange: "XNYS"),
    ],
    "Healthcare": [
        MassiveTickerSearchResult(ticker: "ABBV", name: "AbbVie Inc.", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "PFE", name: "Pfizer Inc.", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "MRK", name: "Merck & Co.", market: "stocks", type: "CS", primaryExchange: "XNYS"),
    ],
    "Consumer Defensive": [
        MassiveTickerSearchResult(ticker: "KO", name: "Coca-Cola Company", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "PG", name: "Procter & Gamble", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "CL", name: "Colgate-Palmolive", market: "stocks", type: "CS", primaryExchange: "XNYS"),
    ],
    "Real Estate": [
        MassiveTickerSearchResult(ticker: "O", name: "Realty Income Corp.", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "AMT", name: "American Tower", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "SPG", name: "Simon Property Group", market: "stocks", type: "CS", primaryExchange: "XNYS"),
    ],
    "Energy": [
        MassiveTickerSearchResult(ticker: "XOM", name: "Exxon Mobil", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "CVX", name: "Chevron Corp.", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "EPD", name: "Enterprise Products", market: "stocks", type: "CS", primaryExchange: "XNYS"),
    ],
    "Financial Services": [
        MassiveTickerSearchResult(ticker: "JPM", name: "JPMorgan Chase", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "BLK", name: "BlackRock Inc.", market: "stocks", type: "CS", primaryExchange: "XNYS"),
        MassiveTickerSearchResult(ticker: "TROW", name: "T. Rowe Price", market: "stocks", type: "CS", primaryExchange: "XNAS"),
    ],
]

// MARK: - AdvisorView

struct AdvisorView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.massiveService) private var massive
    @Environment(SettingsStore.self) private var settings

    @State private var query = ""
    @State private var results: [MassiveTickerSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var expandedSector: String?

    private var allHoldings: [Holding] { portfolios.flatMap(\.holdings) }

    private var ownedTickers: Set<String> {
        Set(allHoldings.compactMap { $0.stock?.ticker })
    }

    // MARK: - Quick Picks

    private var undervaluedPicks: [Holding] {
        allHoldings
            .filter { holding in
                guard let pct = holding.unrealizedGainPercent else { return false }
                return pct < -10
            }
            .sorted { ($0.unrealizedGainPercent ?? 0) < ($1.unrealizedGainPercent ?? 0) }
    }

    private var highYieldPicks: [Holding] {
        allHoldings
            .filter { $0.yieldOnCost > 0 }
            .sorted { $0.yieldOnCost > $1.yieldOnCost }
            .prefix(5)
            .map { $0 }
    }

    private var missingSectors: [String] {
        let sectors = Set(allHoldings.compactMap { $0.stock?.sector }.filter { !$0.isEmpty })
        return ["Utilities", "Healthcare", "Consumer Defensive", "Real Estate", "Energy", "Financial Services"]
            .filter { !sectors.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchBar

                    if !query.isEmpty {
                        searchResults
                    } else {
                        advisorContent
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Advisor")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search stocks to evaluate...", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .onChange(of: query) { _, newValue in
                    searchTask?.cancel()
                    guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                        results = []
                        isSearching = false
                        return
                    }
                    isSearching = true
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        do {
                            let fetched = try await massive.service.fetchTickerSearch(query: newValue)
                            if !Task.isCancelled {
                                results = fetched
                            }
                        } catch {
                            if !Task.isCancelled { results = [] }
                        }
                        if !Task.isCancelled { isSearching = false }
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Search Results

    private var searchResults: some View {
        VStack(spacing: 8) {
            if isSearching {
                ProgressView()
                    .padding(.top, 40)
            } else if results.isEmpty {
                Text("No results found")
                    .textStyle(.rowDetail)
                    .padding(.top, 40)
            } else {
                ForEach(results, id: \.ticker) { result in
                    let owned = ownedTickers.contains(result.ticker)
                    NavigationLink {
                        StockDetailView(result: result)
                    } label: {
                        HStack(spacing: 12) {
                            CompanyLogoView(
                                branding: nil,
                                ticker: result.ticker,
                                service: massive.service,
                                size: 36
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(result.ticker)
                                        .textStyle(.tickerSymbol)
                                    if owned {
                                        Text("OWNED")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(Color.green.opacity(0.12))
                                            )
                                    }
                                }
                                if !result.name.isEmpty {
                                    Text(result.name)
                                        .textStyle(.rowDetail)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Advisor Content

    private var advisorContent: some View {
        VStack(spacing: 16) {
            if allHoldings.isEmpty {
                ContentUnavailableView(
                    "No Holdings to Analyze",
                    systemImage: "lightbulb",
                    description: Text("Add holdings to your portfolios and the advisor will suggest purchase opportunities.")
                )
                .padding(.top, 40)
            } else {
                // Undervalued opportunities
                if !undervaluedPicks.isEmpty {
                    advisorSection(
                        title: "Buy the Dip",
                        subtitle: "Holdings down >10% — consider adding more",
                        icon: "arrow.down.right.circle.fill",
                        iconColor: .red,
                        accentGradient: [.red.opacity(0.15), .clear]
                    ) {
                        ForEach(undervaluedPicks.prefix(5)) { holding in
                            if let stock = holding.stock {
                                actionRow(
                                    ticker: stock.ticker,
                                    name: stock.companyName,
                                    metric: percentLabel(holding.unrealizedGainPercent),
                                    metricColor: .red,
                                    badge: holding.yieldOnCost > 0
                                        ? String(format: "%.1f%% YoC", (holding.yieldOnCost as NSDecimalNumber).doubleValue)
                                        : nil,
                                    action: "Add More",
                                    actionIcon: "plus.circle.fill",
                                    actionColor: .red,
                                    stock: stock
                                )
                            }
                        }
                    }
                }

                // Highest yielding — double down
                if !highYieldPicks.isEmpty {
                    advisorSection(
                        title: "Top Yielders",
                        subtitle: "Your best income producers — double down",
                        icon: "flame.fill",
                        iconColor: .orange,
                        accentGradient: [.orange.opacity(0.15), .clear]
                    ) {
                        ForEach(highYieldPicks) { holding in
                            if let stock = holding.stock {
                                actionRow(
                                    ticker: stock.ticker,
                                    name: stock.companyName,
                                    metric: String(format: "%.2f%% YoC", (holding.yieldOnCost as NSDecimalNumber).doubleValue),
                                    metricColor: .orange,
                                    badge: holding.projectedMonthlyIncome > 0
                                        ? holding.projectedMonthlyIncome.formatted(.currency(code: holding.currency)) + "/mo"
                                        : nil,
                                    action: "Review",
                                    actionIcon: "chart.line.uptrend.xyaxis",
                                    actionColor: .orange,
                                    stock: stock
                                )
                            }
                        }
                    }
                }

                // Missing sectors — tappable chips
                if !missingSectors.isEmpty {
                    portfolioGapsSection
                }

                // Discovery — dividend opportunities in missing sectors
                if !missingSectors.isEmpty {
                    dividendOpportunitiesSection
                }
            }
        }
    }

    // MARK: - Portfolio Gaps (Tappable Chips)

    private var portfolioGapsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "puzzle.piece.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Missing Sectors")
                        .textStyle(.rowTitle)
                    Text("Tap a sector to explore dividend stocks")
                        .textStyle(.rowDetail)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(missingSectors, id: \.self) { sector in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            expandedSector = expandedSector == sector ? nil : sector
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sector)
                                .font(.caption.weight(.medium))
                            Image(systemName: expandedSector == sector ? "chevron.up" : "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(expandedSector == sector ? .white : .blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(expandedSector == sector ? Color.blue : Color.blue.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Inline expansion showing stocks for selected sector
            if let sector = expandedSector, let suggestions = sectorSuggestions[sector] {
                VStack(spacing: 6) {
                    ForEach(suggestions) { result in
                        NavigationLink {
                            StockDetailView(result: result)
                        } label: {
                            sectorSuggestionRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Dividend Opportunities Discovery

    private var dividendOpportunitiesSection: some View {
        let opportunities = missingSectors.prefix(3).compactMap { sector -> SectorOpportunity? in
            guard let tickers = sectorSuggestions[sector] else { return nil }
            // Filter out stocks user already owns
            let filtered = tickers.filter { !ownedTickers.contains($0.ticker) }
            guard !filtered.isEmpty else { return nil }
            return SectorOpportunity(sector: sector, tickers: Array(filtered.prefix(2)))
        }

        return Group {
            if !opportunities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dividend Opportunities")
                                .textStyle(.rowTitle)
                            Text("Top picks for your missing sectors")
                                .textStyle(.rowDetail)
                        }
                    }

                    ForEach(opportunities) { opp in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(opp.sector.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.purple.opacity(0.12))
                                )

                            ForEach(opp.tickers) { result in
                                NavigationLink {
                                    StockDetailView(result: result)
                                } label: {
                                    discoveryRow(result: result)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.regularMaterial)
                        LinearGradient(
                            colors: [.purple.opacity(0.08), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            }
        }
    }

    // MARK: - Unique Advisor Rows

    private func actionRow(
        ticker: String,
        name: String,
        metric: String,
        metricColor: Color,
        badge: String?,
        action: String,
        actionIcon: String,
        actionColor: Color,
        stock: Stock
    ) -> some View {
        NavigationLink {
            StockDetailView(result: MassiveTickerSearchResult(
                ticker: stock.ticker,
                name: stock.companyName,
                market: nil,
                type: nil,
                primaryExchange: nil
            ))
        } label: {
            HStack(spacing: 10) {
                // Colored accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(metricColor)
                    .frame(width: 3, height: 40)

                CompanyLogoView(
                    branding: nil,
                    ticker: ticker,
                    service: massive.service,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(ticker)
                        .font(.subheadline.bold())
                    if !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(metric)
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(metricColor)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                // Action pill
                HStack(spacing: 3) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 10))
                    Text(action)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(actionColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .strokeBorder(actionColor.opacity(0.4), lineWidth: 1)
                )
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func sectorSuggestionRow(result: MassiveTickerSearchResult) -> some View {
        HStack(spacing: 10) {
            CompanyLogoView(
                branding: nil,
                ticker: result.ticker,
                service: massive.service,
                size: 28
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(result.ticker)
                    .font(.caption.bold())
                Text(result.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("Explore")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .strokeBorder(Color.blue.opacity(0.4), lineWidth: 1)
                )
        }
        .padding(.vertical, 2)
    }

    private func discoveryRow(result: MassiveTickerSearchResult) -> some View {
        HStack(spacing: 10) {
            CompanyLogoView(
                branding: nil,
                ticker: result.ticker,
                service: massive.service,
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(result.ticker)
                    .font(.subheadline.bold())
                Text(result.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 10))
                Text("Research")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .strokeBorder(Color.purple.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(.vertical, 4)
    }

    // MARK: - Section Container

    private func advisorSection<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        accentGradient: [Color] = [.clear, .clear],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(.rowTitle)
                    Text(subtitle)
                        .textStyle(.rowDetail)
                }
            }

            content()
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                LinearGradient(
                    colors: accentGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Helpers

    private func percentLabel(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        let prefix = value >= 0 ? "+" : ""
        let formatted = (value as NSDecimalNumber)
            .doubleValue
            .formatted(.number.precision(.fractionLength(2)))
        return "\(prefix)\(formatted)%"
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return AdvisorView()
        .modelContainer(container)
        .environment(settings)
        .environment(StockRefreshService(container: container))
}
