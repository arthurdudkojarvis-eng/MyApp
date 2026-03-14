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
        .navigationTitle("Screener")
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
            searchField
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

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter stocks…", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            headerButton("Symbol", column: .symbol, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            headerButton("Mkt Cap", column: .marketCap, alignment: .trailing)
                .frame(width: 80, alignment: .trailing)
            headerButton("Score", column: .signalScore, alignment: .trailing)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
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

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }
}
