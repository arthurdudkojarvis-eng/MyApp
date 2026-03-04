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
        expectedYieldRange: "3%–5%",
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
        expectedYieldRange: "2%–3%",
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
        expectedYieldRange: "3%–6%",
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
]
