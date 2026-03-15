import SwiftUI
import SwiftData

// MARK: - Score Filter

private enum ScoreFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case strongBuy = "Strong Buy"
    case buy = "Buy"
    case hold = "Hold"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease"
        case .strongBuy: return "star.fill"
        case .buy: return "hand.thumbsup.fill"
        case .hold: return "pause.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .secondary
        case .strongBuy: return .green
        case .buy: return .orange
        case .hold: return .red
        }
    }

    func matches(_ score: Int?) -> Bool {
        guard let score else { return self == .all }
        switch self {
        case .all: return true
        case .strongBuy: return score >= 70
        case .buy: return score >= 40 && score < 70
        case .hold: return score < 40
        }
    }
}

// MARK: - Signal Screener Content View

struct SignalScreenerContentView: View {
    @Bindable var viewModel: SignalScreenerViewModel

    @Environment(\.massiveService) private var massive
    @Environment(\.finnhubService) private var finnhub
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Query private var watchlistItems: [WatchlistItem]
    @State private var showScoreInfo = false
    @State private var appeared = false
    @State private var selectedFilter: ScoreFilter = .all

    var body: some View {
        Group {
            if viewModel.isInitialLoading && viewModel.rows.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.rows.isEmpty {
                richEmptyState
            } else {
                screenerList
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadIfNeeded(
                portfolios: portfolios,
                watchlistItems: watchlistItems,
                massive: massive,
                finnhub: finnhub,
                modelContext: modelContext
            )
        }
        .onAppear {
            guard !appeared else { return }
            Task { @MainActor in
                appeared = true
            }
        }
    }

    // MARK: - Rich Empty State

    private var richEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            Text("No Stocks to Score")
                .textStyle(.cardTitle)

            Text("Add stocks to your Watchlist or Portfolio to see signal scores here.")
                .textStyle(.rowDetail)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.blue.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .padding(.horizontal)
        .padding(.top, 40)
    }

    // MARK: - Screener List

    private var screenerList: some View {
        let allRows = viewModel.displayedRows
        let filteredRows = selectedFilter == .all
            ? allRows
            : allRows.filter { selectedFilter.matches($0.signalScore) }

        return ScrollView {
            VStack(spacing: 0) {
                columnHeaders
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appeared)

                // Stats summary
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(
                        icon: "gauge.with.dots.needle.33percent",
                        title: "Portfolio Signal Overview",
                        description: "Weighted score from yield (20%), payout safety (25%), dividend growth (20%), analyst consensus (20%), and volatility (15%). Requires at least 3 of 5 data points."
                    )
                    screenerSummaryView(rows: allRows)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05), value: appeared)

                // Score distribution bar
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(
                        icon: "chart.bar.fill",
                        title: "Score Distribution",
                        description: "Strong Buy (70-100): high yield, safe payout, strong growth. Buy (40-69): moderate fundamentals. Hold (<40): weak signals or incomplete data."
                    )
                    scoreDistributionBar(rows: allRows)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.08), value: appeared)

                // Filter chips
                filterChips
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.1), value: appeared)

                // Stock rows in glass card
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(
                        icon: "list.bullet.rectangle",
                        title: "Scored Stocks",
                        description: "Your portfolio and watchlist stocks ranked by signal score. Tap any stock for detailed analysis. Confidence badge (HI/MD/LO) shows data completeness."
                    )
                    screenerCardView(rows: filteredRows)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.15), value: appeared)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Screener Summary

    private func screenerSummaryView(rows: [SignalScreenerRow]) -> some View {
        let scores = rows.compactMap(\.signalScore)
        let avgScore: Int? = scores.isEmpty ? nil : Int(round(Double(scores.reduce(0, +)) / Double(scores.count)))
        let strongBuys = scores.filter { $0 >= 70 }.count
        let loadingCount = rows.filter(\.isLoading).count

        return HStack(spacing: 0) {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(rows.count)")
                    .textStyle(.cardHero)
                Text("Stocks")
                    .textStyle(.microLabel)
            }
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if loadingCount > 0 {
                    HStack(spacing: 4) {
                        Text(avgScore.map { "\($0)" } ?? "—")
                            .textStyle(.cardHero)
                        ProgressView()
                            .controlSize(.mini)
                    }
                } else {
                    Text(avgScore.map { "\($0)" } ?? "—")
                        .textStyle(.cardHero)
                }
                Text("Avg Score")
                    .textStyle(.microLabel)
            }
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(strongBuys > 0 ? .green : .secondary)
                Text("\(strongBuys)")
                    .textStyle(.cardHero)
                Text("Strong Buys")
                    .textStyle(.microLabel)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .padding(.bottom, 8)
    }

    // MARK: - Score Distribution Bar

    private func scoreDistributionBar(rows: [SignalScreenerRow]) -> some View {
        let scores = rows.compactMap(\.signalScore)
        let strong = scores.filter { $0 >= 70 }.count
        let buy = scores.filter { $0 >= 40 && $0 < 70 }.count
        let hold = scores.filter { $0 < 40 }.count
        let total = max(scores.count, 1)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if strong > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: max(geo.size.width * CGFloat(strong) / CGFloat(total), 8))
                    }
                    if buy > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: max(geo.size.width * CGFloat(buy) / CGFloat(total), 8))
                    }
                    if hold > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: max(geo.size.width * CGFloat(hold) / CGFloat(total), 8))
                    }
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                distributionLegend(color: .green, label: "Strong Buy", count: strong)
                distributionLegend(color: .orange, label: "Buy", count: buy)
                distributionLegend(color: .red, label: "Hold", count: hold)
                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private func distributionLegend(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) (\(count))")
                .textStyle(.microBadge)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ScoreFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = selectedFilter == filter ? .all : filter
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 10))
                            Text(filter.rawValue)
                                .textStyle(.captionBold)
                        }
                        .foregroundStyle(selectedFilter == filter ? .white : filter.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedFilter == filter ? filter.color : filter.color.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 10)
    }

    // MARK: - Screener Card

    private func screenerCardView(rows: [SignalScreenerRow]) -> some View {
        VStack(spacing: 0) {
            if rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No stocks match this filter")
                        .textStyle(.rowDetail)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                    NavigationLink {
                        StockDetailView(
                            result: MassiveTickerSearchResult(
                                ticker: row.ticker,
                                name: row.companyName,
                                market: nil,
                                type: nil,
                                primaryExchange: nil
                            )
                        )
                    } label: {
                        screenerRow(row)
                    }
                    .buttonStyle(.plain)

                    if offset < rows.count - 1 {
                        Divider().opacity(0.3)
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            headerButton("Symbol", column: .symbol, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            headerButton("Mkt Cap", column: .marketCap, alignment: .trailing)
                .frame(width: 80, alignment: .trailing)
            HStack(spacing: 2) {
                headerButton("Score", column: .signalScore, alignment: .trailing)
                Button { showScoreInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.bottom, 8)
        .sheet(isPresented: $showScoreInfo) {
            scoreInfoSheet
        }
    }

    private func headerButton(_ title: String, column: ScreenerSortColumn, alignment: Alignment) -> some View {
        Button {
            if viewModel.sortColumn == column {
                viewModel.sortAscending.toggle()
            } else {
                viewModel.sortColumn = column
                viewModel.sortAscending = false
            }
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(title)
                    .textStyle(.captionBold)
                    .foregroundStyle(viewModel.sortColumn == column ? .primary : .secondary)
                if viewModel.sortColumn == column {
                    Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.primary)
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(viewModel.sortColumn == column ? (viewModel.sortAscending ? "ascending" : "descending") : "not sorted")")
    }

    // MARK: - Row

    private func screenerRow(_ row: SignalScreenerRow) -> some View {
        HStack(spacing: 10) {
            // Colored accent bar based on score
            RoundedRectangle(cornerRadius: 2)
                .fill(row.signalScore.map { scoreColor($0) } ?? Color.gray.opacity(0.3))
                .frame(width: 3, height: 44)

            // Company logo
            CompanyLogoView(
                branding: nil,
                ticker: row.ticker,
                service: massive.service,
                size: 36
            )

            // Ticker + company name + confidence
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(row.ticker)
                        .textStyle(.tickerSymbol)
                    if let confidence = row.confidence {
                        confidenceBadge(confidence)
                    }
                }
                Text(row.companyName)
                    .textStyle(.rowDetail)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Market cap
            Text(row.marketCap.map { formatMarketCap($0) } ?? "—")
                .textStyle(.rowDetail)
                .frame(width: 60, alignment: .trailing)

            // Signal score badge
            Group {
                if row.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let score = row.signalScore {
                    Text("\(score)")
                        .textStyle(.captionBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(scoreColor(score))
                                .shadow(color: scoreColor(score).opacity(0.4), radius: 4, y: 2)
                        )
                } else {
                    Text("—")
                        .textStyle(.captionBold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemFill))
                        )
                }
            }
            .frame(width: 50, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.ticker), \(row.companyName), score \(row.signalScore.map { "\($0)" } ?? "unavailable")")
    }

    // MARK: - Confidence Badge

    private func confidenceBadge(_ confidence: Confidence) -> some View {
        let (label, color): (String, Color) = switch confidence {
        case .high: ("HI", .green)
        case .medium: ("MD", .orange)
        case .low: ("LO", .red)
        }
        return Text(label)
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }

    // MARK: - Score Info Sheet

    private var scoreInfoSheet: some View {
        NavigationStack {
            List {
                criteriaRow(
                    icon: "percent",
                    color: .blue,
                    title: "Dividend Yield",
                    weight: "20%",
                    description: "Scores the annual dividend yield. Sweet spot is 4-6%. Yields above 8% are penalized as potential yield traps."
                )
                criteriaRow(
                    icon: "shield.checkered",
                    color: .green,
                    title: "Payout Safety",
                    weight: "25%",
                    description: "Evaluates dividend sustainability via payout ratio. Below 60% is safe, 60-80% is moderate, above 80% is risky."
                )
                criteriaRow(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .mint,
                    title: "Dividend Growth",
                    weight: "20%",
                    description: "Rewards consistent dividend payment history. 10+ years scores highest, signaling a reliable dividend payer."
                )
                criteriaRow(
                    icon: "person.3.fill",
                    color: .purple,
                    title: "Analyst Consensus",
                    weight: "20%",
                    description: "Weighted average of analyst recommendations (Strong Buy to Strong Sell). More buy ratings = higher score."
                )
                criteriaRow(
                    icon: "waveform.path.ecg",
                    color: .orange,
                    title: "Historical Volatility",
                    weight: "15%",
                    description: "Annualized price volatility from 1 year of daily returns. Lower volatility scores higher — stable prices are better for income investing."
                )
            }
            .navigationTitle("Signal Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showScoreInfo = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func criteriaRow(icon: String, color: Color, title: String, weight: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .textStyle(.rowTitle)
                    Spacer()
                    Text(weight)
                        .textStyle(.captionBold)
                        .foregroundStyle(.secondary)
                }
                Text(description)
                    .textStyle(.rowDetail)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(.rowTitle)
                Text(description)
                    .textStyle(.statLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }
}
