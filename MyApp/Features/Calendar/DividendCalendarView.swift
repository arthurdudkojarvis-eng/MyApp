import SwiftUI
import SwiftData

// MARK: - CalendarGroup

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
        let label = sorted[0].payDate.formatted(.dateTime.month(.wide).year())
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

// MARK: - DividendCalendarView

struct DividendCalendarView: View {
    @Query(sort: \DividendSchedule.payDate, order: .forward)
    private var schedules: [DividendSchedule]

    private var groups: [CalendarGroup] {
        calendarGroups(from: schedules)
    }

    private var scrollTarget: Int? {
        scrollTargetKey(from: groups.map(\.key))
    }

    var body: some View {
        NavigationStack {
            Group {
                if schedules.isEmpty {
                    ContentUnavailableView(
                        "No Dividend Events",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text(
                            "Add holdings with dividend schedules to see upcoming payments."
                        )
                    )
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(groups, id: \.key) { group in
                                Section {
                                    // Anchor id on the first row — Section ids are unreliable
                                    // scroll targets in List on iOS 17.
                                    DividendCalendarRowView(schedule: group.schedules[0])
                                        .id(group.key)
                                    ForEach(group.schedules.dropFirst()) { schedule in
                                        DividendCalendarRowView(schedule: schedule)
                                    }
                                } header: {
                                    Text(group.monthLabel)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .onAppear {
                            guard let target = scrollTarget else { return }
                            // Defer until the list has completed its first layout pass.
                            DispatchQueue.main.async {
                                proxy.scrollTo(target, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
        }
    }
}

// MARK: - Preview

#Preview {
    let container = ModelContainer.preview

    let stock = Stock(ticker: "AAPL", companyName: "Apple Inc.", currentPrice: 185)
    container.mainContext.insert(stock)

    let stock2 = Stock(ticker: "VYM", companyName: "Vanguard High Dividend", currentPrice: 115)
    container.mainContext.insert(stock2)

    // Schedules spanning two months
    for monthOffset in 0...3 {
        let payDate = Calendar.current.date(byAdding: .month, value: monthOffset, to: .now)!
        let s = DividendSchedule(
            frequency: .quarterly,
            amountPerShare: Decimal(string: "0.25")!,
            exDate: payDate,
            payDate: payDate,
            declaredDate: .now,
            status: monthOffset == 0 ? .declared : .estimated
        )
        s.stock = monthOffset.isMultiple(of: 2) ? stock : stock2
        container.mainContext.insert(s)
    }

    return DividendCalendarView()
        .modelContainer(container)
}
