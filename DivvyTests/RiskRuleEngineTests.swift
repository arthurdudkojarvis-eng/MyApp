import XCTest
@testable import Divvy

final class RiskRuleEngineTests: XCTestCase {

    // MARK: - Helpers

    private func inputs(
        payoutRatio: Decimal? = nil,
        dividendYield: Decimal? = nil,
        revenueGrowthYoY: Decimal? = nil,
        debtToEquity: Decimal? = nil,
        eps: Decimal? = nil,
        dividendGrowthStreak: Int? = nil
    ) -> RiskInputs {
        RiskInputs(
            payoutRatio: payoutRatio,
            dividendYield: dividendYield,
            revenueGrowthYoY: revenueGrowthYoY,
            debtToEquity: debtToEquity,
            eps: eps,
            dividendGrowthStreak: dividendGrowthStreak
        )
    }

    private func riskIDs(_ factors: [RiskFactor]) -> Set<String> {
        Set(factors.map(\.id))
    }

    // MARK: - R01: Unsustainable Payout Ratio (> 100%)

    func testR01_payoutAbove100_triggersCritical() {
        let factors = RiskRuleEngine.evaluate(inputs(payoutRatio: 120))
        XCTAssertTrue(riskIDs(factors).contains("R01"))
        XCTAssertEqual(factors.first { $0.id == "R01" }?.severity, .critical)
    }

    func testR01_payoutExactly100_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(payoutRatio: 100))
        XCTAssertFalse(riskIDs(factors).contains("R01"))
    }

    // MARK: - R02: Elevated Payout Ratio (80–100%)

    func testR02_payout85_triggersHigh() {
        let factors = RiskRuleEngine.evaluate(inputs(payoutRatio: 85))
        XCTAssertTrue(riskIDs(factors).contains("R02"))
        XCTAssertEqual(factors.first { $0.id == "R02" }?.severity, .high)
    }

    func testR02_payout80_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(payoutRatio: 80))
        XCTAssertFalse(riskIDs(factors).contains("R02"))
    }

    func testR02_doesNotTriggerWhenR01Fires() {
        // Payout 120% → R01 fires, R02 must NOT fire (exclusive ranges)
        let factors = RiskRuleEngine.evaluate(inputs(payoutRatio: 120))
        XCTAssertTrue(riskIDs(factors).contains("R01"))
        XCTAssertFalse(riskIDs(factors).contains("R02"))
    }

    // MARK: - R03: Potential Yield Trap (> 8%)

    func testR03_yieldAbove8_triggersHigh() {
        let factors = RiskRuleEngine.evaluate(inputs(dividendYield: 9))
        XCTAssertTrue(riskIDs(factors).contains("R03"))
        XCTAssertEqual(factors.first { $0.id == "R03" }?.severity, .high)
    }

    func testR03_yieldExactly8_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(dividendYield: 8))
        XCTAssertFalse(riskIDs(factors).contains("R03"))
    }

    // MARK: - R04: Revenue Decline (< -10%)

    func testR04_revenueDrop15_triggersHigh() {
        let factors = RiskRuleEngine.evaluate(inputs(revenueGrowthYoY: -15))
        XCTAssertTrue(riskIDs(factors).contains("R04"))
        XCTAssertEqual(factors.first { $0.id == "R04" }?.severity, .high)
    }

    func testR04_revenueDrop10_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(revenueGrowthYoY: -10))
        XCTAssertFalse(riskIDs(factors).contains("R04"))
    }

    // MARK: - R05: High Financial Leverage (D/E > 2.0)

    func testR05_debtToEquityAbove2_triggersMedium() {
        let factors = RiskRuleEngine.evaluate(inputs(debtToEquity: Decimal(string: "2.5")!))
        XCTAssertTrue(riskIDs(factors).contains("R05"))
        XCTAssertEqual(factors.first { $0.id == "R05" }?.severity, .medium)
    }

    func testR05_debtToEquityExactly2_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(debtToEquity: 2))
        XCTAssertFalse(riskIDs(factors).contains("R05"))
    }

    // MARK: - R06: Dividend Under Pressure (payout > 60 && revenue < 0)

    func testR06_highPayoutAndNegativeRevenue_triggersHigh() {
        let factors = RiskRuleEngine.evaluate(inputs(payoutRatio: 70, revenueGrowthYoY: -5))
        XCTAssertTrue(riskIDs(factors).contains("R06"))
        XCTAssertEqual(factors.first { $0.id == "R06" }?.severity, .high)
    }

    func testR06_highPayoutButPositiveRevenue_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(payoutRatio: 70, revenueGrowthYoY: 5))
        XCTAssertFalse(riskIDs(factors).contains("R06"))
    }

    func testR06_lowPayoutAndNegativeRevenue_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(payoutRatio: 50, revenueGrowthYoY: -5))
        XCTAssertFalse(riskIDs(factors).contains("R06"))
    }

    // MARK: - R07: Negative Earnings (EPS < 0)

    func testR07_negativeEPS_triggersCritical() {
        let factors = RiskRuleEngine.evaluate(inputs(eps: Decimal(string: "-1.50")!))
        XCTAssertTrue(riskIDs(factors).contains("R07"))
        XCTAssertEqual(factors.first { $0.id == "R07" }?.severity, .critical)
    }

    func testR07_zeroEPS_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(eps: 0))
        XCTAssertFalse(riskIDs(factors).contains("R07"))
    }

    func testR07_positiveEPS_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(eps: Decimal(string: "2.50")!))
        XCTAssertFalse(riskIDs(factors).contains("R07"))
    }

    // MARK: - R08: No Dividend Growth Track Record (streak == 0)

    func testR08_zeroStreak_triggersLow() {
        let factors = RiskRuleEngine.evaluate(inputs(dividendGrowthStreak: 0))
        XCTAssertTrue(riskIDs(factors).contains("R08"))
        XCTAssertEqual(factors.first { $0.id == "R08" }?.severity, .low)
    }

    func testR08_positiveStreak_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(dividendGrowthStreak: 5))
        XCTAssertFalse(riskIDs(factors).contains("R08"))
    }

    func testR08_nilStreak_doesNotTrigger() {
        let factors = RiskRuleEngine.evaluate(inputs(dividendGrowthStreak: nil))
        XCTAssertFalse(riskIDs(factors).contains("R08"))
    }

    // MARK: - Edge Cases

    func testAllNilInputs_returnsNoRisks() {
        let factors = RiskRuleEngine.evaluate(inputs())
        XCTAssertTrue(factors.isEmpty)
    }

    func testMultipleRulesCanFireSimultaneously() {
        // Negative EPS (R07) + high yield (R03) + no growth (R08)
        let factors = RiskRuleEngine.evaluate(inputs(
            dividendYield: 10,
            eps: Decimal(string: "-0.50")!,
            dividendGrowthStreak: 0
        ))
        let ids = riskIDs(factors)
        XCTAssertTrue(ids.contains("R03"))
        XCTAssertTrue(ids.contains("R07"))
        XCTAssertTrue(ids.contains("R08"))
    }

    func testCleanFundamentals_returnsNoRisks() {
        // Healthy company: moderate payout, reasonable yield, growing revenue, low leverage, positive EPS, growth streak
        let factors = RiskRuleEngine.evaluate(inputs(
            payoutRatio: 45,
            dividendYield: Decimal(string: "3.5")!,
            revenueGrowthYoY: 8,
            debtToEquity: Decimal(string: "0.8")!,
            eps: Decimal(string: "4.25")!,
            dividendGrowthStreak: 10
        ))
        XCTAssertTrue(factors.isEmpty)
    }

    // MARK: - Severity Ordering

    func testSeverityComparable_correctOrder() {
        XCTAssertTrue(RiskSeverity.low < RiskSeverity.medium)
        XCTAssertTrue(RiskSeverity.medium < RiskSeverity.high)
        XCTAssertTrue(RiskSeverity.high < RiskSeverity.critical)
    }

    // MARK: - Factor Properties

    func testAllFactorsHaveUniqueIDs() {
        // Fire everything possible
        let factors = RiskRuleEngine.evaluate(inputs(
            payoutRatio: 120,
            dividendYield: 10,
            revenueGrowthYoY: -20,
            debtToEquity: 3,
            eps: Decimal(string: "-1.0")!,
            dividendGrowthStreak: 0
        ))
        let ids = factors.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Risk factor IDs should be unique")
    }
}
