import Foundation

struct StockTipConstituent: Identifiable {
    let ticker: String
    let name: String
    let note: String
    var id: String { ticker }
}

struct StockTip: Identifiable {
    let name: String
    let description: String
    let category: String
    let riskLevel: String
    let examples: [StockTipConstituent]
    var id: String { name }
}

let builtInStockTips: [StockTip] = [
    StockTip(
        name: "Dividend Aristocrats",
        description: "S&P 500 companies that have increased dividends for 25+ consecutive years. These blue chips combine reliability with inflation-beating income growth.",
        category: "Dividend Growth",
        riskLevel: "Low",
        examples: [
            StockTipConstituent(ticker: "JNJ", name: "Johnson & Johnson", note: "60+ years of increases"),
            StockTipConstituent(ticker: "PG", name: "Procter & Gamble", note: "65+ years of increases"),
            StockTipConstituent(ticker: "KO", name: "Coca-Cola Company", note: "60+ years of increases"),
            StockTipConstituent(ticker: "MMM", name: "3M Company", note: "60+ years of increases"),
            StockTipConstituent(ticker: "ABT", name: "Abbott Laboratories", note: "50+ years of increases"),
        ]
    ),
    StockTip(
        name: "High Free Cash Flow",
        description: "Companies generating strong free cash flow relative to market cap. High FCF yield means the business earns more than enough to cover and grow its dividend safely.",
        category: "Value",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "ABBV", name: "AbbVie Inc.", note: "FCF yield ~8%"),
            StockTipConstituent(ticker: "MO", name: "Altria Group", note: "FCF yield ~9%"),
            StockTipConstituent(ticker: "T", name: "AT&T Inc.", note: "FCF yield ~10%"),
            StockTipConstituent(ticker: "VZ", name: "Verizon Communications", note: "FCF yield ~9%"),
            StockTipConstituent(ticker: "BTI", name: "British American Tobacco", note: "FCF yield ~10%"),
        ]
    ),
    StockTip(
        name: "Low Payout Ratio",
        description: "Look for payout ratios between 30-60%. A low payout ratio signals the company retains earnings for growth while still rewarding shareholders — with room to raise dividends.",
        category: "Safety",
        riskLevel: "Low",
        examples: [
            StockTipConstituent(ticker: "AAPL", name: "Apple Inc.", note: "Payout ratio ~15%"),
            StockTipConstituent(ticker: "MSFT", name: "Microsoft Corporation", note: "Payout ratio ~25%"),
            StockTipConstituent(ticker: "UNH", name: "UnitedHealth Group", note: "Payout ratio ~30%"),
            StockTipConstituent(ticker: "HD", name: "Home Depot", note: "Payout ratio ~50%"),
            StockTipConstituent(ticker: "TXN", name: "Texas Instruments", note: "Payout ratio ~55%"),
        ]
    ),
    StockTip(
        name: "Dividend Growth Leaders",
        description: "Stocks with the fastest dividend growth rates over the past 5 years. A 2% yield growing at 15% annually beats a static 5% yield within a decade through compounding.",
        category: "Dividend Growth",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "AVGO", name: "Broadcom Inc.", note: "~15% annual dividend growth"),
            StockTipConstituent(ticker: "COST", name: "Costco Wholesale", note: "~13% annual dividend growth"),
            StockTipConstituent(ticker: "LMT", name: "Lockheed Martin", note: "~10% annual dividend growth"),
            StockTipConstituent(ticker: "LOW", name: "Lowe's Companies", note: "~18% annual dividend growth"),
            StockTipConstituent(ticker: "V", name: "Visa Inc.", note: "~17% annual dividend growth"),
        ]
    ),
    StockTip(
        name: "Undervalued Yield",
        description: "High-yield stocks where the elevated yield comes from a price decline rather than fundamental deterioration. When the market overreacts, you get more income per dollar invested.",
        category: "Contrarian",
        riskLevel: "High",
        examples: [
            StockTipConstituent(ticker: "PFE", name: "Pfizer Inc.", note: "Post-COVID price decline"),
            StockTipConstituent(ticker: "WBA", name: "Walgreens Boots Alliance", note: "Retail headwinds"),
            StockTipConstituent(ticker: "BMY", name: "Bristol-Myers Squibb", note: "Patent cliff concerns"),
            StockTipConstituent(ticker: "MMM", name: "3M Company", note: "Litigation overhang"),
            StockTipConstituent(ticker: "INTC", name: "Intel Corporation", note: "Turnaround story"),
        ]
    ),
    StockTip(
        name: "Low Volatility Payers",
        description: "Stocks with low beta (under 0.8) and steady dividends. These defensive names hold up better in downturns, letting you sleep well while collecting reliable income.",
        category: "Defensive",
        riskLevel: "Low",
        examples: [
            StockTipConstituent(ticker: "WMT", name: "Walmart Inc.", note: "Beta ~0.5"),
            StockTipConstituent(ticker: "PEP", name: "PepsiCo Inc.", note: "Beta ~0.6"),
            StockTipConstituent(ticker: "CL", name: "Colgate-Palmolive", note: "Beta ~0.5"),
            StockTipConstituent(ticker: "SO", name: "Southern Company", note: "Beta ~0.4"),
            StockTipConstituent(ticker: "DUK", name: "Duke Energy", note: "Beta ~0.4"),
        ]
    ),
    StockTip(
        name: "New Dividend Initiators",
        description: "Companies that recently started paying dividends signal confidence in sustained earnings. Early-stage dividend payers often deliver the fastest subsequent dividend growth.",
        category: "Growth",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "META", name: "Meta Platforms", note: "Initiated 2024"),
            StockTipConstituent(ticker: "CRM", name: "Salesforce Inc.", note: "Initiated 2024"),
            StockTipConstituent(ticker: "GOOG", name: "Alphabet Inc.", note: "Initiated 2024"),
            StockTipConstituent(ticker: "BKNG", name: "Booking Holdings", note: "Initiated 2024"),
            StockTipConstituent(ticker: "NOW", name: "ServiceNow", note: "Potential initiator"),
        ]
    ),
    StockTip(
        name: "Preferred Stock Income",
        description: "Preferred shares pay fixed dividends with priority over common stock. They behave like bonds but trade on stock exchanges — ideal for stable income when rates are falling.",
        category: "Fixed Income",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "PFF", name: "iShares Preferred & Income ETF", note: "Diversified preferred basket"),
            StockTipConstituent(ticker: "PGX", name: "Invesco Preferred ETF", note: "Investment-grade focus"),
            StockTipConstituent(ticker: "FPE", name: "First Trust Preferred Securities ETF", note: "Active management"),
            StockTipConstituent(ticker: "PSK", name: "SPDR ICE Preferred Securities ETF", note: "Broad preferred exposure"),
            StockTipConstituent(ticker: "PFFD", name: "Global X US Preferred ETF", note: "Low-cost access"),
        ]
    ),
    StockTip(
        name: "Monthly Dividend Payers",
        description: "Most stocks pay quarterly, but some pay monthly — perfect for covering monthly bills or accelerating compounding with more frequent reinvestment.",
        category: "Income",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "O", name: "Realty Income Corporation", note: "The 'Monthly Dividend Company'"),
            StockTipConstituent(ticker: "MAIN", name: "Main Street Capital", note: "Monthly BDC dividends"),
            StockTipConstituent(ticker: "STAG", name: "STAG Industrial", note: "Monthly industrial REIT"),
            StockTipConstituent(ticker: "AGNC", name: "AGNC Investment Corp", note: "Monthly mortgage REIT"),
            StockTipConstituent(ticker: "LTC", name: "LTC Properties", note: "Monthly healthcare REIT"),
        ]
    ),
    StockTip(
        name: "Spin-Off Dividends",
        description: "Newly spun-off companies are often undervalued because institutional sellers must dump shares that don't fit their mandate. These orphaned stocks can offer hidden dividend value.",
        category: "Special Situations",
        riskLevel: "High",
        examples: [
            StockTipConstituent(ticker: "KHC", name: "Kraft Heinz Company", note: "Kraft Foods spin-off"),
            StockTipConstituent(ticker: "WBD", name: "Warner Bros. Discovery", note: "AT&T spin-off"),
            StockTipConstituent(ticker: "OGN", name: "Organon & Co.", note: "Merck spin-off"),
            StockTipConstituent(ticker: "VTRS", name: "Viatris Inc.", note: "Pfizer/Mylan merger"),
            StockTipConstituent(ticker: "SOLV", name: "Solventum Corporation", note: "3M healthcare spin-off"),
        ]
    ),
    StockTip(
        name: "Debt-Free Dividends",
        description: "Companies with zero or minimal debt paying dividends are the safest income picks. No debt means no interest burden — every dollar of cash flow goes to operations and shareholders.",
        category: "Safety",
        riskLevel: "Low",
        examples: [
            StockTipConstituent(ticker: "GOOG", name: "Alphabet Inc.", note: "Net cash position"),
            StockTipConstituent(ticker: "AAPL", name: "Apple Inc.", note: "Minimal net debt"),
            StockTipConstituent(ticker: "PAYX", name: "Paychex Inc.", note: "Nearly debt-free"),
            StockTipConstituent(ticker: "EXPD", name: "Expeditors International", note: "Zero long-term debt"),
            StockTipConstituent(ticker: "SEIC", name: "SEI Investments", note: "No long-term debt"),
        ]
    ),
    StockTip(
        name: "Wide Moat Dividends",
        description: "Companies with durable competitive advantages — brands, network effects, switching costs, patents — can sustain pricing power and dividends for decades.",
        category: "Quality",
        riskLevel: "Low",
        examples: [
            StockTipConstituent(ticker: "MSFT", name: "Microsoft Corporation", note: "Enterprise software moat"),
            StockTipConstituent(ticker: "V", name: "Visa Inc.", note: "Payment network moat"),
            StockTipConstituent(ticker: "UNP", name: "Union Pacific", note: "Railroad monopoly moat"),
            StockTipConstituent(ticker: "WM", name: "Waste Management", note: "Landfill permit moat"),
            StockTipConstituent(ticker: "BRO", name: "Brown & Brown", note: "Insurance distribution moat"),
        ]
    ),
    StockTip(
        name: "REIT Income Plays",
        description: "Real Estate Investment Trusts must distribute 90% of taxable income. This legal requirement makes them among the most reliable dividend payers — backed by real property assets.",
        category: "Income",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "O", name: "Realty Income Corporation", note: "Triple-net retail REIT"),
            StockTipConstituent(ticker: "AMT", name: "American Tower", note: "Cell tower REIT"),
            StockTipConstituent(ticker: "PSA", name: "Public Storage", note: "Self-storage REIT"),
            StockTipConstituent(ticker: "DLR", name: "Digital Realty Trust", note: "Data center REIT"),
            StockTipConstituent(ticker: "VICI", name: "VICI Properties", note: "Casino property REIT"),
        ]
    ),
    StockTip(
        name: "Covered Call Enhancement",
        description: "Stocks with high options volume and moderate volatility are great for selling covered calls. You collect dividend income plus options premium — doubling your yield.",
        category: "Options Strategy",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "AAPL", name: "Apple Inc.", note: "Highly liquid options chain"),
            StockTipConstituent(ticker: "INTC", name: "Intel Corporation", note: "High implied volatility"),
            StockTipConstituent(ticker: "T", name: "AT&T Inc.", note: "Range-bound + high yield"),
            StockTipConstituent(ticker: "F", name: "Ford Motor Company", note: "Active weekly options"),
            StockTipConstituent(ticker: "QYLD", name: "Global X NASDAQ 100 Covered Call", note: "Automated covered calls"),
        ]
    ),
    StockTip(
        name: "Recession-Proof Income",
        description: "Essential services people pay regardless of the economy: water, electricity, garbage collection, healthcare. These stocks maintained or grew dividends through 2008 and 2020.",
        category: "Defensive",
        riskLevel: "Low",
        examples: [
            StockTipConstituent(ticker: "AWK", name: "American Water Works", note: "Water utility"),
            StockTipConstituent(ticker: "WM", name: "Waste Management", note: "Waste collection"),
            StockTipConstituent(ticker: "NEE", name: "NextEra Energy", note: "Regulated utility"),
            StockTipConstituent(ticker: "WMT", name: "Walmart Inc.", note: "Essential retail"),
            StockTipConstituent(ticker: "JNJ", name: "Johnson & Johnson", note: "Healthcare staple"),
        ]
    ),
    StockTip(
        name: "Special Dividend History",
        description: "Some companies pay surprise special dividends when cash accumulates. Tracking companies with a history of specials can unlock bonus income beyond the regular payout.",
        category: "Special Situations",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "COST", name: "Costco Wholesale", note: "Multiple special dividends"),
            StockTipConstituent(ticker: "LRCX", name: "Lam Research", note: "Periodic special payouts"),
            StockTipConstituent(ticker: "CINF", name: "Cincinnati Financial", note: "Occasional specials"),
            StockTipConstituent(ticker: "WSO", name: "Watsco Inc.", note: "History of specials"),
            StockTipConstituent(ticker: "EXPD", name: "Expeditors International", note: "Periodic special dividends"),
        ]
    ),
    StockTip(
        name: "Yield on Cost Strategy",
        description: "Buy stocks with modest yields but high dividend growth. A 2% yield growing at 12% per year becomes a 6% yield on your original cost in 10 years — the power of compounding.",
        category: "Dividend Growth",
        riskLevel: "Low",
        examples: [
            StockTipConstituent(ticker: "V", name: "Visa Inc.", note: "~1% yield, ~17% growth"),
            StockTipConstituent(ticker: "HD", name: "Home Depot", note: "~2.5% yield, ~10% growth"),
            StockTipConstituent(ticker: "AVGO", name: "Broadcom Inc.", note: "~2% yield, ~15% growth"),
            StockTipConstituent(ticker: "LOW", name: "Lowe's Companies", note: "~2% yield, ~18% growth"),
            StockTipConstituent(ticker: "UNH", name: "UnitedHealth Group", note: "~1.5% yield, ~14% growth"),
        ]
    ),
    StockTip(
        name: "International ADR Income",
        description: "American Depositary Receipts let you buy foreign dividend stocks on US exchanges. Some pay higher yields than US peers, but watch for foreign withholding taxes.",
        category: "International",
        riskLevel: "Moderate",
        examples: [
            StockTipConstituent(ticker: "UL", name: "Unilever PLC", note: "UK — no withholding tax"),
            StockTipConstituent(ticker: "NVS", name: "Novartis AG", note: "Swiss pharma giant"),
            StockTipConstituent(ticker: "TM", name: "Toyota Motor Corp", note: "Japanese auto leader"),
            StockTipConstituent(ticker: "SHEL", name: "Shell PLC", note: "UK — no withholding tax"),
            StockTipConstituent(ticker: "RIO", name: "Rio Tinto Group", note: "Australian miner"),
        ]
    ),
    StockTip(
        name: "BDC High Yielders",
        description: "Business Development Companies lend to mid-market firms and must distribute 90% of income. Yields of 8-12% are common, but credit risk is higher — diversify across several BDCs.",
        category: "High Yield",
        riskLevel: "High",
        examples: [
            StockTipConstituent(ticker: "ARCC", name: "Ares Capital Corporation", note: "Largest BDC by assets"),
            StockTipConstituent(ticker: "MAIN", name: "Main Street Capital", note: "Monthly payer, internal mgmt"),
            StockTipConstituent(ticker: "HTGC", name: "Hercules Capital", note: "Tech-focused lending"),
            StockTipConstituent(ticker: "BXSL", name: "Blackstone Secured Lending", note: "Senior secured loans"),
            StockTipConstituent(ticker: "CSWC", name: "Capital Southwest", note: "Lower middle market"),
        ]
    ),
    StockTip(
        name: "Payout Ratio Warning Signs",
        description: "Avoid stocks with payout ratios above 90% (except REITs and BDCs). Unsustainably high payouts often precede dividend cuts. Check earnings and FCF coverage before buying.",
        category: "Risk Management",
        riskLevel: "Educational",
        examples: [
            StockTipConstituent(ticker: "VZ", name: "Verizon Communications", note: "Watch capex vs FCF"),
            StockTipConstituent(ticker: "T", name: "AT&T Inc.", note: "Cut dividend in 2022"),
            StockTipConstituent(ticker: "LUMN", name: "Lumen Technologies", note: "Suspended dividend 2023"),
            StockTipConstituent(ticker: "IVZ", name: "Invesco Ltd.", note: "High payout, AUM-dependent"),
            StockTipConstituent(ticker: "WBA", name: "Walgreens Boots Alliance", note: "Cut dividend 2024"),
        ]
    ),
]
