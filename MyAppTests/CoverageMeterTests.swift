import XCTest
@testable import MyApp

/// Tests for `CoverageMetrics` — the pure value-type that owns
/// the coverage ratio arithmetic used by `CoverageMeterView`.
final class CoverageMeterTests: XCTestCase {

    // MARK: - hasTarget

    func testHasTargetFalseWhenZero() {
        XCTAssertFalse(CoverageMetrics(monthlyEquivalent: 1000, monthlyExpenseTarget: 0).hasTarget)
    }

    func testHasTargetTrueWhenPositive() {
        XCTAssertTrue(CoverageMetrics(monthlyEquivalent: 0, monthlyExpenseTarget: 2000).hasTarget)
    }

    // MARK: - coverageRatio (Decimal)

    func testCoverageRatioAtFiftyPercent() {
        let m = CoverageMetrics(monthlyEquivalent: 1000, monthlyExpenseTarget: 2000)
        XCTAssertEqual(m.coverageRatio, Decimal(string: "0.5")!)
    }

    func testCoverageRatioExactlyFull() {
        let m = CoverageMetrics(monthlyEquivalent: 2000, monthlyExpenseTarget: 2000)
        XCTAssertEqual(m.coverageRatio, 1)
    }

    func testCoverageRatioAbove100Percent() {
        let m = CoverageMetrics(monthlyEquivalent: 2540, monthlyExpenseTarget: 2000)
        XCTAssertEqual(m.coverageRatio, Decimal(string: "1.27")!)
    }

    func testCoverageRatioZeroIncome() {
        let m = CoverageMetrics(monthlyEquivalent: 0, monthlyExpenseTarget: 2000)
        XCTAssertEqual(m.coverageRatio, 0)
    }

    func testCoverageRatioZeroTargetReturnsZero() {
        // Guard path — denominator is 0; must not divide by zero
        let m = CoverageMetrics(monthlyEquivalent: 1000, monthlyExpenseTarget: 0)
        XCTAssertEqual(m.coverageRatio, 0)
    }

    func testCoverageRatioNegativeIncomeClampedAtDisplay() {
        // Negative income (data anomaly) produces a negative ratio.
        // The clamp in clampedProgressValue handles display, but the ratio itself is negative.
        let m = CoverageMetrics(monthlyEquivalent: -50, monthlyExpenseTarget: 200)
        XCTAssertLessThan(m.coverageRatio, 0)
    }

    // MARK: - clampedProgressValue (Double for ProgressView)

    func testClampedValueBelowOne() {
        let m = CoverageMetrics(monthlyEquivalent: 1000, monthlyExpenseTarget: 2000)
        XCTAssertEqual(m.clampedProgressValue, 0.5, accuracy: 0.0001)
    }

    func testClampedValueExactlyOne() {
        let m = CoverageMetrics(monthlyEquivalent: 2000, monthlyExpenseTarget: 2000)
        XCTAssertEqual(m.clampedProgressValue, 1.0, accuracy: 0.0001)
    }

    func testClampedValueAbove100PercentIsClampedToOne() {
        let m = CoverageMetrics(monthlyEquivalent: 3000, monthlyExpenseTarget: 2000)
        XCTAssertEqual(m.clampedProgressValue, 1.0, accuracy: 0.0001)
    }

    func testClampedValueZeroIncome() {
        let m = CoverageMetrics(monthlyEquivalent: 0, monthlyExpenseTarget: 2000)
        XCTAssertEqual(m.clampedProgressValue, 0.0, accuracy: 0.0001)
    }

    func testClampedValueNegativeIncomeIsZero() {
        // Negative income should clamp to 0.0, never go negative in the progress bar
        let m = CoverageMetrics(monthlyEquivalent: -50, monthlyExpenseTarget: 200)
        XCTAssertEqual(m.clampedProgressValue, 0.0, accuracy: 0.0001)
    }

    func testClampedValueZeroTarget() {
        let m = CoverageMetrics(monthlyEquivalent: 1000, monthlyExpenseTarget: 0)
        XCTAssertEqual(m.clampedProgressValue, 0.0, accuracy: 0.0001)
    }

    // MARK: - Coverage percent label
    // Pin locale to en_US so tests don't fail on non-English CI runners.

    func testPercentLabelOneDecimalPlace() {
        let m = CoverageMetrics(
            monthlyEquivalent: Decimal(string: "1468")!,
            monthlyExpenseTarget: Decimal(string: "2000")!
        )
        let label = m.coverageRatio.formatted(
            .percent.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))
        )
        XCTAssertEqual(label, "73.4%")
    }

    func testPercentLabelAbove100() {
        let m = CoverageMetrics(
            monthlyEquivalent: Decimal(string: "2540")!,
            monthlyExpenseTarget: Decimal(string: "2000")!
        )
        let label = m.coverageRatio.formatted(
            .percent.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))
        )
        XCTAssertEqual(label, "127.0%")
    }

    func testPercentLabelExact100() {
        let m = CoverageMetrics(monthlyEquivalent: 2000, monthlyExpenseTarget: 2000)
        let label = m.coverageRatio.formatted(
            .percent.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))
        )
        XCTAssertEqual(label, "100.0%")
    }
}
