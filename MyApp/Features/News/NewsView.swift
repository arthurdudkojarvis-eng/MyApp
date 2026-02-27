import SwiftUI
import SwiftData

struct NewsView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(SettingsStore.self) private var settings
    @Environment(\.polygonService) private var polygon
    @Environment(\.openURL) private var openURL

    @State private var articles: [PolygonNewsArticle] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedTicker: String?

    private var heldTickers: [String] {
        portfolios
            .flatMap(\.holdings)
            .compactMap { $0.stock?.ticker }
            .removingDuplicates()
            .sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !heldTickers.isEmpty {
                    tickerPicker
                }
                contentArea
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("News & Events")
        .navigationBarTitleDisplayMode(.large)
        .task(id: selectedTicker) { await loadNews() }
        .refreshable { await loadNews() }
    }

    // MARK: - Sections

    private var tickerPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All Holdings", isSelected: selectedTicker == nil) {
                    selectedTicker = nil
                }
                ForEach(heldTickers, id: \.self) { ticker in
                    FilterChip(label: ticker, isSelected: selectedTicker == ticker) {
                        selectedTicker = ticker
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if let error = loadError {
            ContentUnavailableView(
                "Could Not Load News",
                systemImage: "newspaper",
                description: Text(error)
            )
            .padding(.top, 20)
        } else if articles.isEmpty {
            ContentUnavailableView(
                heldTickers.isEmpty ? "No Holdings" : "No News Found",
                systemImage: "newspaper",
                description: Text(heldTickers.isEmpty
                    ? "Add holdings to see relevant news."
                    : "No recent news found for your holdings.")
            )
            .padding(.top, 20)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(articles) { article in
                    ArticleCard(article: article, onTap: {
                        if let url = URL(string: article.articleUrl),
                           url.scheme == "https" {
                            openURL(url)
                        }
                    })
                }
            }
        }
    }

    // MARK: - Data loading

    private func loadNews() async {
        guard settings.hasPolygonAPIKey else {
            loadError = "Add a Polygon API key in Settings to load news."
            return
        }
        let tickers = selectedTicker.map { [$0] } ?? heldTickers
        guard !tickers.isEmpty else {
            articles = []
            return
        }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            articles = try await polygon.service.fetchNews(
                tickers: tickers,
                limit: 20,
                apiKey: settings.polygonAPIKey
            )
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Article Card

private struct ArticleCard: View {
    let article: PolygonNewsArticle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.subheadline.bold())
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        if let description = article.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }

                HStack(spacing: 8) {
                    if let tickers = article.tickers, !tickers.isEmpty {
                        Text(tickers.prefix(3).joined(separator: ", "))
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if let author = article.author, !author.isEmpty {
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Text(publishedDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private var publishedDate: String {
        if let date = Self.isoFormatterWithFractional.date(from: article.publishedUtc) {
            return date.formatted(.relative(presentation: .named))
        }
        if let date = Self.isoFormatter.date(from: article.publishedUtc) {
            return date.formatted(.relative(presentation: .named))
        }
        return article.publishedUtc
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Array helper

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview
    let settings = SettingsStore()
    return NavigationStack {
        NewsView()
    }
    .modelContainer(container)
    .environment(settings)
    .environment(StockRefreshService(settings: settings, container: container))
}
