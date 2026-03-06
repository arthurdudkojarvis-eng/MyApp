import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(\.massiveService) private var massive

    @Query(sort: \WatchlistItem.addedDate, order: .reverse) private var items: [WatchlistItem]

    @State private var showAddSheet = false
    @State private var newTicker = ""
    @State private var addError: String?
    @State private var isAdding = false
    @State private var enrichedData: [String: WatchlistEnrichedData] = [:]
    @State private var isEnriching = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Watchlist Empty",
                        systemImage: "eye",
                        description: Text("Add tickers you're researching before committing to a position.")
                    )
                    .padding(.top, 60)
                } else {
                    summaryBar(items)

                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                WatchlistCard(
                                    item: item,
                                    enriched: enrichedData[item.ticker],
                                    service: massive.service,
                                    onDelete: { deleteItem(item) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Watchlist")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: WatchlistItem.self) { item in
            WatchlistItemDetailView(item: item)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add to watchlist")
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: { newTicker = ""; addError = nil }) {
            AddToWatchlistSheet(
                ticker: $newTicker,
                error: $addError,
                isAdding: $isAdding,
                onAdd: addItem
            )
        }
        .task(id: items.map(\.ticker).sorted().joined(separator: ",")) {
            await enrichAll()
        }
    }

    // MARK: - Summary

    private func summaryBar(_ items: [WatchlistItem]) -> some View {
        let withYield = enrichedData.values.filter { ($0.dividendYield ?? 0) > 0 }.count
        let enrichedCount = enrichedData.count

        return HStack(spacing: 0) {
            SummaryPill(
                icon: "eye.fill",
                label: "Watching",
                value: "\(items.count)"
            )
            Spacer()
            SummaryPill(
                icon: "dollarsign.circle.fill",
                label: "Pay Dividends",
                value: "\(withYield)",
                color: .green
            )
            Spacer()
            SummaryPill(
                icon: "checkmark.circle.fill",
                label: "Loaded",
                value: "\(enrichedCount)/\(items.count)",
                color: enrichedCount == items.count ? .green : .orange
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Enrichment

    private func enrichAll() async {
        guard !items.isEmpty, !isEnriching else { return }
        isEnriching = true
        defer { isEnriching = false }

        await withTaskGroup(of: (String, WatchlistEnrichedData?).self) { group in
            for item in items {
                guard enrichedData[item.ticker] == nil else { continue }
                group.addTask {
                    await enrichItem(ticker: item.ticker)
                }
            }
            for await (ticker, data) in group {
                if let data {
                    enrichedData[ticker] = data
                }
            }
        }
    }

    private func enrichItem(ticker: String) async -> (String, WatchlistEnrichedData?) {
        do {
            let svc = massive.service
            async let detailsFetch = svc.fetchTickerDetails(ticker: ticker)
            async let prevCloseFetch: Decimal? = try? svc.fetchPreviousClose(ticker: ticker)
            async let dividendsFetch: [MassiveDividend]? = try? svc.fetchDividends(ticker: ticker, limit: 4)

            let details = try await detailsFetch
            guard !Task.isCancelled else { return (ticker, nil) }

            let prevClose = await prevCloseFetch
            let dividends = await dividendsFetch
            guard !Task.isCancelled else { return (ticker, nil) }

            let annualYield: Double? = {
                guard let divs = dividends, !divs.isEmpty,
                      let price = prevClose, price > 0 else { return nil }
                let annualDiv = divs.reduce(Decimal.zero) { $0 + $1.cashAmount }
                return (annualDiv as NSDecimalNumber).doubleValue
                    / (price as NSDecimalNumber).doubleValue * 100
            }()

            return (ticker, WatchlistEnrichedData(
                companyName: details.name,
                sector: details.sicDescription,
                price: prevClose,
                dividendYield: annualYield,
                marketCap: details.marketCap
            ))
        } catch {
            return (ticker, nil)
        }
    }

    // MARK: - Actions

    private static let tickerAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))

    private func addItem() {
        let ticker = newTicker.trimmingCharacters(in: .whitespaces).uppercased()
        guard !ticker.isEmpty else { return }

        guard ticker.count <= 12,
              ticker.unicodeScalars.allSatisfy({ Self.tickerAllowed.contains($0) }) else {
            addError = "Ticker must be 1-12 alphanumeric characters."
            return
        }

        if items.contains(where: { $0.ticker == ticker }) {
            addError = "\(ticker) is already in your watchlist."
            return
        }

        let item = WatchlistItem(ticker: ticker)
        modelContext.insert(item)
        showAddSheet = false

        Task {
            let result = await enrichItem(ticker: ticker)
            if let data = result.1 {
                enrichedData[ticker] = data
            }
        }
    }

    private func deleteItem(_ item: WatchlistItem) {
        enrichedData.removeValue(forKey: item.ticker)
        modelContext.delete(item)
    }
}

// MARK: - Enriched Data

private struct WatchlistEnrichedData {
    let companyName: String
    let sector: String?
    let price: Decimal?
    let dividendYield: Double?
    let marketCap: Decimal?
}

// MARK: - Summary Pill

private struct SummaryPill: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .accentColor

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Watchlist Card

private struct WatchlistCard: View {
    let item: WatchlistItem
    let enriched: WatchlistEnrichedData?
    let service: any MassiveFetching
    let onDelete: () -> Void

    private var displayName: String {
        if let name = enriched?.companyName, !name.isEmpty { return name }
        return item.companyName
    }

    private var priceText: String? {
        guard let price = enriched?.price else { return nil }
        return price.formatted(.currency(code: "USD"))
    }

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private var yieldText: String? {
        guard let yield = enriched?.dividendYield, yield > 0 else { return nil }
        return String(format: "%.2f%%", locale: Self.posixLocale, yield)
    }

    private var marketCapText: String? {
        guard let cap = enriched?.marketCap, cap > 0 else { return nil }
        let value = (cap as NSDecimalNumber).doubleValue
        switch value {
        case 1_000_000_000_000...:
            return String(format: "$%.1fT", locale: Self.posixLocale, value / 1_000_000_000_000)
        case 1_000_000_000...:
            return String(format: "$%.1fB", locale: Self.posixLocale, value / 1_000_000_000)
        case 1_000_000...:
            return String(format: "$%.0fM", locale: Self.posixLocale, value / 1_000_000)
        default:
            return String(format: "$%.0f", locale: Self.posixLocale, value)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CompanyLogoView(
                branding: nil,
                ticker: item.ticker,
                service: service,
                size: 44
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.ticker)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !displayName.isEmpty {
                    Text(displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let sector = enriched?.sector {
                        Text(sector)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    if enriched?.sector != nil, marketCapText != nil {
                        Circle()
                            .fill(Color(.tertiaryLabel))
                            .frame(width: 3, height: 3)
                    }
                    if let cap = marketCapText {
                        Text(cap)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let price = priceText {
                    Text(price)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                } else {
                    Text("--")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }

                if let yield = yieldText {
                    HStack(spacing: 3) {
                        Image(systemName: "dollarsign.arrow.circlepath")
                            .font(.system(size: 9))
                        Text(yield)
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.green)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove from Watchlist", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            var parts = [item.ticker]
            if !displayName.isEmpty { parts.append(displayName) }
            if let price = priceText { parts.append("Price \(price)") }
            if let yield = yieldText { parts.append("Yield \(yield)") }
            return parts.joined(separator: ", ")
        }())
    }
}

// MARK: - Watchlist Item Detail

struct WatchlistItemDetailView: View {
    let item: WatchlistItem

    @Environment(\.modelContext) private var modelContext

    private var searchResult: MassiveTickerSearchResult {
        MassiveTickerSearchResult(
            ticker: item.ticker,
            name: item.companyName.isEmpty ? item.ticker : item.companyName,
            market: "stocks",
            type: nil,
            primaryExchange: nil
        )
    }

    var body: some View {
        StockDetailView(result: searchResult)
    }
}

// MARK: - Add to Watchlist Sheet

private struct AddToWatchlistSheet: View {
    @Binding var ticker: String
    @Binding var error: String?
    @Binding var isAdding: Bool
    let onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ticker symbol (e.g. AAPL)", text: $ticker)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($isFocused)
                        .onChange(of: ticker) { _, _ in error = nil }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add to Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd() }
                        .disabled(ticker.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        WatchlistView()
    }
    .modelContainer(container)
    .environment(settings)
    .environment(StockRefreshService(container: container))
}
