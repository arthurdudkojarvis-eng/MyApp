import SwiftUI
import SwiftData

// MARK: - Screen Result

struct ScreenResult: Identifiable {
    let ticker: String
    let companyName: String
    let pe: Double?
    let debtEquity: Double?
    let epsGrowth: Double?
    let marketCapB: Double?
    let passesAll: Bool
    let passCount: Int

    var id: String { ticker }
}

// MARK: - Screener Preset

enum ScreenerPreset: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case peterLynch = "Peter Lynch"
    case warrenBuffett = "Warren Buffett"
    case charlieMunger = "Charlie Munger"
    case benjaminGraham = "Benjamin Graham"
    case philipFisher = "Philip Fisher"
    case joelGreenblatt = "Joel Greenblatt"
    case johnNeff = "John Neff"
    case davidDreman = "David Dreman"
    case johnTempleton = "John Templeton"
    case rayDalio = "Ray Dalio"
    case jimSimons = "Jim Simons"

    var id: String { rawValue }

    /// Returns (maxPE, maxDE%, minEPSGrowth%, minMarketCapB) or nil for manual.
    var criteria: (maxPE: Double, maxDE: Double, minEPS: Double, minCap: Double)? {
        switch self {
        case .manual:         return nil
        case .peterLynch:     return (25, 35, 25, 1)
        case .warrenBuffett:  return (15, 50, 10, 10)
        case .charlieMunger:  return (20, 30, 15, 10)
        case .benjaminGraham: return (15, 30, 5, 5)
        case .philipFisher:   return (35, 40, 20, 3)
        case .joelGreenblatt: return (15, 50, 15, 1)
        case .johnNeff:       return (12, 50, 10, 5)
        case .davidDreman:    return (10, 40, 5, 5)
        case .johnTempleton:  return (20, 40, 10, 1)
        case .rayDalio:       return (20, 40, 10, 10)
        case .jimSimons:      return (40, 60, 5, 1)
        }
    }

    var description: String {
        switch self {
        case .manual:         return ""
        case .peterLynch:     return "Growth at a reasonable price; focuses on PEG ratio < 1."
        case .warrenBuffett:  return "Durable moats, low debt, large-cap compounders."
        case .charlieMunger:  return "Quality compounders at fair prices; few concentrated bets."
        case .benjaminGraham: return "Deep value with margin of safety and stable earnings."
        case .philipFisher:   return "High-quality growth companies; willing to pay a premium."
        case .joelGreenblatt: return "Magic Formula — low P/E combined with quality earnings."
        case .johnNeff:       return "Contrarian low P/E with a total-return focus."
        case .davidDreman:    return "Deep contrarian — buy what others avoid."
        case .johnTempleton:  return "Global bargain hunter; buys at the point of maximum pessimism."
        case .rayDalio:       return "Risk-parity macro approach; balanced, large-cap, all-weather."
        case .jimSimons:      return "Quant-driven; wide filters, lets the math find the edge."
        }
    }

    var strategyDetail: String {
        switch self {
        case .manual:
            return "Set your own screening criteria using the sliders below."
        case .peterLynch:
            return "Legendary Fidelity Magellan manager. Coined 'invest in what you know.' Hunts for undervalued growth stocks with a PEG ratio below 1 — earnings growth should exceed the P/E ratio. Prefers low debt and strong earnings momentum."
        case .warrenBuffett:
            return "The Oracle of Omaha. Seeks businesses with durable competitive advantages ('moats'), consistent earnings, and shareholder-friendly management. Favors large, predictable companies trading below intrinsic value with conservative balance sheets."
        case .charlieMunger:
            return "Buffett's longtime partner at Berkshire. Advocates paying a fair price for wonderful businesses rather than a wonderful price for fair businesses. Concentrates in a few high-conviction positions with low debt and strong returns on capital."
        case .benjaminGraham:
            return "The father of value investing and Buffett's mentor. Demands a wide margin of safety — stocks priced well below intrinsic value. Focuses on low P/E, low debt, and stable earnings over multiple years. Conservative and disciplined."
        case .philipFisher:
            return "Pioneer of growth investing. Willing to pay up for companies with outstanding management, strong R&D, and above-average profit margins. Holds for the long term and emphasizes qualitative 'scuttlebutt' research alongside the numbers."
        case .joelGreenblatt:
            return "Columbia professor who developed the Magic Formula: rank stocks by combining high earnings yield (low P/E) with high return on capital. Systematically buys cheap, high-quality businesses and rotates annually."
        case .johnNeff:
            return "Managed Vanguard Windsor for 31 years. A contrarian who bought unloved, low-P/E stocks with decent dividends. Focused on total return (earnings growth + dividend yield) relative to P/E — a value approach with income."
        case .davidDreman:
            return "Behavioral-finance contrarian. Buys stocks that the market has punished — low P/E, low price-to-book, low price-to-cash-flow. Bets that investor overreaction creates opportunity in fundamentally sound companies."
        case .johnTempleton:
            return "Pioneer of global investing. Searched worldwide for stocks trading at bargain prices, often in markets experiencing crises. Famous for buying at 'the point of maximum pessimism' and holding through recovery."
        case .rayDalio:
            return "Founder of Bridgewater, the world's largest hedge fund. Created the All Weather portfolio for balanced risk across asset classes. Prefers large, stable companies with moderate valuations and manageable leverage."
        case .jimSimons:
            return "Mathematician who founded Renaissance Technologies. Uses quantitative models and statistical arbitrage — not traditional fundamental analysis. Wide screening criteria reflect a data-driven approach that finds edges across the entire market."
        }
    }
}

// MARK: - Screener Source

enum ScreenerSource: String, CaseIterable {
    case myStocks = "My Stocks"
    case bySector = "By Sector"
}

// MARK: - StockScreenerView

struct StockScreenerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.massiveService) private var massive
    @Environment(SettingsStore.self) private var settings
    @Query private var portfolios: [Portfolio]
    @Query private var watchlistItems: [WatchlistItem]

    @State private var source: ScreenerSource = .myStocks
    @State private var selectedSector: String?
    @State private var selectedPreset: ScreenerPreset = .manual
    @State private var showingPresetInfo = false

    @State private var maxPE: Double = 25
    @State private var maxDebtEquity: Double = 35
    @State private var minEPSGrowth: Double = 15
    @State private var minMarketCapB: Double = 5

    @State private var isScreening = false
    @State private var screenResults: [ScreenResult] = []
    @State private var screenError: String?
    @State private var screenedCount = 0

    private var tint: Color { settings.fontTheme.color ?? Color.accentColor }

    private let sectorChips: [String] = [
        "Technology", "Healthcare", "Finance", "Energy",
        "Consumer Cyclical", "Industrials", "Real Estate",
        "Utilities", "Communication", "Materials"
    ]

    private let sectorKeywords: [String: [String]] = [
        "Technology": ["tech", "software"],
        "Healthcare": ["health", "pharma"],
        "Finance": ["bank", "financial"],
        "Energy": ["energy", "oil"],
        "Consumer Cyclical": ["consumer", "retail"],
        "Industrials": ["industrial", "manufacturing"],
        "Real Estate": ["realty", "property"],
        "Utilities": ["utility", "electric"],
        "Communication": ["communication", "media"],
        "Materials": ["materials", "chemical"]
    ]

    private var uniqueTickers: [String] {
        var seen = Set<String>()
        var tickers: [String] = []
        for portfolio in portfolios {
            for holding in portfolio.holdings {
                if let ticker = holding.stock?.ticker, seen.insert(ticker).inserted {
                    tickers.append(ticker)
                }
            }
        }
        for item in watchlistItems {
            if seen.insert(item.ticker).inserted {
                tickers.append(item.ticker)
            }
        }
        return tickers
    }

    private func sectorIcon(_ sector: String) -> String {
        switch sector {
        case "Technology": return "desktopcomputer"
        case "Healthcare": return "heart.text.square"
        case "Finance": return "building.columns"
        case "Energy": return "bolt.fill"
        case "Consumer Cyclical": return "cart.fill"
        case "Industrials": return "gearshape.2.fill"
        case "Real Estate": return "house.fill"
        case "Utilities": return "lightbulb.fill"
        case "Communication": return "antenna.radiowaves.left.and.right"
        case "Materials": return "cube.fill"
        default: return "circle.fill"
        }
    }

    private func investorColor(_ preset: ScreenerPreset) -> Color {
        switch preset {
        case .manual: return .gray
        case .peterLynch: return .green
        case .warrenBuffett: return .blue
        case .charlieMunger: return .purple
        case .benjaminGraham: return .brown
        case .philipFisher: return .orange
        case .joelGreenblatt: return .red
        case .johnNeff: return .teal
        case .davidDreman: return .indigo
        case .johnTempleton: return .mint
        case .rayDalio: return .cyan
        case .jimSimons: return .pink
        }
    }

    var body: some View {
        NavigationStack {
            List {
                sourceSection
                criteriaSection
                screenButtonSection

                if isScreening {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView {
                                Text(source == .myStocks
                                     ? "Screening \(uniqueTickers.count) stocks..."
                                     : "Searching & screening \(selectedSector ?? "sector")...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                } else if let error = screenError {
                    Section {
                        ContentUnavailableView(
                            "Screening Failed",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                    }
                } else if !screenResults.isEmpty {
                    resultsSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Stock Screener")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.spring(duration: 0.35), value: selectedPreset)
            .animation(.spring(duration: 0.35), value: selectedSector)
            .animation(.spring(duration: 0.35), value: source)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Source

    private var sourceSection: some View {
        Section {
            Picker("Source", selection: $source) {
                ForEach(ScreenerSource.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)

            if source == .bySector {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sectorChips, id: \.self) { sector in
                            let isSelected = selectedSector == sector
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    selectedSector = isSelected ? nil : sector
                                }
                            } label: {
                                Label(sector, systemImage: sectorIcon(sector))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Group {
                                            if isSelected {
                                                LinearGradient(
                                                    colors: [tint, tint.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            } else {
                                                tint.opacity(0.08)
                                            }
                                        }
                                    )
                                    .foregroundStyle(isSelected ? .white : tint)
                                    .clipShape(Capsule())
                                    .shadow(color: isSelected ? tint.opacity(0.4) : .clear, radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Label("Stock Source", systemImage: "tray.full.fill")
                .font(.caption.bold())
                .foregroundStyle(tint)
        }
    }

    // MARK: - Criteria

    private var criteriaSection: some View {
        Section {
            // Strategy preset cards
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Strategy")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button {
                        showingPresetInfo = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(tint.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ScreenerPreset.allCases) { preset in
                            let isSelected = selectedPreset == preset
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    selectedPreset = preset
                                    applyPreset(preset)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Text(preset.rawValue)
                                            .font(.caption.bold())
                                            .lineLimit(1)
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    if preset != .manual, !preset.description.isEmpty {
                                        Text(preset.description)
                                            .font(.system(size: 9))
                                            .lineLimit(2)
                                            .opacity(0.85)
                                    }
                                    if let c = preset.criteria {
                                        HStack(spacing: 4) {
                                            Text("P/E \(String(format: "%.0f", c.maxPE))")
                                            Text("D/E \(String(format: "%.0f", c.maxDE))%")
                                        }
                                        .font(.system(size: 8).monospacedDigit())
                                        .opacity(0.7)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(width: 140)
                                .foregroundStyle(isSelected ? .white : .primary)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            isSelected
                                                ? AnyShapeStyle(LinearGradient(
                                                    colors: [tint, tint.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                  ))
                                                : AnyShapeStyle(.ultraThinMaterial)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(isSelected ? tint : Color.clear, lineWidth: 1.5)
                                )
                                .shadow(color: isSelected ? tint.opacity(0.3) : .clear, radius: 8, y: 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .sheet(isPresented: $showingPresetInfo) {
                presetInfoSheet
            }

            criteriaRow(
                label: "Max P/E Ratio",
                icon: "number",
                value: maxPE,
                format: "%.0f",
                range: 5...50,
                step: 1,
                rangeLow: "Value", rangeHigh: "Growth"
            ) { maxPE = $0; selectedPreset = .manual }

            criteriaRow(
                label: "Max Debt/Equity",
                icon: "chart.bar.doc.horizontal",
                value: maxDebtEquity,
                format: "%.0f%%",
                range: 0...100,
                step: 5,
                rangeLow: "Conservative", rangeHigh: "Aggressive"
            ) { maxDebtEquity = $0; selectedPreset = .manual }

            criteriaRow(
                label: "Min EPS Growth",
                icon: "arrow.up.right",
                value: minEPSGrowth,
                format: "%.0f%%",
                range: 0...50,
                step: 5,
                rangeLow: "Steady", rangeHigh: "High Growth"
            ) { minEPSGrowth = $0; selectedPreset = .manual }

            criteriaRow(
                label: "Min Market Cap",
                icon: "building.2.fill",
                value: minMarketCapB,
                format: "$%.0fB",
                range: 1...100,
                step: 1,
                rangeLow: "Small Cap", rangeHigh: "Mega Cap"
            ) { minMarketCapB = $0; selectedPreset = .manual }
        } header: {
            Label("Screening Criteria", systemImage: "slider.horizontal.3")
                .font(.caption.bold())
                .foregroundStyle(tint)
        } footer: {
            Text(criteriaFooter)
        }
    }

    private var criteriaFooter: String {
        if selectedPreset != .manual {
            return selectedPreset.description
        }
        return source == .myStocks
            ? "Screens all stocks in your portfolios and watchlist."
            : "Searches for stocks in the selected sector, then screens them."
    }

    private func applyPreset(_ preset: ScreenerPreset) {
        guard let c = preset.criteria else { return }
        maxPE = c.maxPE
        maxDebtEquity = c.maxDE
        minEPSGrowth = c.minEPS
        minMarketCapB = c.minCap
    }

    private var presetInfoSheet: some View {
        NavigationStack {
            List {
                ForEach(ScreenerPreset.allCases.filter { $0 != .manual }) { preset in
                    presetInfoRow(preset)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Investor Strategies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingPresetInfo = false }
                }
            }
        }
    }

    private func presetInfoRow(_ preset: ScreenerPreset) -> some View {
        let isSelected = selectedPreset == preset
        let color = investorColor(preset)
        return Button {
            selectedPreset = preset
            applyPreset(preset)
            showingPresetInfo = false
        } label: {
            HStack(spacing: 0) {
                // Colored accent bar for selected
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? tint : Color.clear)
                    .frame(width: 4)
                    .padding(.vertical, 4)

                HStack(spacing: 12) {
                    // Colored icon circle
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(String(preset.rawValue.prefix(1)))
                            .font(.subheadline.bold())
                            .foregroundStyle(color)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(preset.rawValue)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(tint)
                                    .font(.subheadline)
                            }
                        }

                        Text(preset.strategyDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        presetCriteriaPills(preset)
                    }
                }
                .padding(.leading, 10)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func presetCriteriaPills(_ preset: ScreenerPreset) -> some View {
        if let c = preset.criteria {
            HStack(spacing: 8) {
                presetCriteriaPill("P/E", value: String(format: "%.0f", c.maxPE))
                presetCriteriaPill("D/E", value: String(format: "%.0f%%", c.maxDE))
                presetCriteriaPill("EPS+", value: String(format: "%.0f%%", c.minEPS))
                presetCriteriaPill("Cap", value: String(format: "$%.0fB", c.minCap))
            }
            .padding(.top, 2)
        }
    }

    private func presetCriteriaPill(_ label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(tint.opacity(0.7))
            Text(value)
                .font(.caption2.monospacedDigit().bold())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func criteriaRow(
        label: String,
        icon: String,
        value: Double,
        format: String,
        range: ClosedRange<Double>,
        step: Double,
        rangeLow: String,
        rangeHigh: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(tint)
                    Text(label)
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
                Text(String(format: format, value))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
            }
            Slider(value: Binding(get: { value }, set: onChange), in: range, step: step)
                .tint(tint)
            HStack {
                Text(rangeLow)
                Spacer()
                Text(rangeHigh)
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 0)
    }

    // MARK: - Screen Button

    private var screenButtonSection: some View {
        Section {
            Button {
                Task { await runScreener() }
            } label: {
                HStack {
                    Spacer()
                    Label(screenButtonLabel, systemImage: "sparkle.magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            isScreenButtonDisabled
                                ? AnyShapeStyle(Color.gray.opacity(0.4))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [tint, tint.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                  ))
                        )
                        .shadow(color: isScreenButtonDisabled ? .clear : tint.opacity(0.35), radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
            .disabled(isScreenButtonDisabled)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private var screenButtonLabel: String {
        switch source {
        case .myStocks:
            return "Screen \(uniqueTickers.count) Stocks"
        case .bySector:
            if let sector = selectedSector {
                return "Search & Screen \(sector)"
            }
            return "Select a Sector"
        }
    }

    private var isScreenButtonDisabled: Bool {
        if isScreening { return true }
        switch source {
        case .myStocks: return uniqueTickers.isEmpty
        case .bySector: return selectedSector == nil
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        let passing = screenResults.filter(\.passesAll)
        let total = screenResults.count
        let passCount = passing.count
        return Section {
            // Summary header card
            HStack(spacing: 14) {
                SummaryRingView(
                    passed: passCount,
                    total: total,
                    tint: tint
                )
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(passCount) of \(total) Passed")
                        .font(.headline)
                    Text("Stocks meeting all screening criteria")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

            ForEach(screenResults) { result in
                NavigationLink {
                    StockDetailView(result: MassiveTickerSearchResult(
                        ticker: result.ticker,
                        name: result.companyName,
                        market: "stocks",
                        type: nil,
                        primaryExchange: nil
                    ))
                } label: {
                    screenResultRow(result)
                }
            }
        } header: {
            Label("Results", systemImage: "list.bullet.clipboard.fill")
                .font(.caption.bold())
                .foregroundStyle(tint)
        }
    }

    private func screenResultRow(_ result: ScreenResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CompanyLogoView(
                    branding: nil,
                    ticker: result.ticker,
                    service: massive.service,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.ticker).font(.headline)
                    Text(result.companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("\(result.passCount)/4")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(result.passesAll ? .green : (result.passCount >= 2 ? .orange : .red))
                    if result.passesAll {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .shadow(color: .green.opacity(0.5), radius: 4)
                    } else {
                        Image(systemName: "xmark.diamond.fill")
                            .font(.title3)
                            .foregroundStyle(result.passCount >= 2 ? .orange.opacity(0.7) : .red.opacity(0.6))
                    }
                }
            }

            HStack(spacing: 6) {
                metricPill("P/E", value: result.pe, format: "%.1f",
                           passes: result.pe.map { $0 < maxPE } ?? false)
                metricPill("D/E", value: result.debtEquity, format: "%.0f%%",
                           passes: result.debtEquity.map { $0 < maxDebtEquity } ?? false)
                metricPill("EPS+", value: result.epsGrowth, format: "%.0f%%",
                           passes: result.epsGrowth.map { $0 > minEPSGrowth } ?? false)
                metricPill("Cap", value: result.marketCapB, format: "$%.0fB",
                           passes: result.marketCapB.map { $0 > minMarketCapB } ?? false)
            }
        }
        .padding(.vertical, 6)
    }

    private func metricPill(_ label: String, value: Double?, format: String, passes: Bool) -> some View {
        let hasValue = value != nil
        return VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(hasValue ? (passes ? .white.opacity(0.85) : .red.opacity(0.7)) : .secondary)
            HStack(spacing: 2) {
                if let value {
                    Text(String(format: format, value))
                        .font(.caption2.monospacedDigit().bold())
                } else {
                    Text("N/A")
                        .font(.caption2)
                }
                Image(systemName: passes ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(hasValue ? (passes ? .white : .red) : .gray)
            }
            .foregroundStyle(hasValue ? (passes ? .white : .red) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    hasValue
                        ? (passes
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ))
                            : AnyShapeStyle(Color.red.opacity(0.12)))
                        : AnyShapeStyle(Color(.tertiarySystemFill))
                )
        )
    }

    // MARK: - Screening Logic

    private func runScreener() async {
        isScreening = true
        screenError = nil
        screenResults = []
        defer { isScreening = false }

        let api = massive.service
        let tickers: [String]

        switch source {
        case .myStocks:
            tickers = uniqueTickers
            guard !tickers.isEmpty else {
                screenError = "No stocks in your portfolios or watchlist."
                return
            }
        case .bySector:
            guard let sector = selectedSector,
                  let keywords = sectorKeywords[sector] else {
                screenError = "Please select a sector."
                return
            }
            do {
                var seen = Set<String>()
                var collected: [String] = []
                for keyword in keywords {
                    let results = try await api.fetchTickerSearch(query: keyword)
                    for r in results {
                        if seen.insert(r.ticker).inserted {
                            collected.append(r.ticker)
                        }
                        if collected.count >= 30 { break }
                    }
                    if collected.count >= 30 { break }
                }
                guard !collected.isEmpty else {
                    screenError = "No tickers found for \(sector)."
                    return
                }
                tickers = collected
            } catch {
                screenError = "Search failed: \(error.localizedDescription)"
                return
            }
        }
        let capturedMaxPE = maxPE
        let capturedMaxDE = maxDebtEquity
        let capturedMinEPS = minEPSGrowth
        let capturedMinCap = minMarketCapB

        do {
            let results: [ScreenResult] = try await withThrowingTaskGroup(of: ScreenResult?.self) { group in
                for ticker in tickers {
                    group.addTask { @Sendable in
                        // Fetch data concurrently for each ticker
                        async let detailsReq = api.fetchTickerDetails(ticker: ticker)
                        async let financialsReq = api.fetchFinancials(ticker: ticker, limit: 2)
                        async let priceReq = api.fetchPreviousClose(ticker: ticker)

                        let details: MassiveTickerDetails
                        let financials: [MassiveFinancial]
                        let price: Decimal?

                        do {
                            details = try await detailsReq
                        } catch {
                            return nil
                        }

                        financials = (try? await financialsReq) ?? []
                        price = try? await priceReq

                        // Compute P/E
                        var pe: Double?
                        if let p = price, let eps = financials.first?.dilutedEarningsPerShare, eps > 0 {
                            pe = (p as NSDecimalNumber).doubleValue / (eps as NSDecimalNumber).doubleValue
                        }

                        // Compute D/E
                        var debtEquity: Double?
                        if let liab = financials.first?.liabilities,
                           let eq = financials.first?.equity, eq > 0 {
                            debtEquity = (liab as NSDecimalNumber).doubleValue / (eq as NSDecimalNumber).doubleValue * 100
                        }

                        // Compute EPS Growth
                        var epsGrowth: Double?
                        if financials.count >= 2,
                           let currentEPS = financials[0].dilutedEarningsPerShare,
                           let priorEPS = financials[1].dilutedEarningsPerShare,
                           priorEPS != 0 {
                            let current = (currentEPS as NSDecimalNumber).doubleValue
                            let prior = (priorEPS as NSDecimalNumber).doubleValue
                            epsGrowth = ((current - prior) / abs(prior)) * 100
                        }

                        // Market cap in billions
                        var marketCapB: Double?
                        if let mc = details.marketCap {
                            marketCapB = (mc as NSDecimalNumber).doubleValue / 1_000_000_000
                        }

                        // Determine pass/fail
                        let passesPE = pe.map { $0 < capturedMaxPE } ?? false
                        let passesDE = debtEquity.map { $0 < capturedMaxDE } ?? false
                        let passesEPS = epsGrowth.map { $0 > capturedMinEPS } ?? false
                        let passesCap = marketCapB.map { $0 > capturedMinCap } ?? false
                        let passCount = [passesPE, passesDE, passesEPS, passesCap].filter { $0 }.count
                        let passesAll = passCount == 4

                        return ScreenResult(
                            ticker: ticker,
                            companyName: details.name,
                            pe: pe,
                            debtEquity: debtEquity,
                            epsGrowth: epsGrowth,
                            marketCapB: marketCapB,
                            passesAll: passesAll,
                            passCount: passCount
                        )
                    }
                }

                var collected: [ScreenResult] = []
                for try await result in group {
                    if let result { collected.append(result) }
                }
                return collected
            }

            // Sort: by pass count descending, then P/E ascending within same group
            screenResults = results.sorted { a, b in
                if a.passCount != b.passCount { return a.passCount > b.passCount }
                return (a.pe ?? .infinity) < (b.pe ?? .infinity)
            }
        } catch {
            screenError = error.localizedDescription
        }
    }
}

// MARK: - Summary Ring View

private struct SummaryRingView: View {
    let passed: Int
    let total: Int
    let tint: Color

    private var fraction: Double {
        total > 0 ? Double(passed) / Double(total) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: 5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(passed)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}
