import SwiftUI
import SwiftData
import Charts

// MARK: - IncomeHeroView

struct IncomeHeroView: View {
    let metrics: DashboardMetrics
    let isRefreshing: Bool

    @Environment(\.massiveService) private var massive

    @State private var chartData: [PortfolioValuePoint] = []
    @State private var isLoadingChart = false
    @State private var selectedPage = 0
    @State private var selectedMonth: String?
    @State private var hideAmounts = false
    @State private var chartRange: ChartRange = .oneMonth
    @State private var dripEnabled = false
    @State private var projectionYears = 5
    @State private var scrubPoint: PortfolioValuePoint?
    @State private var showPulse = false
    @State private var showProjectionInfo = false
    @State private var showFlowView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top headline — changes based on selected page
            heroHeadline

            // Chart area — switch with swipe or dot tap
            Group {
                if selectedPage == 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        portfolioChartOnly
                        chartRangePicker
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
                } else if selectedPage == 1 {
                    VStack(alignment: .leading, spacing: 0) {
                        monthlyDividendChartOnly
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        futureValueChartOnly
                        projectionYearPicker
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                }
            }
            .frame(height: 280)
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { drag in
                        let horizontal = drag.translation.width
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if horizontal < -30 && selectedPage < 2 {
                                selectedPage += 1
                                if selectedPage != 1 { selectedMonth = nil }
                                if selectedPage != 2 { showProjectionInfo = false }
                            } else if horizontal > 30 && selectedPage > 0 {
                                selectedPage -= 1
                                selectedMonth = nil
                                showProjectionInfo = false
                            }
                        }
                    }
            )

            // Custom page dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(selectedPage == index ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedPage = index
                                if index != 1 { selectedMonth = nil }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
        .fullScreenCover(isPresented: $showFlowView) {
            PortfolioFlowView(
                portfolios: metrics.portfolios,
                totalValue: metrics.totalMarketValue
            )
        }
        .task(id: "\(holdingTickers)|\(chartRange.rawValue)") {
            await loadChart()
        }
    }

    /// Stable identifier for triggering chart reload when holdings change.
    private var holdingTickers: String {
        Set(metrics.allHoldings.compactMap { $0.stock?.ticker }).sorted().joined(separator: ",")
    }

    // MARK: - Hero Headline (above TabView)

    @ViewBuilder
    private var heroHeadline: some View {
        if selectedPage == 0 {
            // Portfolio value — shows scrubbed point when dragging
            let displayValue = scrubPoint?.value ?? metrics.totalMarketValue

            HStack(spacing: 8) {
                amountText(displayValue)
                eyeButton
                Spacer()
                if metrics.allHoldings.count > 1 {
                    flowExpandButton
                }
            }

            if chartData.count >= 2 {
                let baseValue = chartData.first!.value
                let compareValue = scrubPoint?.value ?? chartData.last!.value
                let change = compareValue - baseValue
                let changePercent = baseValue > 0 ? (change / baseValue) * 100 : Decimal.zero
                let isPositive = change >= 0

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.bold())
                    if hideAmounts {
                        Text("****")
                            .textStyle(.captionBold)
                    } else {
                        Text("\(isPositive ? "+" : "")\(String(format: "%.2f", NSDecimalNumber(decimal: change).doubleValue))")
                            .textStyle(.captionBold)
                            .monospacedDigit()
                        Text("(\(String(format: "%.2f", NSDecimalNumber(decimal: changePercent).doubleValue))%)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    if let scrub = scrubPoint {
                        Text(scrub.date.formatted(.dateTime.month(.abbreviated).day()))
                            .textStyle(.statLabel)
                    } else {
                        Text(chartRange.label)
                            .textStyle(.statLabel)
                    }
                }
                .foregroundStyle(isPositive ? .green : .red)
            }
        } else if selectedPage == 1 {
            // Avg monthly dividend or selected month
            let data = monthlyDividendData
            let total = data.reduce(Decimal.zero) { $0 + $1.amount }
            let avg = data.isEmpty ? Decimal.zero : total / Decimal(data.count)

            if let selected = selectedMonth,
               let point = data.first(where: { $0.label == selected }) {
                HStack(spacing: 8) {
                    amountText(point.amount)
                    eyeButton
                }

                HStack(spacing: 6) {
                    Text(selected)
                        .textStyle(.rowDetail)

                    if !point.tickers.isEmpty {
                        HStack(spacing: -4) {
                            ForEach(Array(point.tickers.prefix(6).enumerated()), id: \.element) { index, ticker in
                                CompanyLogoView(
                                    branding: nil,
                                    ticker: ticker,
                                    service: massive.service,
                                    size: 20
                                )
                                .zIndex(Double(6 - index))
                            }
                            if point.tickers.count > 6 {
                                Text("+\(point.tickers.count - 6)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .zIndex(0)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    amountText(avg)
                    eyeButton
                }

                HStack {
                    Text("Avg Monthly Dividend")
                        .textStyle(.rowDetail)
                }
            }
        } else {
            // Future portfolio value projection (page 3)
            let projections = futureValueProjections
            let finalValue = projections.last?.value ?? metrics.totalMarketValue

            HStack(spacing: 8) {
                amountText(finalValue)
                eyeButton
                infoButton
                Spacer()
                dripToggleButton
            }

            HStack(spacing: 4) {
                Text("\(projectionYears)-Year Projection")
                    .textStyle(.rowDetail)
                if dripEnabled {
                    Text("DRIP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                if !hideAmounts {
                    let growth = metrics.totalMarketValue > 0
                        ? ((finalValue - metrics.totalMarketValue) / metrics.totalMarketValue) * 100
                        : Decimal.zero
                    let growthDouble = NSDecimalNumber(decimal: growth).doubleValue
                    Text("\(growthDouble >= 0 ? "+" : "")\(growthDouble, specifier: "%.1f")%")
                        .textStyle(.captionBold)
                        .foregroundStyle(growthDouble >= 0 ? .green : .red)
                }
            }
        }
    }

    // MARK: - Portfolio Value Chart (chart only)

    @ViewBuilder
    private var portfolioChartOnly: some View {
        if isLoadingChart && chartData.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            }
            .frame(height: 250)
        } else if chartData.count >= 2 {
            let isPositive = chartData.last!.value >= chartData.first!.value
            let trendColor: Color = isPositive ? .green : .red

            Chart {
                ForEach(chartData) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.doubleValue)
                    )
                    .foregroundStyle(trendColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
                }

                // Crosshair when scrubbing
                if let scrub = scrubPoint {
                    RuleMark(x: .value("Date", scrub.date))
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("Date", scrub.date),
                        y: .value("Value", scrub.doubleValue)
                    )
                    .symbolSize(40)
                    .foregroundStyle(trendColor)
                }
            }
            .chartYScale(domain: {
                let values = chartData.map { $0.doubleValue }
                let lo = values.min() ?? 0
                let hi = values.max() ?? 1
                let padding = max((hi - lo) * 0.3, hi * 0.01)
                return (lo - padding)...(hi + padding)
            }())
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            LongPressGesture(minimumDuration: 0.2)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
                                    switch value {
                                    case .second(true, let drag):
                                        guard let drag else { return }
                                        let x = drag.location.x - geo[proxy.plotAreaFrame].origin.x
                                        guard let date: Date = proxy.value(atX: x) else { return }
                                        let nearest = chartData.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                        scrubPoint = nearest
                                    default:
                                        break
                                    }
                                }
                                .onEnded { _ in
                                    scrubPoint = nil
                                }
                        )
                }
            }
            .frame(height: 250)
        }
    }

    // MARK: - Chart Range Picker

    private var chartRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(ChartRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        chartRange = range
                    }
                } label: {
                    Text(range.label)
                        .font(.system(size: 10, weight: chartRange == range ? .bold : .medium))
                        .foregroundStyle(chartRange == range ? Color.accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            chartRange == range
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func amountText(_ value: Decimal) -> some View {
        if hideAmounts {
            Text("****")
                .textStyle(.cardHero)
                .foregroundStyle(.primary)
        } else {
            Text(value, format: .currency(code: "USD"))
                .textStyle(.cardHero)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private var eyeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                hideAmounts.toggle()
            }
        } label: {
            Image(systemName: hideAmounts ? "eye.slash" : "eye")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var flowExpandButton: some View {
        Button {
            showFlowView = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var infoButton: some View {
        Button {
            showProjectionInfo.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showProjectionInfo) {
            VStack(alignment: .leading, spacing: 10) {
                Text("How it's calculated")
                    .font(.subheadline.bold())
                Text("Projection assumes 7% annual growth based on historical market average.")
                    .textStyle(.rowDetail)
                Text("**DRIP OFF** — Price appreciation only. Dividends taken as cash.")
                    .textStyle(.rowDetail)
                Text("**DRIP ON** — Dividends are reinvested monthly at your current portfolio yield, compounding over time.")
                    .textStyle(.rowDetail)
                Text("Actual results will vary with market conditions and dividend changes.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(width: 280)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var dripToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                dripEnabled.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                Text("DRIP")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(dripEnabled ? .white : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(dripEnabled ? Color.accentColor : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private static let projectionYearOptions = [1, 5, 10, 15, 20, 25, 30]

    private var projectionYearPicker: some View {
        HStack(spacing: 0) {
            ForEach(Self.projectionYearOptions, id: \.self) { years in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        projectionYears = years
                    }
                } label: {
                    Text("\(years)Y")
                        .font(.system(size: 11, weight: projectionYears == years ? .bold : .medium))
                        .foregroundStyle(projectionYears == years ? Color.accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            projectionYears == years
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Future Value Projections (Page 3)

    private var futureValueProjections: [FutureValuePoint] {
        let portfolioValue = NSDecimalNumber(decimal: metrics.totalMarketValue).doubleValue
        guard portfolioValue > 0 else { return [] }

        let annualIncome = NSDecimalNumber(decimal: metrics.allHoldings.reduce(Decimal.zero) {
            $0 + $1.projectedAnnualIncome
        }).doubleValue
        let yield = portfolioValue > 0 ? annualIncome / portfolioValue : 0
        let growthRate = 0.07 // 7% annual market average

        var points: [FutureValuePoint] = []
        var value = portfolioValue

        let totalMonths = projectionYears * 12
        let monthlyGrowth = pow(1 + growthRate, 1.0 / 12.0) - 1
        let monthlyYield = yield / 12.0

        for month in 0...totalMonths {
            let decimal = Decimal(floatLiteral: value)
            points.append(FutureValuePoint(month: month, value: decimal))

            let dividend = value * monthlyYield
            value *= (1 + monthlyGrowth)

            if dripEnabled {
                value += dividend
            }
        }

        return points
    }

    @ViewBuilder
    private var futureValueChartOnly: some View {
        let data = futureValueProjections
        if data.count >= 2 {
            Chart(data) { point in
                LineMark(
                    x: .value("Month", point.month),
                    y: .value("Value", point.doubleValue)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Month", point.month),
                    y: .value("Value", point.doubleValue)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.25),
                            Color.accentColor.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 250)
        }
    }

    // MARK: - Monthly Dividend Chart (Page 2)

    private var monthlyDividendData: [MonthlyDividendPoint] {
        let calendar = Calendar.current
        let now = Date.now

        // For each holding, project payments across the next 12 months
        // based on dividend schedule frequency and pay date anchor month
        var byMonthIndex: [Int: Decimal] = [:]  // 0 = current month, 11 = 11 months ahead
        var tickersByMonth: [Int: Set<String>] = [:]

        for holding in metrics.allHoldings {
            guard let stock = holding.stock else { continue }
            for schedule in stock.dividendSchedules {
                let paymentPerOccurrence = schedule.amountPerShare * holding.shares
                let anchorMonth = calendar.component(.month, from: schedule.payDate)
                let currentMonth = calendar.component(.month, from: now)

                switch schedule.frequency {
                case .monthly:
                    for i in 0..<12 {
                        byMonthIndex[i, default: 0] += paymentPerOccurrence
                        tickersByMonth[i, default: []].insert(stock.ticker)
                    }
                case .quarterly:
                    for i in 0..<12 {
                        let targetMonth = (currentMonth + i - 1) % 12 + 1
                        if (targetMonth - anchorMonth + 12) % 3 == 0 {
                            byMonthIndex[i, default: 0] += paymentPerOccurrence
                            tickersByMonth[i, default: []].insert(stock.ticker)
                        }
                    }
                case .semiAnnual:
                    for i in 0..<12 {
                        let targetMonth = (currentMonth + i - 1) % 12 + 1
                        if (targetMonth - anchorMonth + 12) % 6 == 0 {
                            byMonthIndex[i, default: 0] += paymentPerOccurrence
                            tickersByMonth[i, default: []].insert(stock.ticker)
                        }
                    }
                case .annual:
                    for i in 0..<12 {
                        let targetMonth = (currentMonth + i - 1) % 12 + 1
                        if targetMonth == anchorMonth {
                            byMonthIndex[i, default: 0] += paymentPerOccurrence
                            tickersByMonth[i, default: []].insert(stock.ticker)
                        }
                    }
                }
            }
        }

        return (0..<12).map { offset in
            let date = calendar.date(byAdding: .month, value: offset, to: now) ?? now
            let amount = byMonthIndex[offset] ?? 0
            let tickers = tickersByMonth[offset]?.sorted() ?? []
            return MonthlyDividendPoint(
                label: date.formatted(.dateTime.month(.abbreviated)),
                amount: amount,
                offset: offset,
                tickers: tickers
            )
        }
    }

    @ViewBuilder
    private var monthlyDividendChartOnly: some View {
        let data = monthlyDividendData
        let total = data.reduce(Decimal.zero) { $0 + $1.amount }
        let avg = data.isEmpty ? Decimal.zero : total / Decimal(data.count)
        let avgDouble = NSDecimalNumber(decimal: avg).doubleValue

        Chart {
            ForEach(data) { point in
                BarMark(
                    x: .value("Month", point.label),
                    y: .value("Income", point.doubleAmount)
                )
                .foregroundStyle(
                    selectedMonth == nil
                        ? Color.accentColor.opacity(0.7).gradient
                        : (selectedMonth == point.label
                            ? Color.accentColor.gradient
                            : Color.accentColor.opacity(0.25).gradient)
                )
                .cornerRadius(3)
            }

            RuleMark(y: .value("Average", avgDouble))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let x = location.x - geo[proxy.plotAreaFrame].origin.x
                        if let label: String = proxy.value(atX: x) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedMonth = selectedMonth == label ? nil : label
                            }
                        }
                    }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.system(size: 8))
                            .fontWeight(selectedMonth == label ? .bold : .regular)
                            .foregroundStyle(selectedMonth == label ? Color.accentColor : .white)
                    }
                }
            }
        }
        .frame(height: 250)
    }

    // MARK: - Chart Data Loading

    @MainActor
    private func loadChart() async {
        let holdings = metrics.allHoldings
        guard !holdings.isEmpty else {
            chartData = []
            return
        }

        // Build shares-by-ticker map
        var sharesByTicker: [String: Decimal] = [:]
        for holding in holdings {
            guard let ticker = holding.stock?.ticker else { continue }
            sharesByTicker[ticker, default: 0] += holding.shares
        }
        guard !sharesByTicker.isEmpty else { return }

        isLoadingChart = true
        defer { isLoadingChart = false }

        let range = chartRange.dateRange
        let fromStr = range.from
        let toStr = range.to

        // Fetch aggregates for each ticker concurrently
        var aggsByTicker: [String: [MassiveAggregate]] = [:]
        await withTaskGroup(of: (String, [MassiveAggregate]).self) { group in
            for ticker in sharesByTicker.keys {
                group.addTask {
                    let aggs = (try? await massive.service.fetchAggregates(
                        ticker: ticker, from: fromStr, to: toStr
                    )) ?? []
                    return (ticker, aggs)
                }
            }
            for await (ticker, aggs) in group {
                aggsByTicker[ticker] = aggs
            }
        }

        // Collect all unique dates
        var allTimestamps = Set<Int>()
        for aggs in aggsByTicker.values {
            for agg in aggs {
                allTimestamps.insert(agg.t)
            }
        }

        guard !allTimestamps.isEmpty else {
            chartData = []
            return
        }

        // Build lookup: ticker -> timestamp -> close price
        var priceLookup: [String: [Int: Decimal]] = [:]
        for (ticker, aggs) in aggsByTicker {
            var map: [Int: Decimal] = [:]
            for agg in aggs {
                map[agg.t] = agg.c
            }
            priceLookup[ticker] = map
        }

        // For each date, compute total portfolio value
        let sortedTimestamps = allTimestamps.sorted()
        var lastKnownPrice: [String: Decimal] = [:]
        var points: [PortfolioValuePoint] = []

        for ts in sortedTimestamps {
            var totalValue = Decimal.zero
            for (ticker, shares) in sharesByTicker {
                if let price = priceLookup[ticker]?[ts] {
                    lastKnownPrice[ticker] = price
                    totalValue += price * shares
                } else if let last = lastKnownPrice[ticker] {
                    totalValue += last * shares
                }
                // If no price at all yet for this ticker, it contributes 0
            }
            let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
            points.append(PortfolioValuePoint(date: date, value: totalValue))
        }

        chartData = points
    }
}

// MARK: - Chart Data Model

private struct PortfolioValuePoint: Identifiable {
    let date: Date
    let value: Decimal

    var id: Date { date }
    var doubleValue: Double { NSDecimalNumber(decimal: value).doubleValue }
}

private struct FutureValuePoint: Identifiable {
    let month: Int
    let value: Decimal

    var id: Int { month }
    var doubleValue: Double { NSDecimalNumber(decimal: value).doubleValue }
}

private struct MonthlyDividendPoint: Identifiable {
    let label: String
    let amount: Decimal
    let offset: Int
    let tickers: [String]

    var id: Int { offset }
    var doubleAmount: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

// MARK: - Previews

#Preview("With data") {
    let container = ModelContainer.preview

    let portfolio = Portfolio(name: "Main")
    container.mainContext.insert(portfolio)

    let stock = Stock(ticker: "AAPL", companyName: "Apple Inc.", currentPrice: 185)
    container.mainContext.insert(stock)

    let schedule = DividendSchedule(
        frequency: .quarterly, amountPerShare: Decimal(string: "0.25")!,
        exDate: .now, payDate: .now, declaredDate: .now, status: .declared
    )
    schedule.stock = stock
    container.mainContext.insert(schedule)

    let holding = Holding(shares: 100, averageCostBasis: 150)
    holding.stock = stock
    holding.portfolio = portfolio
    container.mainContext.insert(holding)

    return IncomeHeroView(
        metrics: DashboardMetrics(portfolios: [portfolio]),
        isRefreshing: false
    )
    .modelContainer(container)
}

#Preview("Refreshing") {
    IncomeHeroView(
        metrics: DashboardMetrics(portfolios: []),
        isRefreshing: true
    )
}

#Preview("Empty") {
    IncomeHeroView(
        metrics: DashboardMetrics(portfolios: []),
        isRefreshing: false
    )
}
