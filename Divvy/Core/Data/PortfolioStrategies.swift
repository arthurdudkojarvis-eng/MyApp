import Foundation

struct StrategyConstituent: Identifiable {
    let ticker: String
    let name: String
    let allocationPercent: Double
    var id: String { ticker }
}

struct DividendStrategy: Identifiable {
    let name: String
    let description: String
    let riskProfile: String
    let expectedYieldRange: String
    let constituents: [StrategyConstituent]
    var id: String { name }
}

let builtInStrategies: [DividendStrategy] = [
    DividendStrategy(
        name: "Dogs of the Dow",
        description: "Buy the 10 highest-yielding stocks in the Dow Jones Industrial Average at the start of each year. This classic income strategy targets large-cap blue chips with above-average yields.",
        riskProfile: "Moderate",
        expectedYieldRange: "3-5%",
        constituents: [
            StrategyConstituent(ticker: "VZ", name: "Verizon Communications", allocationPercent: 10),
            StrategyConstituent(ticker: "DOW", name: "Dow Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "IBM", name: "International Business Machines", allocationPercent: 10),
            StrategyConstituent(ticker: "CVX", name: "Chevron Corporation", allocationPercent: 10),
            StrategyConstituent(ticker: "AMGN", name: "Amgen Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "MRK", name: "Merck & Co.", allocationPercent: 10),
            StrategyConstituent(ticker: "CSCO", name: "Cisco Systems", allocationPercent: 10),
            StrategyConstituent(ticker: "JNJ", name: "Johnson & Johnson", allocationPercent: 10),
            StrategyConstituent(ticker: "KO", name: "Coca-Cola Company", allocationPercent: 10),
            StrategyConstituent(ticker: "MMM", name: "3M Company", allocationPercent: 10),
        ]
    ),
    DividendStrategy(
        name: "All Weather Portfolio",
        description: "Ray Dalio's all-weather allocation adapted for income investors using low-cost ETFs. Designed to perform in any economic environment with balanced asset classes.",
        riskProfile: "Conservative",
        expectedYieldRange: "2-3%",
        constituents: [
            StrategyConstituent(ticker: "VTI", name: "Vanguard Total Stock Market ETF", allocationPercent: 30),
            StrategyConstituent(ticker: "TLT", name: "iShares 20+ Year Treasury Bond ETF", allocationPercent: 40),
            StrategyConstituent(ticker: "IEI", name: "iShares 3-7 Year Treasury Bond ETF", allocationPercent: 15),
            StrategyConstituent(ticker: "GLD", name: "SPDR Gold Shares", allocationPercent: 7),
            StrategyConstituent(ticker: "DBC", name: "Invesco DB Commodity Index", allocationPercent: 8),
        ]
    ),
    DividendStrategy(
        name: "High Yield Aristocrats",
        description: "Top-yielding S&P 500 Dividend Aristocrats — companies that have increased dividends for 25+ consecutive years. Combines income with dividend growth reliability.",
        riskProfile: "Moderate-Low",
        expectedYieldRange: "3-6%",
        constituents: [
            StrategyConstituent(ticker: "T", name: "AT&T Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "ABBV", name: "AbbVie Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "XOM", name: "Exxon Mobil Corporation", allocationPercent: 10),
            StrategyConstituent(ticker: "O", name: "Realty Income Corporation", allocationPercent: 10),
            StrategyConstituent(ticker: "PFE", name: "Pfizer Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "KMI", name: "Kinder Morgan", allocationPercent: 10),
            StrategyConstituent(ticker: "WBA", name: "Walgreens Boots Alliance", allocationPercent: 10),
            StrategyConstituent(ticker: "BEN", name: "Franklin Resources", allocationPercent: 10),
            StrategyConstituent(ticker: "LEG", name: "Leggett & Platt", allocationPercent: 10),
            StrategyConstituent(ticker: "FRT", name: "Federal Realty Investment", allocationPercent: 10),
        ]
    ),
    DividendStrategy(
        name: "Dividend Kings",
        description: "Companies that have raised dividends for 50+ consecutive years. The ultimate dividend reliability — these businesses have survived recessions, wars, and market crashes while never cutting their payout.",
        riskProfile: "Conservative",
        expectedYieldRange: "2-4%",
        constituents: [
            StrategyConstituent(ticker: "PG", name: "Procter & Gamble", allocationPercent: 10),
            StrategyConstituent(ticker: "KO", name: "Coca-Cola Company", allocationPercent: 10),
            StrategyConstituent(ticker: "JNJ", name: "Johnson & Johnson", allocationPercent: 10),
            StrategyConstituent(ticker: "CL", name: "Colgate-Palmolive", allocationPercent: 10),
            StrategyConstituent(ticker: "EMR", name: "Emerson Electric", allocationPercent: 10),
            StrategyConstituent(ticker: "PH", name: "Parker-Hannifin", allocationPercent: 10),
            StrategyConstituent(ticker: "SWK", name: "Stanley Black & Decker", allocationPercent: 10),
            StrategyConstituent(ticker: "LOW", name: "Lowe's Companies", allocationPercent: 10),
            StrategyConstituent(ticker: "TGT", name: "Target Corporation", allocationPercent: 10),
            StrategyConstituent(ticker: "GPC", name: "Genuine Parts Company", allocationPercent: 10),
        ]
    ),
    DividendStrategy(
        name: "REIT Income",
        description: "Real Estate Investment Trusts are required by law to distribute 90% of taxable income as dividends. This portfolio targets diversified REITs across property types for steady rental income.",
        riskProfile: "Moderate",
        expectedYieldRange: "4-7%",
        constituents: [
            StrategyConstituent(ticker: "O", name: "Realty Income Corporation", allocationPercent: 12),
            StrategyConstituent(ticker: "VICI", name: "VICI Properties", allocationPercent: 12),
            StrategyConstituent(ticker: "AMT", name: "American Tower", allocationPercent: 10),
            StrategyConstituent(ticker: "SPG", name: "Simon Property Group", allocationPercent: 10),
            StrategyConstituent(ticker: "PSA", name: "Public Storage", allocationPercent: 10),
            StrategyConstituent(ticker: "DLR", name: "Digital Realty Trust", allocationPercent: 10),
            StrategyConstituent(ticker: "WPC", name: "W. P. Carey", allocationPercent: 10),
            StrategyConstituent(ticker: "STAG", name: "STAG Industrial", allocationPercent: 10),
            StrategyConstituent(ticker: "NNN", name: "NNN REIT", allocationPercent: 8),
            StrategyConstituent(ticker: "MPW", name: "Medical Properties Trust", allocationPercent: 8),
        ]
    ),
    DividendStrategy(
        name: "Utility Staples",
        description: "Utilities provide essential services with regulated revenue streams. This defensive portfolio focuses on electric, gas, and water utilities known for stable dividends even during recessions.",
        riskProfile: "Conservative",
        expectedYieldRange: "3-5%",
        constituents: [
            StrategyConstituent(ticker: "NEE", name: "NextEra Energy", allocationPercent: 15),
            StrategyConstituent(ticker: "DUK", name: "Duke Energy", allocationPercent: 12),
            StrategyConstituent(ticker: "SO", name: "Southern Company", allocationPercent: 12),
            StrategyConstituent(ticker: "D", name: "Dominion Energy", allocationPercent: 12),
            StrategyConstituent(ticker: "AEP", name: "American Electric Power", allocationPercent: 10),
            StrategyConstituent(ticker: "XEL", name: "Xcel Energy", allocationPercent: 10),
            StrategyConstituent(ticker: "WEC", name: "WEC Energy Group", allocationPercent: 10),
            StrategyConstituent(ticker: "AWK", name: "American Water Works", allocationPercent: 10),
            StrategyConstituent(ticker: "ED", name: "Consolidated Edison", allocationPercent: 9),
        ]
    ),
    DividendStrategy(
        name: "Energy Income",
        description: "Oil, gas, and midstream energy companies with strong cash flows and generous shareholder returns. Higher risk due to commodity price sensitivity, but offers compelling yields.",
        riskProfile: "Moderate-High",
        expectedYieldRange: "4-8%",
        constituents: [
            StrategyConstituent(ticker: "XOM", name: "Exxon Mobil Corporation", allocationPercent: 15),
            StrategyConstituent(ticker: "CVX", name: "Chevron Corporation", allocationPercent: 15),
            StrategyConstituent(ticker: "EPD", name: "Enterprise Products Partners", allocationPercent: 12),
            StrategyConstituent(ticker: "ET", name: "Energy Transfer", allocationPercent: 12),
            StrategyConstituent(ticker: "KMI", name: "Kinder Morgan", allocationPercent: 10),
            StrategyConstituent(ticker: "WMB", name: "Williams Companies", allocationPercent: 10),
            StrategyConstituent(ticker: "OKE", name: "ONEOK Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "MPC", name: "Marathon Petroleum", allocationPercent: 8),
            StrategyConstituent(ticker: "PSX", name: "Phillips 66", allocationPercent: 8),
        ]
    ),
    DividendStrategy(
        name: "Healthcare Dividends",
        description: "Pharmaceutical and healthcare companies with strong moats, aging-population tailwinds, and consistent dividend growth. Blends large-cap pharma with medical devices.",
        riskProfile: "Moderate",
        expectedYieldRange: "2-4%",
        constituents: [
            StrategyConstituent(ticker: "JNJ", name: "Johnson & Johnson", allocationPercent: 15),
            StrategyConstituent(ticker: "ABBV", name: "AbbVie Inc.", allocationPercent: 15),
            StrategyConstituent(ticker: "PFE", name: "Pfizer Inc.", allocationPercent: 12),
            StrategyConstituent(ticker: "MRK", name: "Merck & Co.", allocationPercent: 12),
            StrategyConstituent(ticker: "BMY", name: "Bristol-Myers Squibb", allocationPercent: 10),
            StrategyConstituent(ticker: "MDT", name: "Medtronic", allocationPercent: 10),
            StrategyConstituent(ticker: "ABT", name: "Abbott Laboratories", allocationPercent: 10),
            StrategyConstituent(ticker: "AMGN", name: "Amgen Inc.", allocationPercent: 8),
            StrategyConstituent(ticker: "GILD", name: "Gilead Sciences", allocationPercent: 8),
        ]
    ),
    DividendStrategy(
        name: "Consumer Staples Shield",
        description: "Everyday essentials companies — food, beverages, household products — that consumers buy regardless of the economy. A classic recession-proof dividend strategy.",
        riskProfile: "Conservative",
        expectedYieldRange: "2-4%",
        constituents: [
            StrategyConstituent(ticker: "PG", name: "Procter & Gamble", allocationPercent: 14),
            StrategyConstituent(ticker: "KO", name: "Coca-Cola Company", allocationPercent: 12),
            StrategyConstituent(ticker: "PEP", name: "PepsiCo Inc.", allocationPercent: 12),
            StrategyConstituent(ticker: "WMT", name: "Walmart Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "COST", name: "Costco Wholesale", allocationPercent: 10),
            StrategyConstituent(ticker: "CL", name: "Colgate-Palmolive", allocationPercent: 10),
            StrategyConstituent(ticker: "KMB", name: "Kimberly-Clark", allocationPercent: 8),
            StrategyConstituent(ticker: "GIS", name: "General Mills", allocationPercent: 8),
            StrategyConstituent(ticker: "HSY", name: "Hershey Company", allocationPercent: 8),
            StrategyConstituent(ticker: "MO", name: "Altria Group", allocationPercent: 8),
        ]
    ),
    DividendStrategy(
        name: "Financials Income",
        description: "Banks, insurers, and asset managers that generate strong cash flows and return capital via dividends. Benefits from rising interest rates and economic growth.",
        riskProfile: "Moderate-High",
        expectedYieldRange: "3-5%",
        constituents: [
            StrategyConstituent(ticker: "JPM", name: "JPMorgan Chase", allocationPercent: 15),
            StrategyConstituent(ticker: "BAC", name: "Bank of America", allocationPercent: 12),
            StrategyConstituent(ticker: "WFC", name: "Wells Fargo", allocationPercent: 10),
            StrategyConstituent(ticker: "BLK", name: "BlackRock Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "MS", name: "Morgan Stanley", allocationPercent: 10),
            StrategyConstituent(ticker: "USB", name: "U.S. Bancorp", allocationPercent: 10),
            StrategyConstituent(ticker: "PNC", name: "PNC Financial Services", allocationPercent: 8),
            StrategyConstituent(ticker: "TFC", name: "Truist Financial", allocationPercent: 8),
            StrategyConstituent(ticker: "MET", name: "MetLife Inc.", allocationPercent: 8),
            StrategyConstituent(ticker: "PRU", name: "Prudential Financial", allocationPercent: 9),
        ]
    ),
    DividendStrategy(
        name: "Tech Dividend Growth",
        description: "Technology companies that have matured into reliable dividend payers. Lower current yields but strong dividend growth rates and capital appreciation potential.",
        riskProfile: "Moderate",
        expectedYieldRange: "1-3%",
        constituents: [
            StrategyConstituent(ticker: "AAPL", name: "Apple Inc.", allocationPercent: 15),
            StrategyConstituent(ticker: "MSFT", name: "Microsoft Corporation", allocationPercent: 15),
            StrategyConstituent(ticker: "AVGO", name: "Broadcom Inc.", allocationPercent: 12),
            StrategyConstituent(ticker: "TXN", name: "Texas Instruments", allocationPercent: 12),
            StrategyConstituent(ticker: "CSCO", name: "Cisco Systems", allocationPercent: 10),
            StrategyConstituent(ticker: "IBM", name: "International Business Machines", allocationPercent: 10),
            StrategyConstituent(ticker: "QCOM", name: "Qualcomm Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "HPQ", name: "HP Inc.", allocationPercent: 8),
            StrategyConstituent(ticker: "INTC", name: "Intel Corporation", allocationPercent: 8),
        ]
    ),
    DividendStrategy(
        name: "Monthly Payers",
        description: "Stocks and REITs that pay dividends monthly instead of quarterly. Ideal for investors who want regular cash flow to cover monthly expenses or reinvest more frequently.",
        riskProfile: "Moderate",
        expectedYieldRange: "4-8%",
        constituents: [
            StrategyConstituent(ticker: "O", name: "Realty Income Corporation", allocationPercent: 15),
            StrategyConstituent(ticker: "STAG", name: "STAG Industrial", allocationPercent: 12),
            StrategyConstituent(ticker: "MAIN", name: "Main Street Capital", allocationPercent: 12),
            StrategyConstituent(ticker: "AGNC", name: "AGNC Investment Corp", allocationPercent: 10),
            StrategyConstituent(ticker: "SLG", name: "SL Green Realty", allocationPercent: 10),
            StrategyConstituent(ticker: "LTC", name: "LTC Properties", allocationPercent: 10),
            StrategyConstituent(ticker: "GLAD", name: "Gladstone Capital", allocationPercent: 8),
            StrategyConstituent(ticker: "GOOD", name: "Gladstone Commercial", allocationPercent: 8),
            StrategyConstituent(ticker: "EPR", name: "EPR Properties", allocationPercent: 8),
            StrategyConstituent(ticker: "LAND", name: "Gladstone Land", allocationPercent: 7),
        ]
    ),
    DividendStrategy(
        name: "International Dividends",
        description: "US-listed ADRs and ETFs providing exposure to high-yielding international companies. Geographic diversification with the convenience of trading on US exchanges.",
        riskProfile: "Moderate-High",
        expectedYieldRange: "3-6%",
        constituents: [
            StrategyConstituent(ticker: "VYMI", name: "Vanguard Intl High Dividend Yield ETF", allocationPercent: 20),
            StrategyConstituent(ticker: "UL", name: "Unilever PLC", allocationPercent: 12),
            StrategyConstituent(ticker: "BTI", name: "British American Tobacco", allocationPercent: 10),
            StrategyConstituent(ticker: "NVS", name: "Novartis AG", allocationPercent: 10),
            StrategyConstituent(ticker: "TM", name: "Toyota Motor Corp", allocationPercent: 10),
            StrategyConstituent(ticker: "RIO", name: "Rio Tinto Group", allocationPercent: 10),
            StrategyConstituent(ticker: "SHEL", name: "Shell PLC", allocationPercent: 10),
            StrategyConstituent(ticker: "BP", name: "BP PLC", allocationPercent: 8),
            StrategyConstituent(ticker: "GSK", name: "GSK PLC", allocationPercent: 10),
        ]
    ),
    DividendStrategy(
        name: "Small-Cap Dividend",
        description: "Smaller companies with established dividend histories. Higher growth potential than large-caps with more volatility. Targets small-caps with sustainable payout ratios.",
        riskProfile: "High",
        expectedYieldRange: "2-5%",
        constituents: [
            StrategyConstituent(ticker: "NNN", name: "NNN REIT", allocationPercent: 12),
            StrategyConstituent(ticker: "OHI", name: "Omega Healthcare Investors", allocationPercent: 12),
            StrategyConstituent(ticker: "SBRA", name: "Sabra Health Care REIT", allocationPercent: 10),
            StrategyConstituent(ticker: "UVV", name: "Universal Corporation", allocationPercent: 10),
            StrategyConstituent(ticker: "SON", name: "Sonoco Products", allocationPercent: 10),
            StrategyConstituent(ticker: "NWN", name: "Northwest Natural Holding", allocationPercent: 10),
            StrategyConstituent(ticker: "WDFC", name: "WD-40 Company", allocationPercent: 8),
            StrategyConstituent(ticker: "BANF", name: "BancFirst Corporation", allocationPercent: 8),
            StrategyConstituent(ticker: "CSWC", name: "Capital Southwest", allocationPercent: 10),
            StrategyConstituent(ticker: "HBAN", name: "Huntington Bancshares", allocationPercent: 10),
        ]
    ),
    DividendStrategy(
        name: "Dividend ETF Core",
        description: "A simple, low-maintenance approach using dividend-focused ETFs. Maximum diversification with minimal stock-picking. Ideal for hands-off investors.",
        riskProfile: "Moderate-Low",
        expectedYieldRange: "2-4%",
        constituents: [
            StrategyConstituent(ticker: "VYM", name: "Vanguard High Dividend Yield ETF", allocationPercent: 20),
            StrategyConstituent(ticker: "SCHD", name: "Schwab US Dividend Equity ETF", allocationPercent: 20),
            StrategyConstituent(ticker: "HDV", name: "iShares Core High Dividend ETF", allocationPercent: 15),
            StrategyConstituent(ticker: "DGRO", name: "iShares Core Dividend Growth ETF", allocationPercent: 15),
            StrategyConstituent(ticker: "DVY", name: "iShares Select Dividend ETF", allocationPercent: 15),
            StrategyConstituent(ticker: "SDY", name: "SPDR S&P Dividend ETF", allocationPercent: 15),
        ]
    ),
    DividendStrategy(
        name: "Retirement Income 60/40",
        description: "Classic 60% stocks / 40% bonds allocation tilted toward income-producing assets. Designed for retirees who need current income with lower volatility than an all-equity portfolio.",
        riskProfile: "Conservative",
        expectedYieldRange: "3-5%",
        constituents: [
            StrategyConstituent(ticker: "SCHD", name: "Schwab US Dividend Equity ETF", allocationPercent: 30),
            StrategyConstituent(ticker: "VYM", name: "Vanguard High Dividend Yield ETF", allocationPercent: 30),
            StrategyConstituent(ticker: "BND", name: "Vanguard Total Bond Market ETF", allocationPercent: 20),
            StrategyConstituent(ticker: "VCIT", name: "Vanguard Intermediate-Term Corp Bond ETF", allocationPercent: 10),
            StrategyConstituent(ticker: "TIP", name: "iShares TIPS Bond ETF", allocationPercent: 10),
        ]
    ),
    DividendStrategy(
        name: "Telecom & Media Income",
        description: "Telecommunications and media companies with strong recurring revenue from subscriptions and advertising. Mature industry with generous cash returns to shareholders.",
        riskProfile: "Moderate",
        expectedYieldRange: "4-7%",
        constituents: [
            StrategyConstituent(ticker: "VZ", name: "Verizon Communications", allocationPercent: 20),
            StrategyConstituent(ticker: "T", name: "AT&T Inc.", allocationPercent: 20),
            StrategyConstituent(ticker: "CMCSA", name: "Comcast Corporation", allocationPercent: 15),
            StrategyConstituent(ticker: "TMUS", name: "T-Mobile US", allocationPercent: 15),
            StrategyConstituent(ticker: "BCE", name: "BCE Inc.", allocationPercent: 15),
            StrategyConstituent(ticker: "IPG", name: "Interpublic Group", allocationPercent: 15),
        ]
    ),
    DividendStrategy(
        name: "Industrial Dividends",
        description: "Industrial conglomerates, aerospace, and defense companies with long dividend histories. Benefits from infrastructure spending, defense budgets, and global trade.",
        riskProfile: "Moderate",
        expectedYieldRange: "2-3%",
        constituents: [
            StrategyConstituent(ticker: "CAT", name: "Caterpillar Inc.", allocationPercent: 12),
            StrategyConstituent(ticker: "RTX", name: "RTX Corporation", allocationPercent: 12),
            StrategyConstituent(ticker: "LMT", name: "Lockheed Martin", allocationPercent: 12),
            StrategyConstituent(ticker: "HON", name: "Honeywell International", allocationPercent: 12),
            StrategyConstituent(ticker: "UPS", name: "United Parcel Service", allocationPercent: 10),
            StrategyConstituent(ticker: "DE", name: "Deere & Company", allocationPercent: 10),
            StrategyConstituent(ticker: "EMR", name: "Emerson Electric", allocationPercent: 10),
            StrategyConstituent(ticker: "ITW", name: "Illinois Tool Works", allocationPercent: 10),
            StrategyConstituent(ticker: "GD", name: "General Dynamics", allocationPercent: 12),
        ]
    ),
    DividendStrategy(
        name: "BDC High Income",
        description: "Business Development Companies lend to mid-market businesses and are required to distribute 90% of income. Very high yields with higher risk — suited for income-focused investors who accept volatility.",
        riskProfile: "High",
        expectedYieldRange: "8-12%",
        constituents: [
            StrategyConstituent(ticker: "MAIN", name: "Main Street Capital", allocationPercent: 15),
            StrategyConstituent(ticker: "ARCC", name: "Ares Capital Corporation", allocationPercent: 15),
            StrategyConstituent(ticker: "HTGC", name: "Hercules Capital", allocationPercent: 12),
            StrategyConstituent(ticker: "CSWC", name: "Capital Southwest", allocationPercent: 10),
            StrategyConstituent(ticker: "GBDC", name: "Golub Capital BDC", allocationPercent: 10),
            StrategyConstituent(ticker: "TPVG", name: "TriplePoint Venture Growth", allocationPercent: 10),
            StrategyConstituent(ticker: "BXSL", name: "Blackstone Secured Lending", allocationPercent: 10),
            StrategyConstituent(ticker: "PSEC", name: "Prospect Capital", allocationPercent: 8),
            StrategyConstituent(ticker: "NEWT", name: "Newtek Business Services", allocationPercent: 10),
        ]
    ),
    DividendStrategy(
        name: "Warren Buffett Dividends",
        description: "Top dividend-paying holdings from Berkshire Hathaway's public equity portfolio. Buffett's investment philosophy favors businesses with durable competitive advantages and strong cash generation.",
        riskProfile: "Moderate",
        expectedYieldRange: "2-4%",
        constituents: [
            StrategyConstituent(ticker: "KO", name: "Coca-Cola Company", allocationPercent: 15),
            StrategyConstituent(ticker: "CVX", name: "Chevron Corporation", allocationPercent: 15),
            StrategyConstituent(ticker: "KHC", name: "Kraft Heinz Company", allocationPercent: 12),
            StrategyConstituent(ticker: "OXY", name: "Occidental Petroleum", allocationPercent: 12),
            StrategyConstituent(ticker: "HPQ", name: "HP Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "PARA", name: "Paramount Global", allocationPercent: 8),
            StrategyConstituent(ticker: "USB", name: "U.S. Bancorp", allocationPercent: 10),
            StrategyConstituent(ticker: "BAC", name: "Bank of America", allocationPercent: 10),
            StrategyConstituent(ticker: "AAPL", name: "Apple Inc.", allocationPercent: 8),
        ]
    ),
    DividendStrategy(
        name: "Materials & Mining",
        description: "Mining, metals, and materials companies that generate strong free cash flow during commodity upcycles. Cyclical but with generous dividends tied to commodity prices.",
        riskProfile: "High",
        expectedYieldRange: "3-7%",
        constituents: [
            StrategyConstituent(ticker: "RIO", name: "Rio Tinto Group", allocationPercent: 15),
            StrategyConstituent(ticker: "BHP", name: "BHP Group", allocationPercent: 15),
            StrategyConstituent(ticker: "NUE", name: "Nucor Corporation", allocationPercent: 12),
            StrategyConstituent(ticker: "APD", name: "Air Products & Chemicals", allocationPercent: 12),
            StrategyConstituent(ticker: "LIN", name: "Linde PLC", allocationPercent: 10),
            StrategyConstituent(ticker: "ECL", name: "Ecolab Inc.", allocationPercent: 10),
            StrategyConstituent(ticker: "NEM", name: "Newmont Corporation", allocationPercent: 10),
            StrategyConstituent(ticker: "FCX", name: "Freeport-McMoRan", allocationPercent: 8),
            StrategyConstituent(ticker: "DD", name: "DuPont de Nemours", allocationPercent: 8),
        ]
    ),
]
