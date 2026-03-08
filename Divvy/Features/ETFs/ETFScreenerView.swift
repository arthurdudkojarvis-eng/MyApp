import SwiftUI
import SwiftData

// MARK: - ETF Screen Result

struct ETFScreenResult: Identifiable {
    let ticker: String
    let name: String
    let dividendYield: Double?
    let frequency: Int?
    let returnSixMonth: Double?
    let marketCapB: Double?
    let avgVolumeM: Double?
    let rsi: Double?
    let passesAll: Bool
    let passCount: Int

    var id: String { ticker }
}

// MARK: - ETF Frequency Filter

enum ETFFrequencyFilter: Int, CaseIterable, Identifiable {
    case any = 0
    case annual = 1
    case semiAnnual = 2
    case quarterly = 4
    case monthly = 12

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .any: return "Any"
        case .annual: return "1/yr"
        case .semiAnnual: return "2/yr"
        case .quarterly: return "4/yr"
        case .monthly: return "12/yr"
        }
    }

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .annual: return "Annual"
        case .semiAnnual: return "Semi-Annual"
        case .quarterly: return "Quarterly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - ETF Screener Preset

enum ETFScreenerPreset: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case dividendIncome = "Dividend Income"
    case growth = "Growth"
    case conservative = "Conservative"
    case value = "Value"
    case balanced = "Balanced"

    var id: String { rawValue }

    /// (minYield%, minFreq, minReturn%, minCapB, minVolM, maxRSI) or nil for manual.
    var criteria: (minYield: Double, minFreq: Int, minReturn: Double, minCapB: Double, minVolM: Double, maxRSI: Double)? {
        switch self {
        case .manual:          return nil
        case .dividendIncome:  return (3, 4, -30, 0, 0, 100)
        case .growth:          return (0, 0, 10, 5, 1, 100)
        case .conservative:    return (2, 4, 0, 10, 2, 70)
        case .value:           return (2, 0, -30, 0, 0, 40)
        case .balanced:        return (1.5, 4, 5, 5, 0.5, 80)
        }
    }

    var description: String {
        switch self {
        case .manual:          return ""
        case .dividendIncome:  return "High-yield ETFs with regular distributions for income investors."
        case .growth:          return "ETFs with strong recent price momentum and sufficient size."
        case .conservative:    return "Large, liquid ETFs with regular payouts and stable momentum."
        case .value:           return "Potentially undervalued ETFs with technical oversold conditions."
        case .balanced:        return "Diversified ETFs balancing yield, growth, and stability."
        }
    }

    var strategyDetail: String {
        switch self {
        case .manual:
            return "Set your own screening criteria using the controls below."
        case .dividendIncome:
            return "Targets ETFs paying at least 3% annualized yield on a quarterly or more frequent basis. Ideal for investors seeking regular cash flow from their ETF portfolio. No constraints on momentum or size allow focus purely on income generation."
        case .growth:
            return "Seeks ETFs with at least 10% price appreciation over the past six months and minimum $5B market cap. Volume floor of 1M shares ensures liquidity. Suitable for investors prioritizing capital growth over income."
        case .conservative:
            return "Combines moderate yield (2%+) with quarterly distributions, positive 6-month returns, and large-cap ($10B+) focus. High volume requirement (2M+) ensures easy exit. RSI cap at 70 avoids chasing overbought conditions."
        case .value:
            return "Screens for ETFs with decent yield (2%+) trading in oversold territory (RSI below 40). This contrarian approach targets ETFs the market may have unfairly punished, offering potential mean-reversion upside."
        case .balanced:
            return "Middle-ground strategy requiring moderate yield (1.5%+), quarterly payouts, positive recent momentum (5%+ return), and adequate size ($5B+ cap). Balances income, growth, and risk management."
        }
    }
}

// MARK: - ETF Screener Source

enum ETFScreenerSource: String, CaseIterable {
    case myETFs = "My ETFs"
    case bySector = "By Sector"
}

// MARK: - ETFScreenerView

struct ETFScreenerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.massiveService) private var massive
    @Environment(SettingsStore.self) private var settings
    @Query private var portfolios: [Portfolio]
    @Query private var watchlistItems: [WatchlistItem]

    @State private var source: ETFScreenerSource = .myETFs
    @State private var selectedSector: String?
    @State private var selectedPreset: ETFScreenerPreset = .manual
    @State private var showingPresetInfo = false

    // 6 ETF-specific criteria
    @State private var minDividendYield: Double = 0
    @State private var minFrequency: ETFFrequencyFilter = .any
    @State private var minReturn: Double = -30
    @State private var minMarketCapB: Double = 0
    @State private var minVolumeM: Double = 0
    @State private var maxRSI: Double = 100

    @State private var isScreening = false
    @State private var screenResults: [ETFScreenResult] = []
    @State private var screenError: String?

    private var tint: Color { settings.fontTheme.color ?? Color.accentColor }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let sectorChips: [String] = [
        "Technology", "Healthcare", "Finance", "Energy",
        "Consumer Cyclical", "Industrials", "Real Estate",
        "Utilities", "Communication", "Materials"
    ]

    private let sectorKeywords: [String: [String]] = [
        "Technology": ["technology ETF", "semiconductor ETF"],
        "Healthcare": ["healthcare ETF", "biotech ETF"],
        "Finance": ["financial ETF", "banking ETF"],
        "Energy": ["energy ETF", "oil ETF"],
        "Consumer Cyclical": ["consumer ETF", "retail ETF"],
        "Industrials": ["industrial ETF", "aerospace ETF"],
        "Real Estate": ["real estate ETF", "REIT ETF"],
        "Utilities": ["utilities ETF", "electric ETF"],
        "Communication": ["communication ETF", "media ETF"],
        "Materials": ["materials ETF", "mining ETF"]
    ]

    private var uniqueETFTickers: [String] {
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

    private func presetColor(_ preset: ETFScreenerPreset) -> Color {
        switch preset {
        case .manual: return .gray
        case .dividendIncome: return .green
        case .growth: return .orange
        case .conservative: return .blue
        case .value: return .purple
        case .balanced: return .teal
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
                                Text(source == .myETFs
                                     ? "Screening \(uniqueETFTickers.count) ETFs..."
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
            .navigationTitle("ETF Screener")
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
                ForEach(ETFScreenerSource.allCases, id: \.self) { s in
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
            Label("ETF Source", systemImage: "tray.full.fill")
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
                        ForEach(ETFScreenerPreset.allCases) { preset in
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
                                            if c.minYield > 0 {
                                                Text("Yld≥\(String(format: "%.0f", c.minYield))%")
                                            }
                                            if c.minFreq > 0 {
                                                Text("Freq≥\(c.minFreq)/yr")
                                            }
                                            if c.minReturn > -30 {
                                                Text("Ret≥\(String(format: "%.0f", c.minReturn))%")
                                            }
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

            // 1. Min Dividend Yield
            criteriaRow(
                label: "Min Dividend Yield",
                icon: "percent",
                value: minDividendYield,
                format: "%.1f%%",
                range: 0...15,
                step: 0.5,
                rangeLow: "Any", rangeHigh: "High Yield"
            ) { minDividendYield = $0; selectedPreset = .manual }

            // 2. Min Payout Frequency
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(tint)
                    Text("Min Payout Frequency")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(minFrequency.displayName)
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
                Picker("Frequency", selection: $minFrequency) {
                    ForEach(ETFFrequencyFilter.allCases) { freq in
                        Text(freq.label).tag(freq)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: minFrequency) { _, _ in selectedPreset = .manual }
            }

            // 3. Min 6-Month Return
            criteriaRow(
                label: "Min 6-Month Return",
                icon: "chart.line.uptrend.xyaxis",
                value: minReturn,
                format: "%+.0f%%",
                range: -30...50,
                step: 1,
                rangeLow: "Any", rangeHigh: "Strong Momentum"
            ) { minReturn = $0; selectedPreset = .manual }

            // 4. Min Market Cap
            criteriaRow(
                label: "Min Market Cap",
                icon: "building.2.fill",
                value: minMarketCapB,
                format: "$%.0fB",
                range: 0...100,
                step: 1,
                rangeLow: "Any", rangeHigh: "Mega Cap"
            ) { minMarketCapB = $0; selectedPreset = .manual }

            // 5. Min Daily Volume
            criteriaRow(
                label: "Min Daily Volume",
                icon: "chart.bar.fill",
                value: minVolumeM,
                format: "%.1fM",
                range: 0...10,
                step: 0.1,
                rangeLow: "Any", rangeHigh: "High Liquidity"
            ) { minVolumeM = $0; selectedPreset = .manual }

            // 6. Max RSI
            criteriaRow(
                label: "Max RSI",
                icon: "waveform.path.ecg",
                value: maxRSI,
                format: "%.0f",
                range: 20...100,
                step: 5,
                rangeLow: "Oversold Only", rangeHigh: "No Filter"
            ) { maxRSI = $0; selectedPreset = .manual }
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
        return source == .myETFs
            ? "Screens all ETFs in your portfolios and watchlist."
            : "Searches for ETFs in the selected sector, then screens them."
    }

    private func applyPreset(_ preset: ETFScreenerPreset) {
        guard let c = preset.criteria else { return }
        minDividendYield = c.minYield
        minFrequency = ETFFrequencyFilter(rawValue: c.minFreq) ?? .any
        minReturn = c.minReturn
        minMarketCapB = c.minCapB
        minVolumeM = c.minVolM
        maxRSI = c.maxRSI
    }

    private var presetInfoSheet: some View {
        NavigationStack {
            List {
                ForEach(ETFScreenerPreset.allCases.filter { $0 != .manual }) { preset in
                    presetInfoRow(preset)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ETF Strategies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingPresetInfo = false }
                }
            }
        }
    }

    private func presetInfoRow(_ preset: ETFScreenerPreset) -> some View {
        let isSelected = selectedPreset == preset
        let color = presetColor(preset)
        return Button {
            selectedPreset = preset
            applyPreset(preset)
            showingPresetInfo = false
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? tint : Color.clear)
                    .frame(width: 4)
                    .padding(.vertical, 4)

                HStack(spacing: 12) {
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
    private func presetCriteriaPills(_ preset: ETFScreenerPreset) -> some View {
        if let c = preset.criteria {
            HStack(spacing: 6) {
                if c.minYield > 0 {
                    presetCriteriaPill("Yield", value: "≥\(String(format: "%.0f", c.minYield))%")
                }
                if c.minFreq > 0 {
                    let freqLabel = ETFFrequencyFilter(rawValue: c.minFreq)?.label ?? "\(c.minFreq)/yr"
                    presetCriteriaPill("Freq", value: "≥\(freqLabel)")
                }
                if c.minReturn > -30 {
                    presetCriteriaPill("Ret", value: "≥\(String(format: "%.0f", c.minReturn))%")
                }
                if c.minCapB > 0 {
                    presetCriteriaPill("Cap", value: "≥$\(String(format: "%.0f", c.minCapB))B")
                }
                if c.minVolM > 0 {
                    presetCriteriaPill("Vol", value: "≥\(String(format: "%.1f", c.minVolM))M")
                }
                if c.maxRSI < 100 {
                    presetCriteriaPill("RSI", value: "≤\(String(format: "%.0f", c.maxRSI))")
                }
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
        .padding(.horizontal, 6)
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
        case .myETFs:
            return "Screen \(uniqueETFTickers.count) ETFs"
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
        case .myETFs: return uniqueETFTickers.isEmpty
        case .bySector: return selectedSector == nil
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        let passing = screenResults.filter(\.passesAll)
        let total = screenResults.count
        let passCount = passing.count
        return Section {
            HStack(spacing: 14) {
                ETFSummaryRingView(
                    passed: passCount,
                    total: total,
                    tint: tint
                )
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(passCount) of \(total) Passed")
                        .font(.headline)
                    Text("ETFs meeting all screening criteria")
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
                        name: result.name,
                        market: "stocks",
                        type: "ETF",
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

    private func screenResultRow(_ result: ETFScreenResult) -> some View {
        let totalCriteria = 6
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CompanyLogoView(
                    branding: nil,
                    ticker: result.ticker,
                    service: massive.service,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.ticker).font(.headline)
                    Text(result.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("\(result.passCount)/\(totalCriteria)")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(result.passesAll ? .green : (result.passCount >= 3 ? .orange : .red))
                    if result.passesAll {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .shadow(color: .green.opacity(0.5), radius: 4)
                    } else {
                        Image(systemName: "xmark.diamond.fill")
                            .font(.title3)
                            .foregroundStyle(result.passCount >= 3 ? .orange.opacity(0.7) : .red.opacity(0.6))
                    }
                }
            }

            // Row 1: Yield, Frequency, Return
            HStack(spacing: 6) {
                metricPill("Yield", value: result.dividendYield, format: "%.1f%%",
                           passes: passesYield(result.dividendYield))
                frequencyPill(result.frequency)
                metricPill("6M Ret", value: result.returnSixMonth, format: "%+.1f%%",
                           passes: passesReturn(result.returnSixMonth))
            }

            // Row 2: Market Cap, Volume, RSI
            HStack(spacing: 6) {
                metricPill("Cap", value: result.marketCapB, format: "$%.1fB",
                           passes: passesCap(result.marketCapB))
                metricPill("Vol", value: result.avgVolumeM, format: "%.1fM",
                           passes: passesVolume(result.avgVolumeM))
                metricPill("RSI", value: result.rsi, format: "%.0f",
                           passes: passesRSI(result.rsi))
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Pass/Fail Helpers

    private func passesYield(_ value: Double?) -> Bool {
        minDividendYield <= 0 || (value.map { $0 >= minDividendYield } ?? false)
    }

    private func passesFreq(_ value: Int?) -> Bool {
        minFrequency == .any || (value.map { $0 >= minFrequency.rawValue } ?? false)
    }

    private func passesReturn(_ value: Double?) -> Bool {
        minReturn <= -30 || (value.map { $0 >= minReturn } ?? false)
    }

    private func passesCap(_ value: Double?) -> Bool {
        minMarketCapB <= 0 || (value.map { $0 >= minMarketCapB } ?? false)
    }

    private func passesVolume(_ value: Double?) -> Bool {
        minVolumeM <= 0 || (value.map { $0 >= minVolumeM } ?? false)
    }

    private func passesRSI(_ value: Double?) -> Bool {
        maxRSI >= 100 || (value.map { $0 <= maxRSI } ?? false)
    }

    // MARK: - Metric Pills

    private func frequencyPill(_ freq: Int?) -> some View {
        let passes = passesFreq(freq)
        let hasValue = freq != nil
        let displayText: String
        if let f = freq {
            switch f {
            case 12: displayText = "Monthly"
            case 4:  displayText = "Quarterly"
            case 2:  displayText = "Semi-Ann"
            case 1:  displayText = "Annual"
            default: displayText = "\(f)/yr"
            }
        } else {
            displayText = "N/A"
        }

        return VStack(spacing: 2) {
            Text("Freq")
                .font(.caption2)
                .foregroundStyle(hasValue ? (passes ? .white.opacity(0.85) : .red.opacity(0.7)) : .secondary)
            HStack(spacing: 2) {
                Text(displayText)
                    .font(.caption2.monospacedDigit().bold())
                Image(systemName: passes ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(hasValue ? (passes ? .white : .red) : .gray)
            }
            .foregroundStyle(hasValue ? (passes ? .white : .red) : .secondary)
        }
        .padding(.horizontal, 6)
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
        .padding(.horizontal, 6)
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
        case .myETFs:
            tickers = uniqueETFTickers
            guard !tickers.isEmpty else {
                screenError = "No tickers in your portfolios or watchlist."
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
                    for r in results where r.type?.uppercased() == "ETF" {
                        if seen.insert(r.ticker).inserted {
                            collected.append(r.ticker)
                        }
                        if collected.count >= 30 { break }
                    }
                    if collected.count >= 30 { break }
                }
                guard !collected.isEmpty else {
                    screenError = "No ETFs found for \(sector)."
                    return
                }
                tickers = collected
            } catch {
                screenError = "Search failed: \(error.localizedDescription)"
                return
            }
        }

        // Capture criteria for @Sendable closure
        let capturedMinYield = minDividendYield
        let capturedMinFreq = minFrequency.rawValue
        let capturedMinReturn = minReturn
        let capturedMinCap = minMarketCapB
        let capturedMinVol = minVolumeM
        let capturedMaxRSI = maxRSI

        // Compute date strings for 6-month return
        let calendar = Calendar.current
        let today = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today)!
        let sixMonthsAgoPlus7 = calendar.date(byAdding: .day, value: 7, to: sixMonthsAgo)!
        let fromStr = Self.dateFormatter.string(from: sixMonthsAgo)
        let toStr = Self.dateFormatter.string(from: sixMonthsAgoPlus7)

        do {
            let results: [ETFScreenResult] = try await withThrowingTaskGroup(of: ETFScreenResult?.self) { group in
                let isMyETFs = source == .myETFs
                for ticker in tickers {
                    group.addTask { @Sendable in
                        // For "My ETFs": check type first, skip non-ETFs before expensive calls
                        if isMyETFs {
                            let searchResults = (try? await api.fetchTickerSearch(query: ticker)) ?? []
                            let isETF = searchResults.contains { $0.ticker == ticker && $0.type?.uppercased() == "ETF" }
                            guard isETF else { return nil }
                        }

                        // Fetch all data concurrently
                        async let detailsReq = api.fetchTickerDetails(ticker: ticker)
                        async let dividendsReq = api.fetchDividends(ticker: ticker, limit: 4)
                        async let closeBarReq = api.fetchPreviousCloseBar(ticker: ticker)
                        async let aggregatesReq = api.fetchAggregates(ticker: ticker, from: fromStr, to: toStr)
                        async let rsiReq = api.fetchTechnicalIndicator(type: .rsi, ticker: ticker)

                        let details: MassiveTickerDetails
                        do {
                            details = try await detailsReq
                        } catch {
                            return nil
                        }

                        let dividends = (try? await dividendsReq) ?? []
                        let closeBar = try? await closeBarReq
                        let pastAggregates = (try? await aggregatesReq) ?? []
                        let rsiValues = (try? await rsiReq) ?? []

                        let currentPrice = closeBar?.c

                        // 1. Dividend Yield
                        var dividendYield: Double?
                        if let latest = dividends.first, let price = currentPrice, price > 0 {
                            let freq = Decimal(latest.frequency ?? 4)
                            let annual = latest.cashAmount * freq
                            dividendYield = ((annual / price) * 100 as NSDecimalNumber).doubleValue
                        }

                        // 2. Frequency
                        let frequency = dividends.first?.frequency

                        // 3. 6-Month Return
                        var returnSixMonth: Double?
                        if let pastBar = pastAggregates.first, let price = currentPrice, pastBar.c > 0 {
                            let pastPrice = (pastBar.c as NSDecimalNumber).doubleValue
                            let curPrice = (price as NSDecimalNumber).doubleValue
                            returnSixMonth = ((curPrice - pastPrice) / pastPrice) * 100
                        }

                        // 4. Market Cap in billions
                        var marketCapB: Double?
                        if let mc = details.marketCap {
                            marketCapB = (mc as NSDecimalNumber).doubleValue / 1_000_000_000
                        }

                        // 5. Volume in millions
                        var avgVolumeM: Double?
                        if let vol = closeBar?.v {
                            avgVolumeM = (vol as NSDecimalNumber).doubleValue / 1_000_000
                        }

                        // 6. RSI
                        let rsi = rsiValues.last.map { ($0.value as NSDecimalNumber).doubleValue }

                        // Determine pass/fail for each criterion
                        let pYield = capturedMinYield <= 0 || (dividendYield.map { $0 >= capturedMinYield } ?? false)
                        let pFreq = capturedMinFreq == 0 || (frequency.map { $0 >= capturedMinFreq } ?? false)
                        let pReturn = capturedMinReturn <= -30 || (returnSixMonth.map { $0 >= capturedMinReturn } ?? false)
                        let pCap = capturedMinCap <= 0 || (marketCapB.map { $0 >= capturedMinCap } ?? false)
                        let pVol = capturedMinVol <= 0 || (avgVolumeM.map { $0 >= capturedMinVol } ?? false)
                        let pRSI = capturedMaxRSI >= 100 || (rsi.map { $0 <= capturedMaxRSI } ?? false)

                        let passCount = [pYield, pFreq, pReturn, pCap, pVol, pRSI].filter { $0 }.count
                        let passesAll = passCount == 6

                        return ETFScreenResult(
                            ticker: ticker,
                            name: details.name,
                            dividendYield: dividendYield,
                            frequency: frequency,
                            returnSixMonth: returnSixMonth,
                            marketCapB: marketCapB,
                            avgVolumeM: avgVolumeM,
                            rsi: rsi,
                            passesAll: passesAll,
                            passCount: passCount
                        )
                    }
                }

                var collected: [ETFScreenResult] = []
                for try await result in group {
                    if let result { collected.append(result) }
                }
                return collected
            }

            // Sort by pass count descending, then yield descending
            screenResults = results.sorted { a, b in
                if a.passCount != b.passCount { return a.passCount > b.passCount }
                return (a.dividendYield ?? 0) > (b.dividendYield ?? 0)
            }
        } catch {
            screenError = error.localizedDescription
        }
    }
}

// MARK: - ETF Summary Ring View

private struct ETFSummaryRingView: View {
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
