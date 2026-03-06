import SwiftUI

struct ETFTipsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(builtInETFTips) { tip in
                NavigationLink {
                    ETFTipDetailView(tip: tip)
                } label: {
                    ETFTipRowView(tip: tip)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ETF Tips")
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

private struct ETFTipRowView: View {
    let tip: ETFTip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tip.name)
                .font(.headline)
            Text(tip.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label(tip.category, systemImage: "tag")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Label(tip.riskLevel, systemImage: "shield")
                    .font(.caption2)
                    .foregroundStyle(etfRiskColor(for: tip.riskLevel))
                Label("\(tip.examples.count) examples", systemImage: "list.number")
                    .font(.caption2)
                    .foregroundStyle(.purple)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tip Detail

private struct ETFTipDetailView: View {
    let tip: ETFTip
    @Environment(\.massiveService) private var massive

    @State private var prices: [String: Decimal] = [:]
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                examplesList
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
                        .foregroundStyle(etfRiskColor(for: tip.riskLevel))
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
                Text("Example ETFs")
                    .font(.headline)
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
                            .font(.headline)
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

private func etfRiskColor(for level: String) -> Color {
    switch level {
    case "Low": return .green
    case "Moderate": return .yellow
    case "High": return .red
    case "Educational": return .blue
    default: return .secondary
    }
}
