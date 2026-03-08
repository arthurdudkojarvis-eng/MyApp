import Foundation

struct ETFTipConstituent: Identifiable {
    let ticker: String
    let name: String
    let note: String
    var id: String { ticker }
}

struct ETFTip: Identifiable {
    let name: String
    let description: String
    let category: String
    let riskLevel: String
    let examples: [ETFTipConstituent]
    var id: String { name }
}

let builtInETFTips: [ETFTip] = [
    ETFTip(
        name: "Total Market Dividend",
        description: "Broad-market dividend ETFs provide instant diversification across hundreds of income-paying stocks. One fund replaces the need to pick individual dividend stocks.",
        category: "Core Holdings",
        riskLevel: "Low",
        examples: [
            ETFTipConstituent(ticker: "VYM", name: "Vanguard High Dividend Yield ETF", note: "400+ dividend stocks"),
            ETFTipConstituent(ticker: "SCHD", name: "Schwab US Dividend Equity ETF", note: "Quality + yield screen"),
            ETFTipConstituent(ticker: "HDV", name: "iShares Core High Dividend ETF", note: "75 high-yield stocks"),
            ETFTipConstituent(ticker: "DVY", name: "iShares Select Dividend ETF", note: "100 dividend leaders"),
            ETFTipConstituent(ticker: "DGRO", name: "iShares Core Dividend Growth ETF", note: "Growth-focused screen"),
        ]
    ),
    ETFTip(
        name: "Dividend Growth Focus",
        description: "These ETFs target companies with strong dividend growth histories rather than just high current yields. Lower starting yield but faster compounding over time.",
        category: "Dividend Growth",
        riskLevel: "Low",
        examples: [
            ETFTipConstituent(ticker: "NOBL", name: "ProShares S&P 500 Dividend Aristocrats ETF", note: "25+ years of growth"),
            ETFTipConstituent(ticker: "DGRW", name: "WisdomTree US Quality Dividend Growth", note: "Quality + growth"),
            ETFTipConstituent(ticker: "VIG", name: "Vanguard Dividend Appreciation ETF", note: "10+ years of growth"),
            ETFTipConstituent(ticker: "TDVG", name: "T. Rowe Price Dividend Growth ETF", note: "Active management"),
            ETFTipConstituent(ticker: "RDVY", name: "First Trust Rising Dividend Achievers", note: "Rising payout screen"),
        ]
    ),
    ETFTip(
        name: "High Yield Bond ETFs",
        description: "Corporate bond ETFs pay higher yields than dividend stocks but carry credit risk. Use them to add fixed-income diversification and boost overall portfolio yield.",
        category: "Fixed Income",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "HYG", name: "iShares iBoxx High Yield Corporate Bond ETF", note: "Largest high-yield bond ETF"),
            ETFTipConstituent(ticker: "JNK", name: "SPDR Bloomberg High Yield Bond ETF", note: "Broad junk bond exposure"),
            ETFTipConstituent(ticker: "USHY", name: "iShares Broad USD High Yield Corp Bond ETF", note: "Low-cost high-yield"),
            ETFTipConstituent(ticker: "SHYG", name: "iShares 0-5 Year High Yield Corp Bond ETF", note: "Short duration, less rate risk"),
            ETFTipConstituent(ticker: "ANGL", name: "VanEck Fallen Angel High Yield Bond ETF", note: "Fallen angel premium"),
        ]
    ),
    ETFTip(
        name: "REIT ETFs",
        description: "Real estate ETFs give you exposure to commercial property income without buying buildings. REITs must distribute 90% of taxable income, making these natural yield vehicles.",
        category: "Real Estate",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "VNQ", name: "Vanguard Real Estate ETF", note: "Largest REIT ETF"),
            ETFTipConstituent(ticker: "SCHH", name: "Schwab US REIT ETF", note: "Ultra-low 0.07% expense"),
            ETFTipConstituent(ticker: "XLRE", name: "Real Estate Select Sector SPDR", note: "S&P 500 REITs only"),
            ETFTipConstituent(ticker: "RWR", name: "SPDR Dow Jones REIT ETF", note: "Pure-play REITs"),
            ETFTipConstituent(ticker: "USRT", name: "iShares Core US REIT ETF", note: "Broad US REIT market"),
        ]
    ),
    ETFTip(
        name: "International Dividend ETFs",
        description: "Global dividend ETFs provide geographic diversification and access to higher yields available outside the US. Currency fluctuations add both risk and opportunity.",
        category: "International",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "VYMI", name: "Vanguard Intl High Dividend Yield ETF", note: "Ex-US high yield"),
            ETFTipConstituent(ticker: "IDV", name: "iShares International Select Dividend ETF", note: "100 intl dividend stocks"),
            ETFTipConstituent(ticker: "SCHY", name: "Schwab International Dividend Equity ETF", note: "Quality intl dividends"),
            ETFTipConstituent(ticker: "DWX", name: "SPDR S&P International Dividend ETF", note: "100 highest-yielding intl"),
            ETFTipConstituent(ticker: "VIGI", name: "Vanguard Intl Dividend Appreciation ETF", note: "Intl dividend growers"),
        ]
    ),
    ETFTip(
        name: "Covered Call ETFs",
        description: "These ETFs sell call options on their holdings to generate extra income beyond dividends. Yields of 8-12% are common, but upside is capped during strong rallies.",
        category: "Options Income",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "JEPI", name: "JPMorgan Equity Premium Income ETF", note: "ELNs + S&P 500 stocks"),
            ETFTipConstituent(ticker: "JEPQ", name: "JPMorgan Nasdaq Equity Premium Income ETF", note: "Nasdaq covered calls"),
            ETFTipConstituent(ticker: "QYLD", name: "Global X NASDAQ 100 Covered Call ETF", note: "ATM calls on QQQ"),
            ETFTipConstituent(ticker: "XYLD", name: "Global X S&P 500 Covered Call ETF", note: "ATM calls on SPY"),
            ETFTipConstituent(ticker: "DIVO", name: "Amplify CWP Enhanced Dividend Income ETF", note: "Selective call writing"),
        ]
    ),
    ETFTip(
        name: "Low Volatility Income",
        description: "Minimum volatility ETFs hold the least-volatile stocks in an index. Lower drawdowns during crashes let you hold through downturns and keep collecting dividends.",
        category: "Defensive",
        riskLevel: "Low",
        examples: [
            ETFTipConstituent(ticker: "USMV", name: "iShares MSCI USA Min Vol Factor ETF", note: "Min vol US large-cap"),
            ETFTipConstituent(ticker: "SPLV", name: "Invesco S&P 500 Low Volatility ETF", note: "100 lowest-vol S&P 500"),
            ETFTipConstituent(ticker: "SPHD", name: "Invesco S&P 500 High Div Low Vol ETF", note: "High yield + low vol"),
            ETFTipConstituent(ticker: "EFAV", name: "iShares MSCI EAFE Min Vol Factor ETF", note: "Intl min vol"),
            ETFTipConstituent(ticker: "LVHD", name: "Franklin US Low Volatility High Div ETF", note: "Income + stability"),
        ]
    ),
    ETFTip(
        name: "Treasury Bond ETFs",
        description: "US Treasury ETFs are the safest income source — backed by the US government. Use them to reduce portfolio volatility and lock in yields when rates are high.",
        category: "Fixed Income",
        riskLevel: "Low",
        examples: [
            ETFTipConstituent(ticker: "TLT", name: "iShares 20+ Year Treasury Bond ETF", note: "Long-duration Treasuries"),
            ETFTipConstituent(ticker: "IEF", name: "iShares 7-10 Year Treasury Bond ETF", note: "Intermediate duration"),
            ETFTipConstituent(ticker: "SHY", name: "iShares 1-3 Year Treasury Bond ETF", note: "Short duration, low risk"),
            ETFTipConstituent(ticker: "TIP", name: "iShares TIPS Bond ETF", note: "Inflation-protected"),
            ETFTipConstituent(ticker: "VGSH", name: "Vanguard Short-Term Treasury ETF", note: "Ultra-low 0.04% expense"),
        ]
    ),
    ETFTip(
        name: "Municipal Bond ETFs",
        description: "Muni bond ETFs pay interest that is exempt from federal income tax, and often state tax too. The after-tax yield can beat Treasuries for investors in high tax brackets.",
        category: "Tax Efficient",
        riskLevel: "Low",
        examples: [
            ETFTipConstituent(ticker: "MUB", name: "iShares National Muni Bond ETF", note: "Broad muni market"),
            ETFTipConstituent(ticker: "VTEB", name: "Vanguard Tax-Exempt Bond ETF", note: "Ultra-low 0.05% expense"),
            ETFTipConstituent(ticker: "TFI", name: "SPDR Nuveen Municipal Bond ETF", note: "Investment-grade munis"),
            ETFTipConstituent(ticker: "HYD", name: "VanEck High Yield Muni ETF", note: "High-yield muni bonds"),
            ETFTipConstituent(ticker: "SUB", name: "iShares Short-Term National Muni Bond ETF", note: "Short duration munis"),
        ]
    ),
    ETFTip(
        name: "Preferred Stock ETFs",
        description: "Preferred stock ETFs offer bond-like fixed dividends with equity-like upside. Yields of 5-7% are typical. They sit between bonds and common stock in the capital structure.",
        category: "Hybrid Income",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "PFF", name: "iShares Preferred & Income Securities ETF", note: "Largest preferred ETF"),
            ETFTipConstituent(ticker: "PGX", name: "Invesco Preferred ETF", note: "Investment-grade focus"),
            ETFTipConstituent(ticker: "PFFD", name: "Global X US Preferred ETF", note: "Low-cost at 0.23%"),
            ETFTipConstituent(ticker: "FPE", name: "First Trust Preferred Securities ETF", note: "Active management"),
            ETFTipConstituent(ticker: "PSK", name: "SPDR ICE Preferred Securities ETF", note: "Broad preferred index"),
        ]
    ),
    ETFTip(
        name: "Monthly Paying ETFs",
        description: "Most bond and REIT ETFs pay monthly rather than quarterly. Building a portfolio of monthly payers creates a regular income stream that matches your monthly expenses.",
        category: "Income",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "JEPI", name: "JPMorgan Equity Premium Income ETF", note: "Monthly equity income"),
            ETFTipConstituent(ticker: "DIVO", name: "Amplify CWP Enhanced Dividend Income ETF", note: "Monthly dividend ETF"),
            ETFTipConstituent(ticker: "SPHD", name: "Invesco S&P 500 High Div Low Vol ETF", note: "Monthly distributions"),
            ETFTipConstituent(ticker: "PFF", name: "iShares Preferred & Income Securities ETF", note: "Monthly preferred income"),
            ETFTipConstituent(ticker: "VCIT", name: "Vanguard Intermediate-Term Corp Bond ETF", note: "Monthly bond income"),
        ]
    ),
    ETFTip(
        name: "Sector ETFs for Income",
        description: "Sector ETFs let you overweight high-yielding sectors like utilities, energy, and financials without picking individual stocks. Great for targeted income tilts.",
        category: "Sector Focus",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "XLU", name: "Utilities Select Sector SPDR", note: "Utility stocks ~3% yield"),
            ETFTipConstituent(ticker: "XLE", name: "Energy Select Sector SPDR", note: "Energy stocks ~3.5% yield"),
            ETFTipConstituent(ticker: "XLF", name: "Financial Select Sector SPDR", note: "Bank & insurance stocks"),
            ETFTipConstituent(ticker: "XLP", name: "Consumer Staples Select Sector SPDR", note: "Defensive consumer names"),
            ETFTipConstituent(ticker: "XLRE", name: "Real Estate Select Sector SPDR", note: "S&P 500 REITs"),
        ]
    ),
    ETFTip(
        name: "Small-Cap Dividend ETFs",
        description: "Small-cap dividend ETFs combine the growth potential of smaller companies with dividend income. Higher volatility but also higher total return potential over long periods.",
        category: "Growth & Income",
        riskLevel: "High",
        examples: [
            ETFTipConstituent(ticker: "DES", name: "WisdomTree US SmallCap Dividend ETF", note: "Dividend-weighted small-caps"),
            ETFTipConstituent(ticker: "SMDV", name: "ProShares Russell 2000 Dividend Growers ETF", note: "Small-cap dividend growth"),
            ETFTipConstituent(ticker: "SDIV", name: "Global X SuperDividend ETF", note: "100 highest-yield globally"),
            ETFTipConstituent(ticker: "REGL", name: "ProShares S&P MidCap 400 Dividend Aristocrats", note: "Mid-cap 15+ year growers"),
            ETFTipConstituent(ticker: "FDL", name: "First Trust Morningstar Dividend Leaders ETF", note: "High-yield large & mid-cap"),
        ]
    ),
    ETFTip(
        name: "Emerging Market Income",
        description: "Emerging market ETFs access higher yields from developing economies. Currency and political risks are real, but so is the income premium over developed markets.",
        category: "International",
        riskLevel: "High",
        examples: [
            ETFTipConstituent(ticker: "DVYE", name: "iShares Emerging Markets Dividend ETF", note: "EM dividend stocks"),
            ETFTipConstituent(ticker: "DEM", name: "WisdomTree Emerging Markets High Dividend ETF", note: "Dividend-weighted EM"),
            ETFTipConstituent(ticker: "EDIV", name: "SPDR S&P Emerging Markets Dividend ETF", note: "High-yield EM screen"),
            ETFTipConstituent(ticker: "EMHY", name: "iShares J.P. Morgan EM High Yield Bond ETF", note: "EM junk bonds"),
            ETFTipConstituent(ticker: "PCY", name: "Invesco Emerging Markets Sovereign Debt ETF", note: "EM government bonds"),
        ]
    ),
    ETFTip(
        name: "Expense Ratio Matters",
        description: "Over 30 years, a 0.50% expense ratio difference costs you 14% of your final portfolio value. Always compare expense ratios — the cheapest ETF usually wins for identical strategies.",
        category: "Cost Efficiency",
        riskLevel: "Educational",
        examples: [
            ETFTipConstituent(ticker: "VYM", name: "Vanguard High Dividend Yield ETF", note: "0.06% expense ratio"),
            ETFTipConstituent(ticker: "SCHD", name: "Schwab US Dividend Equity ETF", note: "0.06% expense ratio"),
            ETFTipConstituent(ticker: "VIG", name: "Vanguard Dividend Appreciation ETF", note: "0.06% expense ratio"),
            ETFTipConstituent(ticker: "DGRO", name: "iShares Core Dividend Growth ETF", note: "0.08% expense ratio"),
            ETFTipConstituent(ticker: "VNQ", name: "Vanguard Real Estate ETF", note: "0.12% expense ratio"),
        ]
    ),
    ETFTip(
        name: "Retirement Income Blend",
        description: "Combine equity dividend ETFs with bond ETFs for a balanced income portfolio. The classic 60/40 split reduces volatility while maintaining a steady income stream.",
        category: "Asset Allocation",
        riskLevel: "Low",
        examples: [
            ETFTipConstituent(ticker: "SCHD", name: "Schwab US Dividend Equity ETF", note: "Equity income core"),
            ETFTipConstituent(ticker: "BND", name: "Vanguard Total Bond Market ETF", note: "Broad bond exposure"),
            ETFTipConstituent(ticker: "VYM", name: "Vanguard High Dividend Yield ETF", note: "High-yield equity"),
            ETFTipConstituent(ticker: "VCIT", name: "Vanguard Intermediate-Term Corp Bond ETF", note: "Corporate bond income"),
            ETFTipConstituent(ticker: "TIP", name: "iShares TIPS Bond ETF", note: "Inflation protection"),
        ]
    ),
    ETFTip(
        name: "ESG Dividend ETFs",
        description: "Environmental, social, and governance screened ETFs let you earn income while investing in companies with responsible business practices. Growing category with competitive yields.",
        category: "Responsible Investing",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "ESGU", name: "iShares ESG Aware MSCI USA ETF", note: "ESG large-cap US"),
            ETFTipConstituent(ticker: "SUSA", name: "iShares MSCI USA ESG Select ETF", note: "Best-in-class ESG"),
            ETFTipConstituent(ticker: "DSI", name: "iShares MSCI KLD 400 Social ETF", note: "400 socially responsible cos"),
            ETFTipConstituent(ticker: "SUSC", name: "iShares ESG Aware USD Corp Bond ETF", note: "ESG corporate bonds"),
            ETFTipConstituent(ticker: "ESGV", name: "Vanguard ESG US Stock ETF", note: "Low-cost ESG equity"),
        ]
    ),
    ETFTip(
        name: "Infrastructure ETFs",
        description: "Infrastructure ETFs invest in companies that own and operate essential assets — toll roads, airports, pipelines, cell towers. These real assets generate steady, inflation-linked income.",
        category: "Real Assets",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "IGF", name: "iShares Global Infrastructure ETF", note: "Global infrastructure"),
            ETFTipConstituent(ticker: "PAVE", name: "Global X US Infrastructure Development ETF", note: "US infrastructure build"),
            ETFTipConstituent(ticker: "NFRA", name: "FlexShares STOXX Global Broad Infra ETF", note: "Broad global infra"),
            ETFTipConstituent(ticker: "IFRA", name: "iShares US Infrastructure ETF", note: "US-focused infra"),
            ETFTipConstituent(ticker: "MLPA", name: "Global X MLP ETF", note: "Midstream energy MLPs"),
        ]
    ),
    ETFTip(
        name: "Convertible Bond ETFs",
        description: "Convertible bond ETFs hold bonds that can convert into stock, offering income plus equity upside. They tend to fall less in crashes while participating in rallies.",
        category: "Hybrid Income",
        riskLevel: "Moderate",
        examples: [
            ETFTipConstituent(ticker: "CWB", name: "SPDR Bloomberg Convertible Securities ETF", note: "Largest convertible ETF"),
            ETFTipConstituent(ticker: "ICVT", name: "iShares Convertible Bond ETF", note: "Broad convertible index"),
            ETFTipConstituent(ticker: "FCVT", name: "First Trust SSI Strategic Convertible ETF", note: "Active management"),
            ETFTipConstituent(ticker: "CCOR", name: "Cambria Core Equity ETF", note: "Equity + downside hedging"),
            ETFTipConstituent(ticker: "VCIT", name: "Vanguard Intermediate-Term Corp Bond ETF", note: "Corporate bond alternative"),
        ]
    ),
    ETFTip(
        name: "Avoid Yield Traps",
        description: "Extremely high ETF yields (over 10%) often signal risk — leverage, options premium decay, or declining NAV. Always check if the NAV is stable or eroding over time.",
        category: "Risk Management",
        riskLevel: "Educational",
        examples: [
            ETFTipConstituent(ticker: "QYLD", name: "Global X NASDAQ 100 Covered Call ETF", note: "High yield, NAV erosion risk"),
            ETFTipConstituent(ticker: "SDIV", name: "Global X SuperDividend ETF", note: "High yield, declining NAV"),
            ETFTipConstituent(ticker: "MORT", name: "VanEck Mortgage REIT Income ETF", note: "Leveraged mREIT risk"),
            ETFTipConstituent(ticker: "PSEC", name: "Prospect Capital", note: "BDC with NAV discount"),
            ETFTipConstituent(ticker: "GOF", name: "Guggenheim Strategic Opportunities Fund", note: "Premium to NAV risk"),
        ]
    ),
]
