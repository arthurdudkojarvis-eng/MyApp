import SwiftUI
import SwiftData

struct AdvisorView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.massiveService) private var massive
    @Environment(SettingsStore.self) private var settings

    @State private var query = ""
    @State private var results: [MassiveTickerSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedResult: MassiveTickerSearchResult?

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Search bar
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
                        subtitle: "Holdings down >10% from your cost basis",
                        icon: "arrow.down.right.circle.fill",
                        iconColor: .red
                    ) {
                        ForEach(undervaluedPicks.prefix(5)) { holding in
                            if let stock = holding.stock {
                                advisorRow(
                                    ticker: stock.ticker,
                                    name: stock.companyName,
                                    detail: percentLabel(holding.unrealizedGainPercent),
                                    detailColor: .red,
                                    badge: holding.yieldOnCost > 0
                                        ? String(format: "%.1f%% YoC", (holding.yieldOnCost as NSDecimalNumber).doubleValue)
                                        : nil,
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
                        subtitle: "Your highest yield-on-cost holdings",
                        icon: "flame.fill",
                        iconColor: .orange
                    ) {
                        ForEach(highYieldPicks) { holding in
                            if let stock = holding.stock {
                                advisorRow(
                                    ticker: stock.ticker,
                                    name: stock.companyName,
                                    detail: String(format: "%.2f%% YoC", (holding.yieldOnCost as NSDecimalNumber).doubleValue),
                                    detailColor: .orange,
                                    badge: holding.projectedMonthlyIncome > 0
                                        ? holding.projectedMonthlyIncome.formatted(.currency(code: holding.currency)) + "/mo"
                                        : nil,
                                    stock: stock
                                )
                            }
                        }
                    }
                }

                // Portfolio gaps
                portfolioGapsSection
            }
        }
    }

    // MARK: - Portfolio Gaps

    private var portfolioGapsSection: some View {
        let sectors = Set(allHoldings.compactMap { $0.stock?.sector }.filter { !$0.isEmpty })
        let missingSectors = ["Utilities", "Healthcare", "Consumer Defensive", "Real Estate", "Energy", "Financial Services"]
            .filter { !sectors.contains($0) }

        return Group {
            if !missingSectors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "puzzle.piece.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Missing Sectors")
                                .textStyle(.rowTitle)
                            Text("Consider diversifying into these sectors")
                                .textStyle(.rowDetail)
                        }
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(missingSectors, id: \.self) { sector in
                            Text(sector)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.12))
                                )
                        }
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
        }
    }

    // MARK: - Helpers

    private func advisorSection<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    private func advisorRow(
        ticker: String,
        name: String,
        detail: String,
        detailColor: Color,
        badge: String?,
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
                CompanyLogoView(
                    branding: nil,
                    ticker: ticker,
                    service: massive.service,
                    size: 32
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(ticker)
                        .textStyle(.tickerSymbol)
                    if !name.isEmpty {
                        Text(name)
                            .textStyle(.rowDetail)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(detail)
                        .textStyle(.statValue)
                        .monospacedDigit()
                        .foregroundStyle(detailColor)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

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
