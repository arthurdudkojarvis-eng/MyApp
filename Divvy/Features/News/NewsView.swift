import SwiftUI
import SwiftData

struct NewsView: View {
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Environment(\.massiveService) private var massive
    @Environment(\.openURL) private var openURL

    @State private var articles: [MassiveNewsArticle] = []
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
        let tickers = heldTickers
        ScrollView {
            VStack(spacing: 0) {
                if !tickers.isEmpty {
                    tickerStrip(tickers)
                }
                contentArea(tickers: tickers)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("News & Events")
        .navigationBarTitleDisplayMode(.large)
        .task(id: selectedTicker) { await loadNews() }
        .refreshable { await loadNews() }
    }

    // MARK: - Ticker Strip

    private func tickerStrip(_ tickers: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                NewsFilterChip(label: "All", isSelected: selectedTicker == nil) {
                    selectedTicker = nil
                }
                ForEach(tickers, id: \.self) { ticker in
                    NewsFilterChip(label: ticker, isSelected: selectedTicker == ticker) {
                        selectedTicker = ticker
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentArea(tickers: [String]) -> some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading news...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        } else if let error = loadError {
            ContentUnavailableView(
                "Could Not Load News",
                systemImage: "newspaper",
                description: Text(error)
            )
            .padding(.top, 40)
        } else if articles.isEmpty {
            ContentUnavailableView(
                tickers.isEmpty ? "No Holdings" : "No News Found",
                systemImage: "newspaper",
                description: Text(tickers.isEmpty
                    ? "Add holdings to see relevant news."
                    : "No recent news for your holdings.")
            )
            .padding(.top, 40)
        } else {
            articleList(articles)
        }
    }

    private func articleList(_ articles: [MassiveNewsArticle]) -> some View {
        let featured = articles.first(where: { $0.imageUrl != nil })
        let remaining = featured.map { f in articles.filter { $0.id != f.id } } ?? articles

        return LazyVStack(spacing: 0) {
            if let featured {
                FeaturedArticleCard(article: featured) {
                    openArticle(featured)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            if !remaining.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Latest")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    ForEach(Array(remaining.enumerated()), id: \.element.id) { index, article in
                        NewsArticleRow(article: article, service: massive.service) {
                            openArticle(article)
                        }

                        if index < remaining.count - 1 {
                            Divider()
                                .padding(.leading, 80)
                        }
                    }
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func openArticle(_ article: MassiveNewsArticle) {
        guard let url = URL(string: article.articleUrl),
              url.scheme == "https" || url.scheme == "http",
              let host = url.host, !host.isEmpty
        else { return }
        openURL(url)
    }

    // MARK: - Data loading

    private func loadNews() async {
        let tickers = selectedTicker.map { [$0] } ?? heldTickers
        guard !tickers.isEmpty else {
            articles = []
            loadError = nil
            return
        }
        isLoading = true
        loadError = nil
        defer {
            if !Task.isCancelled { isLoading = false }
        }
        do {
            articles = try await massive.service.fetchNews(
                tickers: tickers,
                limit: 20
            )
        } catch {
            if !Task.isCancelled {
                loadError = "Unable to load news. Check your connection and try again."
            }
        }
    }
}

// MARK: - Featured Article Card

private struct FeaturedArticleCard: View {
    let article: MassiveNewsArticle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                if let rawURL = article.imageUrl,
                   let imageURL = URL(string: rawURL),
                   imageURL.scheme == "https" {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                        case .failure, .empty:
                            imagePlaceholder
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                    .frame(height: 180)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16,
                            style: .continuous
                        )
                    )
                }

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Ticker badges
                    if let tickers = article.tickers, !tickers.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(tickers.prefix(4), id: \.self) { ticker in
                                Text(ticker)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Text(article.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .foregroundStyle(.primary)

                    if let description = article.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Footer
                    HStack {
                        if let author = article.author, !author.isEmpty {
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(formattedDate(article.publishedUtc))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
        .accessibilityHint("Opens article in browser")
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemGroupedBackground))
            .frame(height: 180)
            .overlay {
                Image(systemName: "newspaper")
                    .font(.title)
                    .foregroundStyle(.quaternary)
            }
    }
}

// MARK: - News Article Row

private struct NewsArticleRow: View {
    let article: MassiveNewsArticle
    let service: any MassiveFetching
    let onTap: () -> Void

    private var leadingTicker: String? {
        article.tickers?.first
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Logo or thumbnail
                articleVisual

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if let tickers = article.tickers, !tickers.isEmpty {
                            Text(tickers.prefix(2).joined(separator: " "))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.accentColor)

                            Circle()
                                .fill(Color(.tertiaryLabel))
                                .frame(width: 3, height: 3)
                        }

                        Text(formattedDate(article.publishedUtc))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
        .accessibilityHint("Opens article in browser")
    }

    @ViewBuilder
    private var articleVisual: some View {
        if let ticker = leadingTicker {
            CompanyLogoView(
                branding: nil,
                ticker: ticker,
                service: service,
                size: 40
            )
        } else if let rawURL = article.imageUrl,
                  let imageURL = URL(string: rawURL),
                  imageURL.scheme == "https" {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                case .failure, .empty:
                    newsIconPlaceholder
                @unknown default:
                    newsIconPlaceholder
                }
            }
            .frame(width: 40, height: 40)
        } else {
            newsIconPlaceholder
        }
    }

    private var newsIconPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: "newspaper")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
    }
}

// MARK: - Filter Chip

private struct NewsFilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Date Formatting

private let isoFormatterWithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private func formattedDate(_ utcString: String) -> String {
    if let date = isoFormatterWithFractional.date(from: utcString) {
        return date.formatted(.relative(presentation: .named))
    }
    if let date = isoFormatter.date(from: utcString) {
        return date.formatted(.relative(presentation: .named))
    }
    return "Unknown date"
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
    return NavigationStack {
        NewsView()
    }
    .modelContainer(container)
    .environment(StockRefreshService(container: container))
}
