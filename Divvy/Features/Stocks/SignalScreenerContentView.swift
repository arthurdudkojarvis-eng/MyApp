import SwiftUI
import SwiftData

// MARK: - Signal Screener Content View

struct SignalScreenerContentView: View {
    @Bindable var viewModel: SignalScreenerViewModel

    @Environment(\.massiveService) private var massive
    @Environment(\.finnhubService) private var finnhub
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Query private var watchlistItems: [WatchlistItem]
    @State private var showScoreInfo = false

    var body: some View {
        Group {
            if viewModel.isInitialLoading && viewModel.rows.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.rows.isEmpty {
                ContentUnavailableView(
                    "No Stocks to Score",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Add stocks to your Watchlist or Portfolio to see signal scores here.")
                )
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
    }

    // MARK: - Screener List

    private var screenerList: some View {
        VStack(spacing: 0) {
            columnHeaders
            List {
                ForEach(viewModel.displayedRows) { row in
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
                }
            }
            .listStyle(.plain)
        }
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
        .padding(.vertical, 6)
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
        HStack(spacing: 0) {
            // Ticker + company name
            VStack(alignment: .leading, spacing: 2) {
                Text(row.ticker)
                    .textStyle(.tickerSymbol)
                Text(row.companyName)
                    .textStyle(.rowDetail)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Market cap
            Text(row.marketCap.map { formatMarketCap($0) } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            // Signal score badge
            Group {
                if row.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let score = row.signalScore {
                    Text("\(score)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(scoreColor(score))
                        .clipShape(Capsule())
                } else {
                    Text("—")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray)
                        .clipShape(Capsule())
                }
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.ticker), \(row.companyName), score \(row.signalScore.map { "\($0)" } ?? "unavailable")")
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
                        .font(.subheadline.bold())
                    Spacer()
                    Text(weight)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }
}
