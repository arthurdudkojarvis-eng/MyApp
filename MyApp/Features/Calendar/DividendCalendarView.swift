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

    // Cached once; updated only when `schedules` changes.
    @State private var eventsByDay: [Date: [CalendarDividendEvent]] = [:]
    @State private var hasEvents = false
    @State private var holidays: [Date: MassiveMarketHoliday] = [:]

    @State private var selectedDayEvents: [CalendarDividendEvent] = []
    @State private var showDetail = false
    @State private var hasScrolled = false

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
        .navigationTitle("Calendar")
        .sheet(isPresented: $showDetail) {
            DividendDaySheet(events: selectedDayEvents)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { rebuildEvents() }
        .onChange(of: schedules) { rebuildEvents() }
        .task { await loadHolidays() }
    }

    private var calendarScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(Self.months, id: \.timeIntervalSinceReferenceDate) { month in
                        MonthGridView(month: month, eventsByDay: eventsByDay, holidays: holidays) { dayEvents in
                            selectedDayEvents = dayEvents
                            showDetail = true
                        }
                        .id(monthKey(for: month))
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .task {
                guard !hasScrolled else { return }
                hasScrolled = true
                proxy.scrollTo(monthKey(for: .now), anchor: .top)
            }
        }
    }

    // MARK: - Event cache

    private func rebuildEvents() {
        let cal = Calendar.current
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
            let key = cal.startOfDay(for: schedule.payDate)
            byDay[key, default: []].append(event)
        }
        eventsByDay = byDay
        hasEvents = !byDay.isEmpty
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
        do {
            let results = try await massive.service.fetchMarketHolidays()
            var byDay: [Date: MassiveMarketHoliday] = [:]
            for holiday in results {
                if let date = formatter.date(from: holiday.date) {
                    let key = Calendar.current.startOfDay(for: date)
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

// MARK: - MonthGridView

private struct MonthGridView: View {
    let month: Date
    let eventsByDay: [Date: [CalendarDividendEvent]]
    let holidays: [Date: MassiveMarketHoliday]
    let onDayTap: ([CalendarDividendEvent]) -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    /// Returns an array of optional Dates for the month grid.
    /// Leading `nil`s fill empty weekday slots before the 1st, respecting the locale's first weekday.
    private var dayGrid: [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }
        // Locale-aware: (rawWeekday - firstWeekday + 7) % 7
        let firstWeekday = cal.firstWeekday                                  // e.g. 1=Sun, 2=Mon
        let rawWeekday   = cal.component(.weekday, from: firstOfMonth)       // 1-based, absolute
        let leadingNilCount = (rawWeekday - firstWeekday + 7) % 7
        let days: [Date?] = range.map { dayNumber in
            cal.date(byAdding: .day, value: dayNumber - 1, to: firstOfMonth)
        }
        return Array(repeating: Date?.none, count: leadingNilCount) + days
    }

    private var daySymbols: [String] {
        Calendar.current.veryShortWeekdaySymbols
    }

    var body: some View {
        let cal = Calendar.current
        VStack(alignment: .leading, spacing: 6) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .padding(.horizontal, 20)

            // Day-of-week header row — locale-ordered
            LazyVGrid(columns: Self.columns, spacing: 0) {
                ForEach(daySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                }
            }
            .padding(.horizontal, 8)

            // Day cells
            let grid = dayGrid
            LazyVGrid(columns: Self.columns, spacing: 0) {
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
                        Color.clear.frame(height: 46)
                    }
                }
            }
            .padding(.horizontal, 8)
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

    /// Dominant dot color: declared beats estimated; blue only when all are paid.
    private var dotColor: Color? {
        guard !events.isEmpty else { return nil }
        if events.contains(where: { $0.status == .declared })  { return .green }
        if events.contains(where: { $0.status == .estimated }) { return .orange }
        if events.allSatisfy({ $0.status == .paid })           { return .blue }
        return .green // mixed declared/paid → declared wins
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 28, height: 28)
                    }
                    Text("\(day)")
                        .font(.callout)
                        .foregroundStyle(
                            isToday ? .white :
                            isMarketClosed ? .red :
                            isEarlyClose ? .orange : .primary
                        )
                }
                if let color = dotColor {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                } else if isMarketClosed {
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 12, height: 2)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
        }
        .buttonStyle(.plain)
        .disabled(events.isEmpty && holiday == nil)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(events.isEmpty ? "" : "Opens payment details")
    }

    private var accessibilityLabel: String {
        var parts: [String] = ["\(day)"]
        if !events.isEmpty {
            parts.append("\(events.count) dividend\(events.count == 1 ? "" : "s")")
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

    private var dateTitle: String {
        events.first?.payDate.formatted(.dateTime.month(.wide).day().year()) ?? ""
    }

    private var dayTotal: Decimal {
        events.reduce(Decimal.zero) { $0 + $1.totalAmount }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(events) { event in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(event.status.calendarDotColor)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.ticker)
                                    .font(.headline)
                                Text(event.companyName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(event.totalAmount, format: .currency(code: "USD"))
                                    .font(.headline)
                                Text(
                                    "\(event.amountPerShare.formatted(.currency(code: "USD"))) / share"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if events.count > 1 {
                    Section {
                        HStack {
                            Text("Total")
                                .font(.subheadline.bold())
                            Spacer()
                            Text(dayTotal, format: .currency(code: "USD"))
                                .font(.subheadline.bold())
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Status dot color

extension DividendScheduleStatus {
    var calendarDotColor: Color {
        switch self {
        case .estimated: return .orange
        case .declared:  return .green
        case .paid:      return .blue
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
