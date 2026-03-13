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
    @State private var noteEditItem: WatchlistItem?

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
                            WatchlistCard(
                                item: item,
                                enriched: enrichedData[item.ticker],
                                service: massive.service,
                                onDelete: { deleteItem(item) },
                                onEditNote: { noteEditItem = item }
                            )
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
        .sheet(item: $noteEditItem) { item in
            EditNoteSheet(item: item)
        }
        .task(id: Set(items.map(\.ticker))) {
            await enrichAll()
        }
    }

    // MARK: - Summary

    private func summaryBar(_ items: [WatchlistItem]) -> some View {
        let (withYield, upcomingCount) = enrichedData.values.reduce(into: (0, 0)) { acc, d in
            if (d.dividendYield ?? 0) > 0 { acc.0 += 1 }
            if d.nextExDate != nil { acc.1 += 1 }
        }

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
                icon: "calendar.badge.clock",
                label: "Upcoming Ex",
                value: "\(upcomingCount)",
                color: upcomingCount > 0 ? .orange : .secondary
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
        guard !items.isEmpty else { return }

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

            // Filter to regular dividends only
            let regularDivs = dividends?.filter { $0.dividendType == "CD" } ?? []

            let latestDiv = regularDivs.first
            let annualYield: Double? = {
                guard let div = latestDiv,
                      let price = prevClose, price > 0 else { return nil }
                let freq = div.frequency ?? 4
                let annualDiv = div.cashAmount * Decimal(freq)
                return NSDecimalNumber(decimal: annualDiv / price).doubleValue * 100
            }()

            // Parse next ex-date (today or future only)
            let todayDate = Calendar.current.startOfDay(for: .now)
            let nextExDate: String? = regularDivs
                .compactMap { div -> (String, Date)? in
                    let str = div.exDividendDate
                    guard let date = WatchlistDateHelper.parseDate(str) else { return nil }
                    return (str, date)
                }
                .filter { $0.1 >= todayDate }
                .sorted { $0.1 < $1.1 }
                .first?.0

            // Payment frequency label
            let frequencyLabel: String? = {
                guard let freq = latestDiv?.frequency else { return nil }
                switch freq {
                case 12: return "Monthly"
                case 4: return "Quarterly"
                case 2: return "Semi-Annual"
                case 1: return "Annual"
                default: return nil
                }
            }()

            return (ticker, WatchlistEnrichedData(
                companyName: details.name,
                sector: details.sicDescription,
                price: prevClose,
                dividendYield: annualYield,
                marketCap: details.marketCap,
                lastDividendAmount: latestDiv?.cashAmount,
                nextExDate: nextExDate,
                frequencyLabel: frequencyLabel,
                companyDescription: details.description
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
        // .task(id:) re-fires automatically when items changes
    }

    private func deleteItem(_ item: WatchlistItem) {
        enrichedData.removeValue(forKey: item.ticker)
        modelContext.delete(item)
    }
}

// MARK: - Date Helper

private enum WatchlistDateHelper {
    private static func makeDateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }

    @MainActor
    static func todayString() -> String {
        makeDateFormatter().string(from: Date.now)
    }

    static func parseDate(_ string: String) -> Date? {
        makeDateFormatter().date(from: string)
    }

    static func daysUntil(_ dateString: String) -> Int? {
        guard let date = parseDate(dateString) else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: date
        ).day
    }

    static func shortDate(_ dateString: String) -> String {
        guard let date = parseDate(dateString) else { return dateString }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Enriched Data

private struct WatchlistEnrichedData {
    let companyName: String
    let sector: String?
    let price: Decimal?
    let dividendYield: Double?
    let marketCap: Decimal?
    let lastDividendAmount: Decimal?
    let nextExDate: String?
    let frequencyLabel: String?
    let companyDescription: String?
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
                .textStyle(.statLabel)
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
    let onEditNote: () -> Void

    private var displayName: String {
        if let name = enriched?.companyName, !name.isEmpty { return name }
        return item.companyName
    }

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private var priceText: String? {
        guard let price = enriched?.price else { return nil }
        return price.formatted(.currency(code: "USD"))
    }

    private var yieldText: String? {
        guard let yield = enriched?.dividendYield, yield > 0 else { return nil }
        return String(format: "%.2f%%", locale: Self.posixLocale, yield)
    }

    private var divPerShareText: String? {
        guard let amount = enriched?.lastDividendAmount, amount > 0 else { return nil }
        return amount.formatted(.currency(code: "USD"))
    }

    private var marketCapText: String? {
        guard let cap = enriched?.marketCap, cap > 0 else { return nil }
        let value = NSDecimalNumber(decimal: cap).doubleValue
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

    private var daysWatching: Int {
        max(0, Calendar.current.dateComponents([.day], from: item.addedDate, to: .now).day ?? 0)
    }

    private var accentStripColor: Color {
        if let yield = enriched?.dividendYield, yield > 0 {
            return .green
        } else if enriched != nil {
            return .gray.opacity(0.3)
        }
        return .clear
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentStripColor)
                .frame(width: 4)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Logo, name, price
                HStack(alignment: .center, spacing: 12) {
                    CompanyLogoView(
                        branding: nil,
                        ticker: item.ticker,
                        service: service,
                        size: 44
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.ticker)
                                .textStyle(.rowTitle)
                            if let freq = enriched?.frequencyLabel {
                                Text(freq)
                                    .textStyle(.microBadge)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                        if !displayName.isEmpty {
                            Text(displayName)
                                .textStyle(.rowDetail)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let price = priceText {
                            Text(price)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        } else {
                            Text("--")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }

                        if let yield = yieldText, let yieldValue = enriched?.dividendYield {
                            Text(yield)
                                .textStyle(.badge)
                                .foregroundStyle(yieldCapsuleColor(yieldValue))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(yieldCapsuleColor(yieldValue).opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Row 2: Dividend info chips
                if let enriched {
                    HStack(spacing: 6) {
                        // Sector + Market Cap
                        if let sector = enriched.sector {
                            InfoChip(icon: "building.2", text: sector, color: .purple)
                        }
                        if let cap = marketCapText {
                            InfoChip(icon: "chart.bar", text: cap, color: .blue)
                        }

                        // Dividend per share
                        if let div = divPerShareText {
                            InfoChip(icon: "banknote", text: "\(div)/share", color: .green)
                        }

                        Spacer()
                    }
                }

                // Row 3: Next ex-date + days watching
                HStack(spacing: 0) {
                    if let exDate = enriched?.nextExDate {
                        let days = WatchlistDateHelper.daysUntil(exDate)
                        let dateLabel = WatchlistDateHelper.shortDate(exDate)
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 10))
                            Text("Ex \(dateLabel)")
                                .font(.caption2.weight(.medium))
                            if let days, days >= 0 {
                                Text("(\(days)d)")
                                    .textStyle(.chartAxis)
                            }
                        }
                        .foregroundStyle(urgencyColor(days: days))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(urgencyColor(days: days).opacity(0.12))
                        .clipShape(Capsule())
                    } else if enriched != nil { // data loaded but no upcoming ex-date
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text("No upcoming ex-date")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text(daysWatchingText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Row 4: Notes (if present)
                if !item.notes.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(item.notes)
                            .textStyle(.rowDetail)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.leading, 10)
            .padding([.trailing, .vertical], 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button {
                onEditNote()
            } label: {
                Label(item.notes.isEmpty ? "Add Note" : "Edit Note", systemImage: "note.text")
            }
            Divider()
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
        .swipeActions(edge: .leading) {
            Button {
                onEditNote()
            } label: {
                Label("Note", systemImage: "note.text")
            }
            .tint(.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [item.ticker]
        if !displayName.isEmpty { parts.append(displayName) }
        if let price = priceText { parts.append("Price \(price)") }
        if let yield = yieldText { parts.append("Yield \(yield)") }
        if let exDate = enriched?.nextExDate {
            parts.append("Ex-date \(WatchlistDateHelper.shortDate(exDate))")
        }
        return parts.joined(separator: ", ")
    }

    private var daysWatchingText: String {
        let days = daysWatching
        if days == 0 { return "Added today" }
        if days == 1 { return "1 day" }
        return "\(days) days"
    }

    private func urgencyColor(days: Int?) -> Color {
        guard let days, days >= 0 else { return .secondary }
        if days <= 3 { return .red }
        if days <= 7 { return .orange }
        return .green
    }

    private func yieldCapsuleColor(_ yield: Double) -> Color {
        if yield >= 5 { return .green }
        if yield >= 2 { return .orange }
        return .blue
    }
}

// MARK: - Info Chip

private struct InfoChip: View {
    let icon: String
    let text: String
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .textStyle(.smallCaption)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Edit Note Sheet

private struct EditNoteSheet: View {
    @Bindable var item: WatchlistItem
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String

    private static let maxNoteLength = 2000

    init(item: WatchlistItem) {
        self.item = item
        _noteText = State(initialValue: item.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Text(item.ticker)
                            .textStyle(.rowTitle)
                        if !item.companyName.isEmpty {
                            Text(item.companyName)
                                .textStyle(.controlLabel)
                        }
                    }
                }

                Section {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 100)
                } header: {
                    Text("Note")
                } footer: {
                    Text("\(noteText.count)/\(Self.maxNoteLength)")
                        .font(.caption2)
                        .foregroundStyle(noteText.count > Self.maxNoteLength ? .red : .secondary)
                }

                if !noteText.isEmpty {
                    Section {
                        Button("Clear Note", role: .destructive) {
                            noteText = ""
                        }
                    }
                }
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.notes = String(noteText.prefix(Self.maxNoteLength))
                        dismiss()
                    }
                }
            }
        }
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
