import SwiftUI
import SwiftData

struct PortfolioStrategiesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(builtInStrategies) { strategy in
                NavigationLink {
                    StrategyDetailView(strategy: strategy, onCreated: { dismiss() })
                } label: {
                    StrategyRowView(strategy: strategy)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Strategies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Strategy Row

private struct StrategyRowView: View {
    let strategy: DividendStrategy

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(strategy.name)
                .textStyle(.cardTitle)
            Text(strategy.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Image(systemName: "shield")
                    Text(strategy.riskProfile)
                }
                .font(.caption2)
                .foregroundStyle(riskColor(for: strategy.riskProfile))
                Text(strategy.expectedYieldRange)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                HStack(spacing: 2) {
                    Image(systemName: "list.number")
                    Text("\(strategy.constituents.count) stocks")
                }
                .font(.caption2)
                .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Strategy Detail

private struct StrategyDetailView: View {
    let strategy: DividendStrategy
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
                constituentsList
                createButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(strategy.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPrices() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strategy.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk Profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(strategy.riskProfile)
                        .font(.subheadline.bold())
                        .foregroundStyle(riskColor(for: strategy.riskProfile))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expected Yield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(strategy.expectedYieldRange)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stocks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(strategy.constituents.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var constituentsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Constituents")
                    .textStyle(.sectionTitle)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            ForEach(strategy.constituents) { constituent in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(constituent.ticker)
                            .textStyle(.tickerSymbol)
                        Text(constituent.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(constituent.allocationPercent))%")
                            .font(.subheadline.bold())
                            .foregroundStyle(.purple)
                        if let price = prices[constituent.ticker] {
                            Text(price, format: .currency(code: "USD"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if constituent.id != strategy.constituents.last?.id {
                    Divider().padding(.leading, 16)
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
                Text("Create Portfolio")
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

        guard !strategy.constituents.isEmpty else { return }

        let notional: Decimal = 1
        let portfolio = Portfolio(name: strategy.name)
        modelContext.insert(portfolio)

        var tickers: [String] = []

        for constituent in strategy.constituents {
            let ticker = constituent.ticker
            tickers.append(ticker)

            let stock: Stock
            if let existing = existingStock(ticker: ticker) {
                stock = existing
            } else {
                stock = Stock(ticker: ticker, companyName: constituent.name)
                modelContext.insert(stock)
            }

            let price = prices[ticker]
            let shares: Decimal
            if let price, price > 0 {
                shares = (notional * Decimal(constituent.allocationPercent) / 100) / price
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
            for constituent in strategy.constituents {
                group.addTask {
                    let price = try? await api.fetchPreviousClose(ticker: constituent.ticker)
                    return (constituent.ticker, price)
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

private func riskColor(for profile: String) -> Color {
    switch profile {
    case "Conservative": return .green
    case "Moderate-Low": return .mint
    case "Moderate": return .yellow
    case "Moderate-High": return .orange
    case "High": return .red
    default: return .secondary
    }
}
