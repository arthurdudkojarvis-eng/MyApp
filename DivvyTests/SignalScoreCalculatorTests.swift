import XCTest
@testable import Divvy

@MainActor
final class SignalScoreCalculatorTests: XCTestCase {

    // MARK: - Component Isolation

    func testYieldComponent_normalYield_scoresInRange() {
        // 3% yield should be in the 2–4% band → score 40–70
        let score = SignalScoreCalculator.scoreYield(Decimal(string: "3.0")!)
        XCTAssertGreaterThanOrEqual(score, 40)
        XCTAssertLessThanOrEqual(score, 70)
    }

    func testYieldComponent_yieldTrap_penalized() {
        // 10% yield (> 8% threshold) → score == 20
        let score = SignalScoreCalculator.scoreYield(Decimal(string: "10.0")!)
        XCTAssertEqual(score, 20)
    }

    func testPayoutSafety_lowPayout_fullScore() {
        // 45% payout ratio → 100 (0–60% band)
        let score = SignalScoreCalculator.scorePayoutRatio(Decimal(string: "45.0")!)
        XCTAssertEqual(score, 100)
    }

    func testPayoutSafety_unsustainable_zeroScore() {
        // 120% payout ratio → 0 (> 100%)
        let score = SignalScoreCalculator.scorePayoutRatio(Decimal(string: "120.0")!)
        XCTAssertEqual(score, 0)
    }

    func testAnalystConsensus_allStrongBuy_maxScore() {
        let rec = FinnhubRecommendation(
            buy: 0, hold: 0, sell: 0, strongBuy: 10, strongSell: 0, period: "2025-01-01"
        )
        let score = SignalScoreCalculator.scoreAnalystConsensus(rec)
        XCTAssertEqual(score, 100)
    }

    // MARK: - Edge Cases

    func testMissingInputs_fewerThan3Components_returnsNil() {
        // Only yield + payout = 2 components < 3 minimum
        let inputs = SignalInputs(
            dividendYield: Decimal(string: "3.0"),
            payoutRatio: Decimal(string: "50.0"),
            dividendGrowthYears: nil,
            analystCounts: nil,
            dailyCloses: []
        )
        let result = SignalScoreCalculator.calculate(from: inputs)
        XCTAssertNil(result)
    }

    func testMissingInputs_exactly3Components_returnsScore() {
        // yield + payout + growth = exactly 3 components
        let inputs = SignalInputs(
            dividendYield: Decimal(string: "3.0"),
            payoutRatio: Decimal(string: "50.0"),
            dividendGrowthYears: 5,
            analystCounts: nil,
            dailyCloses: []
        )
        let result = SignalScoreCalculator.calculate(from: inputs)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.breakdown.count, 3)
    }

    func testWeightReNormalization_excludedComponent_weightsRedistributed() {
        // Provide 4 of 5 components (no volatility) — result should still be valid 0–100
        let rec = FinnhubRecommendation(
            buy: 5, hold: 3, sell: 1, strongBuy: 2, strongSell: 0, period: "2025-01-01"
        )
        let inputs = SignalInputs(
            dividendYield: Decimal(string: "3.5"),
            payoutRatio: Decimal(string: "40.0"),
            dividendGrowthYears: 7,
            analystCounts: rec,
            dailyCloses: [] // not enough for volatility
        )
        let result = SignalScoreCalculator.calculate(from: inputs)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.value, 0)
        XCTAssertLessThanOrEqual(result!.value, 100)
        // Volatility should be excluded
        XCTAssertNil(result!.breakdown[.historicalVolatility])
        XCTAssertEqual(result!.breakdown.count, 4)
    }

    func testVolatility_fewerThan20DataPoints_excluded() {
        // Only 10 data points → volatility excluded
        let closes = (1...10).map { Decimal($0 * 10) }
        let score = SignalScoreCalculator.scoreVolatility(closes)
        XCTAssertNil(score)
    }

    // MARK: - Full Composite

    func testFullInputs_allPositive_highConfidence() {
        // Strong metrics across the board → score >= 70
        let rec = FinnhubRecommendation(
            buy: 8, hold: 2, sell: 0, strongBuy: 5, strongSell: 0, period: "2025-01-01"
        )
        // Generate 30 close prices with low volatility (stable growth)
        let closes = (0..<30).map { Decimal(100 + $0) }
        let inputs = SignalInputs(
            dividendYield: Decimal(string: "3.5"),
            payoutRatio: Decimal(string: "40.0"),
            dividendGrowthYears: 12,
            analystCounts: rec,
            dailyCloses: closes
        )
        let result = SignalScoreCalculator.calculate(from: inputs)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.value, 70)
        XCTAssertEqual(result!.confidence, .high)
        XCTAssertEqual(result!.breakdown.count, 5)
    }

    func testFullInputs_poorMetrics_lowConfidence() {
        // Weak metrics → score < 40
        let rec = FinnhubRecommendation(
            buy: 0, hold: 1, sell: 5, strongBuy: 0, strongSell: 8, period: "2025-01-01"
        )
        // Generate 30 close prices with high volatility
        var closes: [Decimal] = []
        for i in 0..<30 {
            closes.append(i % 2 == 0 ? Decimal(100) : Decimal(60))
        }
        let inputs = SignalInputs(
            dividendYield: Decimal(string: "0.5"),
            payoutRatio: Decimal(string: "110.0"),
            dividendGrowthYears: 0,
            analystCounts: rec,
            dailyCloses: closes
        )
        let result = SignalScoreCalculator.calculate(from: inputs)
        XCTAssertNotNil(result)
        XCTAssertLessThan(result!.value, 40)
        XCTAssertEqual(result!.confidence, .low)
    }

    func testConfidenceThresholds_exactly70_isHigh() {
        // Confidence is a computed property: value >= 70 → .high
        let score = SignalScore(value: 70, breakdown: [:])
        XCTAssertEqual(score.confidence, .high)

        // Verify via calculator with strong inputs
        let rec = FinnhubRecommendation(
            buy: 10, hold: 0, sell: 0, strongBuy: 0, strongSell: 0, period: "2025-01-01"
        )
        let inputs = SignalInputs(
            dividendYield: Decimal(string: "4.5"),
            payoutRatio: Decimal(string: "50.0"),
            dividendGrowthYears: 6,
            analystCounts: rec,
            dailyCloses: []
        )
        let result = SignalScoreCalculator.calculate(from: inputs)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.value, 70)
        XCTAssertEqual(result!.confidence, .high)
    }

    func testConfidenceThresholds_exactly40_isMedium() {
        // Confidence is a computed property: 40-69 → .medium
        let score = SignalScore(value: 40, breakdown: [:])
        XCTAssertEqual(score.confidence, .medium)

        // Also verify boundary: 39 → .low
        let lowScore = SignalScore(value: 39, breakdown: [:])
        XCTAssertEqual(lowScore.confidence, .low)

        // Build inputs that land in medium range
        let rec = FinnhubRecommendation(
            buy: 2, hold: 5, sell: 3, strongBuy: 0, strongSell: 1, period: "2025-01-01"
        )
        let inputs = SignalInputs(
            dividendYield: Decimal(string: "1.5"),
            payoutRatio: Decimal(string: "70.0"),
            dividendGrowthYears: 2,
            analystCounts: rec,
            dailyCloses: []
        )
        let result = SignalScoreCalculator.calculate(from: inputs)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.value, 40)
        XCTAssertLessThan(result!.value, 70)
        XCTAssertEqual(result!.confidence, .medium)
    }

    // MARK: - Dividend Growth

    func testGrowthStreak_zeroYears_zeroScore() {
        let score = SignalScoreCalculator.scoreGrowthYears(0)
        XCTAssertEqual(score, 0)
    }

    func testGrowthStreak_tenPlusYears_maxScore() {
        let score10 = SignalScoreCalculator.scoreGrowthYears(10)
        XCTAssertEqual(score10, 100)

        let score25 = SignalScoreCalculator.scoreGrowthYears(25)
        XCTAssertEqual(score25, 100)
    }
}
