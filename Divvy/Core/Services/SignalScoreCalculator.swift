import Foundation

// MARK: - Types

enum SignalComponent: String, CaseIterable {
    case dividendYield
    case payoutSafety
    case dividendGrowth
    case analystConsensus
    case historicalVolatility
}

enum SignalScoreWeights {
    static let dividendYield: Decimal = Decimal(string: "0.20")!
    static let payoutSafety: Decimal = Decimal(string: "0.25")!
    static let dividendGrowth: Decimal = Decimal(string: "0.20")!
    static let analystConsensus: Decimal = Decimal(string: "0.20")!
    static let historicalVolatility: Decimal = Decimal(string: "0.15")!
    static let yieldTrapThreshold: Decimal = 8
    static let minimumComponents = 3
}

enum Confidence: String {
    case high, medium, low
}

struct SignalInputs {
    let dividendYield: Decimal?
    let payoutRatio: Decimal?
    let dividendGrowthYears: Int?
    let analystCounts: FinnhubRecommendation?
    let dailyCloses: [Decimal]
}

struct SignalScore {
    let value: Int
    let breakdown: [SignalComponent: Int]

    var confidence: Confidence {
        if value >= 70 { return .high }
        if value >= 40 { return .medium }
        return .low
    }
}

// MARK: - Calculator

struct SignalScoreCalculator {

    static func calculate(from inputs: SignalInputs) -> SignalScore? {
        var breakdown: [SignalComponent: Int] = [:]
        var weights: [SignalComponent: Decimal] = [:]

        // 1. Dividend Yield
        if let yield = inputs.dividendYield {
            breakdown[.dividendYield] = scoreYield(yield)
            weights[.dividendYield] = SignalScoreWeights.dividendYield
        }

        // 2. Payout Safety
        if let ratio = inputs.payoutRatio {
            breakdown[.payoutSafety] = scorePayoutRatio(ratio)
            weights[.payoutSafety] = SignalScoreWeights.payoutSafety
        }

        // 3. Dividend Growth
        if let years = inputs.dividendGrowthYears {
            breakdown[.dividendGrowth] = scoreGrowthYears(years)
            weights[.dividendGrowth] = SignalScoreWeights.dividendGrowth
        }

        // 4. Analyst Consensus
        if let rec = inputs.analystCounts {
            let buyCount = rec.strongBuy + rec.buy
            let sellCount = rec.sell + rec.strongSell
            let totalCount = buyCount + rec.hold + sellCount
            if totalCount > 0 {
                breakdown[.analystConsensus] = scoreAnalystConsensus(rec)
                weights[.analystConsensus] = SignalScoreWeights.analystConsensus
            }
        }

        // 5. Historical Volatility
        if let volScore = scoreVolatility(inputs.dailyCloses) {
            breakdown[.historicalVolatility] = volScore
            weights[.historicalVolatility] = SignalScoreWeights.historicalVolatility
        }

        // Require at least 3 components
        guard breakdown.count >= SignalScoreWeights.minimumComponents else { return nil }

        // Re-normalize weights
        let totalWeight = weights.values.reduce(Decimal.zero, +)
        guard totalWeight > 0 else { return nil }

        var weightedSum: Decimal = 0
        for (component, score) in breakdown {
            guard let w = weights[component] else { continue }
            let normalizedWeight = w / totalWeight
            weightedSum += Decimal(score) * normalizedWeight
        }

        let finalValue = min(100, max(0, Int(NSDecimalNumber(decimal: weightedSum).doubleValue)))

        return SignalScore(value: finalValue, breakdown: breakdown)
    }

    // MARK: - Component Scoring

    static func scoreYield(_ yield: Decimal) -> Int {
        if yield <= 0 { return 0 }
        if yield > SignalScoreWeights.yieldTrapThreshold { return 20 }

        // 6–8%: linear scale 80 → 60 (diminishing — approaching trap)
        if yield > 6 {
            let fraction = (yield - 6) / 2 // 0 at 6%, 1 at 8%
            let score = 80 - fraction * 20  // 80 → 60
            return Int(NSDecimalNumber(decimal: score).doubleValue)
        }

        // 4–6%: linear scale 70 → 100
        if yield >= 4 {
            let fraction = (yield - 4) / 2
            let score = 70 + fraction * 30
            return Int(NSDecimalNumber(decimal: score).doubleValue)
        }

        // 2–4%: linear scale 40 → 70
        if yield >= 2 {
            let fraction = (yield - 2) / 2
            let score = 40 + fraction * 30
            return Int(NSDecimalNumber(decimal: score).doubleValue)
        }

        // 0–2%: linear scale 20 → 40
        let fraction = yield / 2
        let score = 20 + fraction * 20
        return Int(NSDecimalNumber(decimal: score).doubleValue)
    }

    static func scorePayoutRatio(_ ratio: Decimal) -> Int {
        if ratio < 0 { return 0 }
        if ratio > 100 { return 0 }
        if ratio > 80 { return 30 }
        if ratio > 60 { return 60 }
        return 100
    }

    static func scoreGrowthYears(_ years: Int) -> Int {
        if years >= 10 { return 100 }
        if years >= 5 { return 75 }
        if years >= 3 { return 50 }
        if years >= 1 { return 30 }
        return 0
    }

    static func scoreAnalystConsensus(_ rec: FinnhubRecommendation) -> Int {
        let buyCount = rec.strongBuy + rec.buy
        let sellCount = rec.sell + rec.strongSell
        let totalCount = buyCount + rec.hold + sellCount
        guard totalCount > 0 else { return 0 }

        let sbWeight = Double(rec.strongBuy) * 1.0
        let bWeight = Double(rec.buy) * 0.75
        let hWeight = Double(rec.hold) * 0.5
        let sWeight = Double(rec.sell) * 0.25
        let ssWeight = Double(rec.strongSell) * 0.0
        let weightedSum = sbWeight + bWeight + hWeight + sWeight + ssWeight

        let weightedAvg = weightedSum / Double(totalCount)
        return Int((weightedAvg * 100).rounded())
    }

    static func scoreVolatility(_ closes: [Decimal]) -> Int? {
        guard closes.count >= 20 else { return nil }

        // Compute daily log returns
        var logReturns: [Decimal] = []
        logReturns.reserveCapacity(closes.count - 1)

        for i in 1..<closes.count {
            guard closes[i - 1] > 0 else { continue }
            let ratio = Double(truncating: closes[i] as NSDecimalNumber)
                / Double(truncating: closes[i - 1] as NSDecimalNumber)
            guard ratio > 0 else { continue }
            let lr = Decimal(Foundation.log(ratio))
            logReturns.append(lr)
        }

        guard !logReturns.isEmpty else { return nil }

        let dailyStdDev = standardDeviation(logReturns)
        // Annualize: stdDev * sqrt(252)
        let sqrt252 = Decimal(Foundation.sqrt(252.0))
        let annualizedVol = dailyStdDev * sqrt252 * 100 // as percentage

        if annualizedVol > 40 { return 10 }
        if annualizedVol > 25 { return 40 }
        if annualizedVol > 15 { return 70 }
        return 100
    }

    // MARK: - Math Helpers

    private static func standardDeviation(_ values: [Decimal]) -> Decimal {
        guard values.count > 1 else { return 0 }
        let count = Decimal(values.count)
        let mean = values.reduce(Decimal.zero, +) / count
        let sumSquaredDiffs = values.reduce(Decimal.zero) { acc, val in
            let diff = val - mean
            return acc + diff * diff
        }
        let variance = sumSquaredDiffs / (count - 1)
        // sqrt via Double conversion
        let varianceDouble = Double(truncating: variance as NSDecimalNumber)
        return Decimal(Foundation.sqrt(varianceDouble))
    }
}
