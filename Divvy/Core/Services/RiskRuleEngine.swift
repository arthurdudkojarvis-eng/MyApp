import Foundation

// MARK: - Risk Types

enum RiskSeverity: Int, CaseIterable, Comparable {
    case low = 0, medium = 1, high = 2, critical = 3

    var label: String {
        switch self {
        case .low:      "LOW"
        case .medium:   "MEDIUM"
        case .high:     "HIGH"
        case .critical: "CRITICAL"
        }
    }

    static func < (lhs: RiskSeverity, rhs: RiskSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct RiskInputs {
    let payoutRatio: Decimal?
    let dividendYield: Decimal?
    let revenueGrowthYoY: Decimal?
    let debtToEquity: Decimal?
    let eps: Decimal?
    let dividendGrowthStreak: Int?
}

struct RiskFactor: Identifiable {
    let id: String
    let title: String
    let description: String
    let severity: RiskSeverity
}

struct RiskRule {
    let id: String
    let title: String
    let description: String
    let severity: RiskSeverity
    let evaluate: (RiskInputs) -> Bool
}

// MARK: - Rule Engine

struct RiskRuleEngine {
    static let rules: [RiskRule] = [
        RiskRule(
            id: "R01",
            title: "Unsustainable Payout Ratio",
            description: "The company is paying out more in dividends than it earns, which may not be sustainable long-term.",
            severity: .critical,
            evaluate: { inputs in
                guard let ratio = inputs.payoutRatio else { return false }
                return ratio > 100
            }
        ),
        RiskRule(
            id: "R02",
            title: "Elevated Payout Ratio",
            description: "The payout ratio is above 80%, leaving limited room for dividend growth or earnings decline.",
            severity: .high,
            evaluate: { inputs in
                guard let ratio = inputs.payoutRatio else { return false }
                return ratio > 80 && ratio <= 100
            }
        ),
        RiskRule(
            id: "R03",
            title: "Potential Yield Trap",
            description: "An unusually high dividend yield may signal that the market expects a dividend cut.",
            severity: .high,
            evaluate: { inputs in
                guard let yield = inputs.dividendYield else { return false }
                return yield > 8
            }
        ),
        RiskRule(
            id: "R04",
            title: "Revenue Decline",
            description: "Revenue has declined more than 10% year-over-year, which could pressure future dividend payments.",
            severity: .high,
            evaluate: { inputs in
                guard let growth = inputs.revenueGrowthYoY else { return false }
                return growth < -10
            }
        ),
        RiskRule(
            id: "R05",
            title: "High Financial Leverage",
            description: "The debt-to-equity ratio exceeds 2.0, indicating elevated financial risk.",
            severity: .medium,
            evaluate: { inputs in
                guard let dte = inputs.debtToEquity else { return false }
                return dte > 2
            }
        ),
        RiskRule(
            id: "R06",
            title: "Dividend Under Pressure",
            description: "A high payout ratio combined with declining revenue suggests the dividend may be at risk.",
            severity: .high,
            evaluate: { inputs in
                guard let ratio = inputs.payoutRatio,
                      let growth = inputs.revenueGrowthYoY else { return false }
                return ratio > 60 && growth < 0
            }
        ),
        RiskRule(
            id: "R07",
            title: "Negative Earnings",
            description: "The company is reporting negative earnings per share, making dividend payments harder to sustain.",
            severity: .critical,
            evaluate: { inputs in
                guard let eps = inputs.eps else { return false }
                return eps < 0
            }
        ),
        RiskRule(
            id: "R08",
            title: "No Dividend Growth Track Record",
            description: "The company has no history of consecutive dividend increases.",
            severity: .low,
            evaluate: { inputs in
                guard let streak = inputs.dividendGrowthStreak else { return false }
                return streak == 0
            }
        ),
    ]

    static func evaluate(_ inputs: RiskInputs) -> [RiskFactor] {
        rules.compactMap { rule in
            guard rule.evaluate(inputs) else { return nil }
            return RiskFactor(
                id: rule.id,
                title: rule.title,
                description: rule.description,
                severity: rule.severity
            )
        }
    }
}
