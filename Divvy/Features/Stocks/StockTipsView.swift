import SwiftUI
import SwiftData

struct StockTipsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(builtInStockTips) { tip in
                NavigationLink {
                    StockTipDetailView(tip: tip, onCreated: { dismiss() })
                } label: {
                    StockTipRowView(tip: tip)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Stock Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Tip Row

private struct StockTipRowView: View {
    let tip: StockTip

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tip.name)
                .textStyle(.cardTitle)
            Text(tip.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Image(systemName: "tag")
                    Text(tip.category)
                }
                .font(.caption2)
                .foregroundStyle(.blue)
                HStack(spacing: 2) {
                    Image(systemName: "shield")
                    Text(tip.riskLevel)
                }
                .font(.caption2)
                .foregroundStyle(riskColor(for: tip.riskLevel))
                HStack(spacing: 2) {
                    Image(systemName: "list.number")
                    Text("\(tip.examples.count) examples")
                }
                .font(.caption2)
                .foregroundStyle(.purple)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Tip Detail

private struct StockTipDetailView: View {
    let tip: StockTip
    var onCreated: () -> Void
    @Environment(\.massiveService) private var massive
    @Environment(\.modelContext) private var modelContext
    @Environment(StockRefreshService.self) private var stockRefresh
    @Environment(SettingsStore.self) private var settings

    @State private var prices: [String: Decimal] = [:]
    @State private var isLoading = false
    @State private var isCreating = false

    private var tint: Color { settings.fontTheme.color ?? Color.accentColor }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                examplesList
                createButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(tip.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: tip.id) { await loadPrices() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tip.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tip.category)
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tip.riskLevel)
                        .font(.subheadline.bold())
                        .foregroundStyle(riskColor(for: tip.riskLevel))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Examples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(tip.examples.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var examplesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Example Stocks")
                    .textStyle(.sectionTitle)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            ForEach(tip.examples) { example in
                HStack(spacing: 12) {
                    CompanyLogoView(
                        branding: nil,
                        ticker: example.ticker,
                        service: massive.service,
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.ticker)
                            .textStyle(.tickerSymbol)
                        Text(example.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let price = prices[example.ticker] {
                            Text(price, format: .currency(code: "USD"))
                                .font(.subheadline.bold())
                        }
                        Text(example.note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if example.id != tip.examples.last?.id {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var createButton: some View {
        Button {
            guard !isCreating else { return }
            isCreating = true
            Task { await createPortfolio() }
        } label: {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "folder.badge.plus")
                }
                Text("Create Stock Selection")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isCreating)
    }

    @MainActor
    private func createPortfolio() async {
        defer { isCreating = false }

        guard !tip.examples.isEmpty else { return }

        let notional: Decimal = 1
        let count = tip.examples.count
        let portfolio = Portfolio(name: tip.name)
        modelContext.insert(portfolio)

        var tickers: [String] = []

        for example in tip.examples {
            let ticker = example.ticker
            tickers.append(ticker)

            let stock: Stock
            if let existing = existingStock(ticker: ticker) {
                stock = existing
            } else {
                stock = Stock(ticker: ticker, companyName: example.name)
                modelContext.insert(stock)
            }

            let price = prices[ticker]

            if let price, price > 0 {
                stock.currentPrice = price
                stock.lastUpdated = .now
            }

            let shares: Decimal
            if let price, price > 0, count > 0 {
                shares = (notional / Decimal(count)) / price
            } else {
                shares = 1
            }

            let holding = Holding(shares: shares, averageCostBasis: price ?? 0)
            holding.portfolio = portfolio
            holding.stock = stock
            modelContext.insert(holding)
        }

        do {
            try modelContext.save()
            settings.lastActivePortfolioID = portfolio.id.uuidString
            settings.selectedTab = 1
            let refreshService = stockRefresh
            Task {
                for ticker in tickers {
                    await refreshService.refresh(ticker: ticker)
                }
            }
            onCreated()
        } catch {
            return
        }
    }

    @MainActor
    private func existingStock(ticker: String) -> Stock? {
        let descriptor = FetchDescriptor<Stock>(predicate: #Predicate<Stock> { $0.ticker == ticker })
        return try? modelContext.fetch(descriptor).first
    }

    @MainActor
    private func loadPrices() async {
        isLoading = true
        defer { if !Task.isCancelled { isLoading = false } }

        let api = massive.service
        await withTaskGroup(of: (String, Decimal?).self) { group in
            for example in tip.examples {
                group.addTask {
                    let price = try? await api.fetchPreviousClose(ticker: example.ticker)
                    return (example.ticker, price)
                }
            }
            for await (ticker, price) in group {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                if let price {
                    prices[ticker] = price
                }
            }
        }
    }
}

// MARK: - Helpers

private func riskColor(for level: String) -> Color {
    switch level {
    case "Low": return .green
    case "Moderate": return .yellow
    case "High": return .red
    case "Educational": return .blue
    default: return .secondary
    }
}
