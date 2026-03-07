import SwiftUI
import SwiftData

// MARK: - CalendarGroup (kept for unit tests in DividendCalendarTests.swift)

/// One month-bucket of sorted `DividendSchedule` records.
/// The `key` (`yyyyMM` integer) is used for sort order and as the `ScrollViewReader` anchor id.
struct CalendarGroup {
    let key: Int              // e.g. 202502 for February 2025
    let monthLabel: String    // e.g. "February 2025"
    let schedules: [DividendSchedule]
}

// MARK: - Grouping helpers (internal so unit tests can reach them)

/// Groups `schedules` by pay-date month, sorts groups chronologically,
/// and sorts schedules within each group by `payDate` ascending.
func calendarGroups(
    from schedules: [DividendSchedule],
    calendar: Calendar = .current
) -> [CalendarGroup] {
    let grouped = Dictionary(grouping: schedules) { schedule -> Int in
        let comps = calendar.dateComponents([.year, .month], from: schedule.payDate)
        return (comps.year ?? 0) * 100 + (comps.month ?? 0)
    }
    return grouped.keys.sorted().map { key in
        let sorted = grouped[key, default: []].sorted { $0.payDate < $1.payDate }
        let label = sorted.first?.payDate.formatted(.dateTime.month(.wide).year()) ?? ""
        return CalendarGroup(key: key, monthLabel: label, schedules: sorted)
    }
}

/// Returns the `yyyyMM` key of the current month if present in `keys`,
/// otherwise the nearest future month, or `nil` if all keys are in the past.
func scrollTargetKey(
    from keys: [Int],
    currentDate: Date = .now,
    calendar: Calendar = .current
) -> Int? {
    let comps = calendar.dateComponents([.year, .month], from: currentDate)
    let currentKey = (comps.year ?? 0) * 100 + (comps.month ?? 0)
    return keys.first(where: { $0 >= currentKey })
}

// MARK: - CalendarDividendEvent

/// A pure-value snapshot of one `DividendSchedule` enriched with the user's
/// calculated total dollar amount (amountPerShare × shares held).
/// All fields are copied from the model at construction time — no live model ref retained.
struct CalendarDividendEvent: Identifiable {
    let id: UUID
    let payDate: Date
    let ticker: String
    let companyName: String
    let amountPerShare: Decimal
    /// amountPerShare × sum of shares across all holdings for this stock.
    let totalAmount: Decimal
    let status: DividendScheduleStatus
}

// MARK: - DividendCalendarView

struct DividendCalendarView: View {
    @Query(sort: \DividendSchedule.payDate) private var schedules: [DividendSchedule]
    @Environment(\.massiveService) private var massive

    @State private var eventsByDay: [Date: [CalendarDividendEvent]] = [:]
    @State private var holidays: [Date: MassiveMarketHoliday] = [:]
    @State private var cachedSummary = MonthSummaryData(
        monthLabel: "", totalIncome: .zero, paymentCount: 0, stockCount: 0, nextPaymentTicker: nil
    )

    @State private var selectedDay: DaySheetItem?
    @State private var hasScrolled = false

    private var hasEvents: Bool { !eventsByDay.isEmpty }

    // 24-month window starting Jan 1 of the current year — stable for the session.
    private static let months: [Date] = {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        guard let jan = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        return (0..<24).compactMap { cal.date(byAdding: .month, value: $0, to: jan) }
    }()

    var body: some View {
        Group {
            if !hasEvents {
                ContentUnavailableView(
                    "No Dividend Events",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(
                        "Add holdings with dividend schedules to see upcoming payments."
                    )
                )
            } else {
                calendarScrollView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedDay) { item in
            DividendDaySheet(events: item.events)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: schedules, initial: true) { rebuildEvents() }
        .task { await loadHolidays() }
    }

    private var calendarScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    statusLegend

                    LazyVStack(spacing: 20) {
                        ForEach(Self.months, id: \.timeIntervalSinceReferenceDate) { month in
                            MonthGridView(
                                month: month,
                                eventsByDay: eventsByDay,
                                holidays: holidays
                            ) { dayEvents in
                                selectedDay = DaySheetItem(events: dayEvents)
                            }
                            .id(monthKey(for: month))
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .task(id: hasEvents) {
                guard hasEvents, !hasScrolled else { return }
                hasScrolled = true
                proxy.scrollTo(monthKey(for: .now), anchor: .top)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let summary = cachedSummary
        return VStack(spacing: 14) {
            HStack {
                Text(summary.monthLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if summary.paymentCount > 0 {
                    Text("\(summary.paymentCount) payment\(summary.paymentCount == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(summary.totalIncome, format: .currency(code: "USD"))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer()
            }

            Divider()

            HStack(spacing: 0) {
                SummaryQuickStat(
                    icon: "building.2",
                    label: "Stocks",
                    value: "\(summary.stockCount)"
                )
                Spacer()
                SummaryQuickStat(
                    icon: "calendar.badge.clock",
                    label: "Payments",
                    value: "\(summary.paymentCount)"
                )
                Spacer()
                if let nextTicker = summary.nextPaymentTicker {
                    SummaryQuickStat(
                        icon: "arrow.right.circle",
                        label: "Next",
                        value: nextTicker
                    )
                } else {
                    SummaryQuickStat(
                        icon: "checkmark.circle",
                        label: "Status",
                        value: summary.paymentCount > 0 ? "All paid" : "None"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .padding(.horizontal, 16)
    }

    // MARK: - Status Legend

    private var statusLegend: some View {
        HStack(spacing: 16) {
            legendItem(color: .green, label: "Declared")
            legendItem(color: .orange, label: "Estimated")
            legendItem(color: .blue, label: "Paid")
            Spacer()
            legendItem(color: .red.opacity(0.5), label: "Market Closed", isCapsule: true)
        }
        .padding(.horizontal, 20)
    }

    private func legendItem(color: Color, label: String, isCapsule: Bool = false) -> some View {
        HStack(spacing: 4) {
            if isCapsule {
                Capsule()
                    .fill(color)
                    .frame(width: 10, height: 3)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 10, design: .default).leading(.tight))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Event cache

    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func rebuildEvents() {
        let cal = Calendar.current
        let utc = Self.utcCalendar
        var byDay: [Date: [CalendarDividendEvent]] = [:]
        for schedule in schedules {
            guard let stock = schedule.stock, !stock.holdings.isEmpty else { continue }
            let totalShares = stock.holdings.reduce(Decimal.zero) { $0 + $1.shares }
            let event = CalendarDividendEvent(
                id: schedule.id,
                payDate: schedule.payDate,
                ticker: stock.ticker,
                companyName: stock.companyName,
                amountPerShare: schedule.amountPerShare,
                totalAmount: schedule.amountPerShare * totalShares,
                status: schedule.status
            )
            let comps = utc.dateComponents([.year, .month, .day], from: schedule.payDate)
            let key = cal.startOfDay(for: cal.date(from: comps) ?? schedule.payDate)
            byDay[key, default: []].append(event)
        }
        eventsByDay = byDay
        cachedSummary = Self.buildMonthSummary(from: byDay, calendar: cal)
    }

    private static func buildMonthSummary(
        from byDay: [Date: [CalendarDividendEvent]], calendar cal: Calendar
    ) -> MonthSummaryData {
        let now = Date.now
        let today = cal.startOfDay(for: now)
        var totalIncome = Decimal.zero
        var paymentCount = 0
        var stockTickers = Set<String>()
        var nextDay: Date?

        for (day, events) in byDay {
            guard cal.isDate(day, equalTo: now, toGranularity: .month) else { continue }
            for event in events {
                totalIncome += event.totalAmount
                paymentCount += 1
                stockTickers.insert(event.ticker)
            }
            if day >= today {
                if nextDay == nil || day < nextDay! {
                    nextDay = day
                }
            }
        }

        // Collect all tickers paying on the next upcoming day
        let nextTicker: String?
        if let nextDay, let dayEvents = byDay[nextDay] {
            let tickers = dayEvents.map(\.ticker)
            if tickers.count == 1 {
                nextTicker = tickers[0]
            } else {
                nextTicker = "\(tickers.count) stocks"
            }
        } else {
            nextTicker = nil
        }

        return MonthSummaryData(
            monthLabel: now.formatted(.dateTime.month(.wide).year()),
            totalIncome: totalIncome,
            paymentCount: paymentCount,
            stockCount: stockTickers.count,
            nextPaymentTicker: nextTicker
        )
    }

    private static let holidayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func loadHolidays() async {
        let formatter = Self.holidayDateFormatter
        let cal = Calendar.current
        let utc = Self.utcCalendar
        do {
            let results = try await massive.service.fetchMarketHolidays()
            guard !Task.isCancelled else { return }
            var byDay: [Date: MassiveMarketHoliday] = [:]
            for holiday in results {
                if let date = formatter.date(from: holiday.date) {
                    let comps = utc.dateComponents([.year, .month, .day], from: date)
                    let key = cal.startOfDay(for: cal.date(from: comps) ?? date)
                    byDay[key] = holiday
                }
            }
            holidays = byDay
        } catch {
            // Non-critical — holidays just won't show
        }
    }

    private func monthKey(for date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return (c.year ?? 0) * 100 + (c.month ?? 0)
    }
}

// MARK: - Month Summary Data

private struct MonthSummaryData {
    let monthLabel: String
    let totalIncome: Decimal
    let paymentCount: Int
    let stockCount: Int
    let nextPaymentTicker: String?
}

// MARK: - Summary Quick Stat

private struct SummaryQuickStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - DaySheetItem

private struct DaySheetItem: Identifiable {
    let events: [CalendarDividendEvent]
    var id: UUID { events.first?.id ?? UUID() }
}

// MARK: - MonthStockSummary

private struct MonthStockSummary: Identifiable {
    let ticker: String
    let companyName: String
    let totalAmount: Decimal
    let paymentCount: Int
    var id: String { ticker }
}

// MARK: - MonthGridView

private struct MonthGridView: View {
    let month: Date
    let eventsByDay: [Date: [CalendarDividendEvent]]
    let holidays: [Date: MassiveMarketHoliday]
    let onDayTap: ([CalendarDividendEvent]) -> Void

    @State private var showMonthSummary = false

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var dayGrid: [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }
        let firstWeekday = cal.firstWeekday
        let rawWeekday   = cal.component(.weekday, from: firstOfMonth)
        let leadingNilCount = (rawWeekday - firstWeekday + 7) % 7
        let days: [Date?] = range.map { dayNumber in
            cal.date(byAdding: .day, value: dayNumber - 1, to: firstOfMonth)
        }
        return Array(repeating: Date?.none, count: leadingNilCount) + days
    }

    private static let daySymbols = Calendar.current.veryShortWeekdaySymbols

    private var monthMetrics: (hasEvents: Bool, total: Decimal, summaries: [MonthStockSummary]) {
        let cal = Calendar.current
        var total = Decimal.zero
        var byTicker: [String: (name: String, amount: Decimal, count: Int)] = [:]
        for (day, events) in eventsByDay {
            guard cal.isDate(day, equalTo: month, toGranularity: .month) else { continue }
            for event in events {
                total += event.totalAmount
                let e = byTicker[event.ticker, default: (event.companyName, .zero, 0)]
                byTicker[event.ticker] = (e.name, e.amount + event.totalAmount, e.count + 1)
            }
        }
        let summaries = byTicker.map {
            MonthStockSummary(ticker: $0.key, companyName: $0.value.name,
                              totalAmount: $0.value.amount, paymentCount: $0.value.count)
        }.sorted { $0.totalAmount > $1.totalAmount }
        return (!byTicker.isEmpty, total, summaries)
    }

    var body: some View {
        let cal = Calendar.current
        let metrics = monthMetrics
        let total = metrics.total
        let hasEvents = metrics.hasEvents

        VStack(alignment: .leading, spacing: 8) {
            // Month header
            HStack(alignment: .firstTextBaseline) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                if total > 0 {
                    Text(total, format: .currency(code: "USD"))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                if hasEvents {
                    Button {
                        showMonthSummary = true
                    } label: {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Month summary")
                }
            }
            .padding(.horizontal, 16)

            // Day-of-week header
            LazyVGrid(columns: Self.columns, spacing: 0) {
                ForEach(Self.daySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 8)

            // Day cells
            let grid = dayGrid
            LazyVGrid(columns: Self.columns, spacing: 2) {
                ForEach(grid.indices, id: \.self) { index in
                    if let date = grid[index] {
                        let start = cal.startOfDay(for: date)
                        let dayEvents = eventsByDay[start] ?? []
                        let holiday = holidays[start]
                        CalendarDayCell(
                            day: cal.component(.day, from: date),
                            isToday: cal.isDateInToday(date),
                            events: dayEvents,
                            holiday: holiday
                        ) {
                            if !dayEvents.isEmpty { onDayTap(dayEvents) }
                        }
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .shadow(color: .black.opacity(0.02), radius: 2, y: 1)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showMonthSummary) {
            MonthSummarySheet(
                monthLabel: month.formatted(.dateTime.month(.wide).year()),
                summaries: metrics.summaries
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - MonthSummarySheet

private struct MonthSummarySheet: View {
    let monthLabel: String
    let summaries: [MonthStockSummary]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.massiveService) private var massive

    private var grandTotal: Decimal {
        summaries.reduce(.zero) { $0 + $1.totalAmount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Grand total card
                    VStack(spacing: 4) {
                        Text("Month Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(grandTotal, format: .currency(code: "USD"))
                            .font(.title2.bold())
                            .monospacedDigit()
                        Text("\(summaries.count) stock\(summaries.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                    )

                    // Per-stock breakdown
                    VStack(spacing: 0) {
                        ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                            HStack(spacing: 12) {
                                CompanyLogoView(
                                    branding: nil,
                                    ticker: summary.ticker,
                                    service: massive.service,
                                    size: 40
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.ticker)
                                        .font(.headline)
                                    Text(summary.companyName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(summary.totalAmount, format: .currency(code: "USD"))
                                        .font(.subheadline.bold())
                                        .monospacedDigit()
                                    Text("\(summary.paymentCount) payment\(summary.paymentCount == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            if index < summaries.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(monthLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - CalendarDayCell

private struct CalendarDayCell: View {
    let day: Int
    let isToday: Bool
    let events: [CalendarDividendEvent]
    let holiday: MassiveMarketHoliday?
    let onTap: () -> Void

    private var isMarketClosed: Bool {
        holiday?.status.lowercased() == "closed"
    }

    private var isEarlyClose: Bool {
        holiday?.status.lowercased() == "early-close"
    }

    private var dotColor: Color? {
        guard !events.isEmpty else { return nil }
        if events.contains(where: { $0.status == .declared })  { return .green }
        if events.contains(where: { $0.status == .estimated }) { return .orange }
        return .blue
    }

    private var dayTotal: Decimal {
        events.reduce(.zero) { $0 + $1.totalAmount }
    }

    private var compactAmountText: String? {
        guard !events.isEmpty else { return nil }
        let total = dayTotal
        if total >= 1 {
            return total.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        }
        return total.formatted(.currency(code: "USD"))
    }

    private var hasContent: Bool {
        !events.isEmpty || holiday != nil
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 30, height: 30)
                    } else if !events.isEmpty {
                        Circle()
                            .fill(dotColor?.opacity(0.1) ?? Color.clear)
                            .frame(width: 30, height: 30)
                    }
                    Text("\(day)")
                        .font(.callout.weight(isToday || !events.isEmpty ? .semibold : .regular))
                        .foregroundStyle(dayTextColor)
                }

                if let color = dotColor {
                    HStack(spacing: 2) {
                        ForEach(0..<min(events.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(color)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 5)
                } else if isMarketClosed {
                    Capsule()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 12, height: 2)
                        .frame(height: 5)
                } else {
                    Spacer().frame(height: 5)
                }

                if let amount = compactAmountText {
                    Text(amount)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(dotColor ?? .secondary)
                        .lineLimit(1)
                        .frame(height: 10)
                } else {
                    Spacer().frame(height: 10)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .disabled(!hasContent)
        .accessibilityLabel(cellAccessibilityLabel)
        .accessibilityHint(events.isEmpty ? "" : "Opens payment details")
    }

    private var dayTextColor: Color {
        if isToday { return .white }
        if isMarketClosed { return .red }
        if isEarlyClose { return .orange }
        return .primary
    }

    private var cellAccessibilityLabel: String {
        var parts: [String] = ["\(day)"]
        if !events.isEmpty {
            parts.append("\(events.count) dividend\(events.count == 1 ? "" : "s")")
            parts.append(dayTotal.formatted(.currency(code: "USD")))
        }
        if let h = holiday {
            parts.append("Market \(h.status): \(h.name)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - DividendDaySheet

private struct DividendDaySheet: View {
    let events: [CalendarDividendEvent]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.massiveService) private var massive

    private var dateTitle: String {
        events.first?.payDate.formatted(.dateTime.month(.wide).day().year()) ?? ""
    }

    private var dayTotal: Decimal {
        events.reduce(Decimal.zero) { $0 + $1.totalAmount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Day total hero
                    if events.count > 1 {
                        VStack(spacing: 4) {
                            Text("Day Total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(dayTotal, format: .currency(code: "USD"))
                                .font(.title2.bold())
                                .monospacedDigit()
                            Text("\(events.count) dividends")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.regularMaterial)
                        )
                    }

                    // Event cards
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            HStack(spacing: 12) {
                                CompanyLogoView(
                                    branding: nil,
                                    ticker: event.ticker,
                                    service: massive.service,
                                    size: 40
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(event.ticker)
                                            .font(.headline)
                                        statusBadge(event.status)
                                    }
                                    Text(event.companyName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(event.totalAmount, format: .currency(code: "USD"))
                                        .font(.headline)
                                        .monospacedDigit()
                                    Text("\(event.amountPerShare.formatted(.currency(code: "USD"))) / share")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            if index < events.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func statusBadge(_ status: DividendScheduleStatus) -> some View {
        Text(status.displayLabel)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(status.calendarDotColor.opacity(0.15))
            )
            .foregroundStyle(status.calendarDotColor)
    }
}

// MARK: - Status helpers

extension DividendScheduleStatus {
    var calendarDotColor: Color {
        switch self {
        case .estimated: return .orange
        case .declared:  return .green
        case .paid:      return .blue
        }
    }

    fileprivate var displayLabel: String {
        switch self {
        case .estimated: return "Est."
        case .declared:  return "Declared"
        case .paid:      return "Paid"
        }
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview

    let stock1 = Stock(ticker: "AAPL", companyName: "Apple Inc.", currentPrice: 185)
    let stock2 = Stock(ticker: "VYM", companyName: "Vanguard High Dividend", currentPrice: 115)
    container.mainContext.insert(stock1)
    container.mainContext.insert(stock2)

    let portfolio = Portfolio(name: "Main")
    container.mainContext.insert(portfolio)

    let holding1 = Holding(shares: 50, averageCostBasis: 150)
    holding1.stock = stock1
    holding1.portfolio = portfolio
    container.mainContext.insert(holding1)

    let holding2 = Holding(shares: 100, averageCostBasis: 100)
    holding2.stock = stock2
    holding2.portfolio = portfolio
    container.mainContext.insert(holding2)

    let cal = Calendar.current
    for offset in 0..<6 {
        let payDate = cal.date(byAdding: .month, value: offset, to: .now)!
        let s1 = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: 0.24,
            exDate: payDate,
            payDate: payDate,
            declaredDate: .now,
            status: offset == 0 ? .declared : .estimated
        )
        s1.stock = stock1
        container.mainContext.insert(s1)

        let s2 = DividendSchedule(
            frequency: .monthly,
            amountPerShare: 0.15,
            exDate: cal.date(byAdding: .day, value: 5, to: payDate)!,
            payDate: cal.date(byAdding: .day, value: 5, to: payDate)!,
            declaredDate: .now,
            status: .estimated
        )
        s2.stock = stock2
        container.mainContext.insert(s2)
    }

    return DividendCalendarView()
        .modelContainer(container)
}
