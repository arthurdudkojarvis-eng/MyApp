import SwiftUI

struct PortfolioStrategiesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(builtInStrategies) { strategy in
                NavigationLink {
                    StrategyDetailView(strategy: strategy)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(strategy.name)
                .font(.headline)
            Text(strategy.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label(strategy.riskProfile, systemImage: "shield")
                    .font(.caption2)
                    .foregroundStyle(riskColor(for: strategy.riskProfile))
                Label(strategy.expectedYieldRange, systemImage: "percent")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Label("\(strategy.constituents.count) stocks", systemImage: "list.number")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Strategy Detail

private struct StrategyDetailView: View {
    let strategy: DividendStrategy
    @Environment(\.massiveService) private var massive

    @State private var prices: [String: Decimal] = [:]
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                constituentsList
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
                    .font(.headline)
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
                            .font(.headline)
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

    private func loadPrices() async {
        isLoading = true
        defer { isLoading = false }

        await withTaskGroup(of: (String, Decimal?).self) { group in
            for constituent in strategy.constituents {
                group.addTask {
                    let price = try? await massive.service.fetchPreviousClose(ticker: constituent.ticker)
                    return (constituent.ticker, price)
                }
            }
            for await (ticker, price) in group {
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
