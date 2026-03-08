import XCTest
import SwiftData
@testable import Divvy

// MARK: - logPaymentTotal tests (pure, no SwiftData)

final class LogPaymentTotalTests: XCTestCase {

    func testSingleHoldingSingleShare() {
        let total = logPaymentTotal(sharesPerHolding: [1], amountPerShare: Decimal(string: "0.25")!)
        XCTAssertEqual(total, Decimal(string: "0.25")!)
    }

    func testSingleHoldingManyShares() {
        let total = logPaymentTotal(sharesPerHolding: [100], amountPerShare: Decimal(string: "0.25")!)
        XCTAssertEqual(total, Decimal(string: "25.00")!)
    }

    func testMultipleHoldingsSameAmountPerShare() {
        // 100 shares + 50 shares × $0.25 = $37.50
        let total = logPaymentTotal(sharesPerHolding: [100, 50], amountPerShare: Decimal(string: "0.25")!)
        XCTAssertEqual(total, Decimal(string: "37.50")!)
    }

    func testEmptyHoldingsProducesZero() {
        let total = logPaymentTotal(sharesPerHolding: [], amountPerShare: Decimal(string: "0.25")!)
        XCTAssertEqual(total, 0)
    }

    func testZeroShares() {
        // A holding with zero shares contributes nothing.
        let total = logPaymentTotal(sharesPerHolding: [0], amountPerShare: Decimal(string: "0.25")!)
        XCTAssertEqual(total, 0)
    }

    func testZeroAmountPerShare() {
        let total = logPaymentTotal(sharesPerHolding: [100, 50], amountPerShare: 0)
        XCTAssertEqual(total, 0)
    }

    func testDecimalPrecisionPreserved() {
        // Verify Decimal arithmetic never falls back to Double-style rounding.
        // Under Double: 3 × 0.10 = 0.30000000000000003; under Decimal: exactly 0.30.
        let total = logPaymentTotal(sharesPerHolding: [3], amountPerShare: Decimal(string: "0.10")!)
        XCTAssertEqual(total, Decimal(string: "0.30")!)
    }

    func testFractionalShares() {
        // 2.5 shares × $1.00 = $2.50
        let total = logPaymentTotal(sharesPerHolding: [Decimal(string: "2.5")!], amountPerShare: 1)
        XCTAssertEqual(total, Decimal(string: "2.50")!)
    }
}

// MARK: - DividendPayment model tests

final class DividendPaymentModelTests: XCTestCase {

    func testNetAmountSubtractsWithholdingTax() {
        let payment = DividendPayment(
            sharesAtTime:   100,
            totalAmount:    Decimal(string: "25.00")!,
            withholdingTax: Decimal(string: "2.50")!
        )
        XCTAssertEqual(payment.netAmount, Decimal(string: "22.50")!)
    }

    func testNetAmountEqualsGrossWhenNoWithholding() {
        let payment = DividendPayment(
            sharesAtTime: 100,
            totalAmount:  Decimal(string: "25.00")!
        )
        XCTAssertEqual(payment.netAmount, Decimal(string: "25.00")!)
    }

    func testNetAmountIsZeroWhenWithholdingEqualsTotalAmount() {
        // Withholdingequal to gross — net must be exactly 0, not negative.
        let payment = DividendPayment(
            sharesAtTime:   100,
            totalAmount:    Decimal(string: "10.00")!,
            withholdingTax: Decimal(string: "10.00")!
        )
        XCTAssertEqual(payment.netAmount, Decimal(0))
    }

    func testWithholdingExceedsTotalProducesNegativeNet() {
        // Documents that negative net is the current behaviour for malformed data.
        // The model does not clamp — callers are responsible for validation.
        let payment = DividendPayment(
            sharesAtTime:   100,
            totalAmount:    Decimal(string: "5.00")!,
            withholdingTax: Decimal(string: "10.00")!
        )
        XCTAssertLessThan(payment.netAmount, Decimal(0))
    }

    func testDefaultReinvestedIsFalse() {
        let payment = DividendPayment(sharesAtTime: 10, totalAmount: 1)
        XCTAssertFalse(payment.reinvested)
    }

    func testReinvestedCanBeSetTrue() {
        let payment = DividendPayment(sharesAtTime: 10, totalAmount: 1, reinvested: true)
        XCTAssertTrue(payment.reinvested)
    }
}

// MARK: - Holding.totalDividendsReceived integration tests
//
// All operations use container.mainContext so relationship graphs remain
// consistent within a single context — mixing contexts for relationship
// assignment is undefined behaviour in SwiftData.

@MainActor
final class HoldingPaymentHistoryTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.makeContainer(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    private var ctx: ModelContext { container.mainContext }

    /// Creates a Holding (with a unique ticker) in `container.mainContext`.
    private func makeHolding(shares: Decimal = 100, ticker: String = "AAPL") throws -> Holding {
        let stock = Stock(
            ticker: "\(ticker)-\(UUID().uuidString.prefix(6))",
            companyName: "Test Corp",
            currentPrice: 100
        )
        let holding = Holding(shares: shares, averageCostBasis: 100)
        holding.stock = stock
        ctx.insert(stock)
        ctx.insert(holding)
        try ctx.save()
        return holding
    }

    func testTotalDividendsReceivedStartsAtZero() throws {
        let holding = try makeHolding()
        XCTAssertEqual(holding.totalDividendsReceived, Decimal(0))
    }

    func testTotalDividendsReceivedAccumulatesPayments() throws {
        let holding = try makeHolding()

        let p1 = DividendPayment(sharesAtTime: 100, totalAmount: Decimal(string: "25.00")!)
        let p2 = DividendPayment(sharesAtTime: 100, totalAmount: Decimal(string: "25.00")!)
        p1.holding = holding
        p2.holding = holding
        ctx.insert(p1)
        ctx.insert(p2)
        try ctx.save()

        XCTAssertEqual(holding.totalDividendsReceived, Decimal(string: "50.00")!)
    }

    func testTotalDividendsReceivedUsesGrossNotNet() throws {
        // totalDividendsReceived sums `totalAmount` (gross), not `netAmount`.
        let holding = try makeHolding()

        let payment = DividendPayment(
            sharesAtTime:   100,
            totalAmount:    Decimal(string: "25.00")!,
            withholdingTax: Decimal(string: "2.50")!
        )
        payment.holding = holding
        ctx.insert(payment)
        try ctx.save()

        XCTAssertEqual(holding.totalDividendsReceived, Decimal(string: "25.00")!)
    }

    func testZeroAmountPaymentDoesNotCorruptTotal() throws {
        let holding = try makeHolding()

        let real = DividendPayment(sharesAtTime: 100, totalAmount: Decimal(string: "25.00")!)
        let zero = DividendPayment(sharesAtTime:   0, totalAmount: 0)
        real.holding = holding
        zero.holding = holding
        ctx.insert(real)
        ctx.insert(zero)
        try ctx.save()

        XCTAssertEqual(holding.totalDividendsReceived, Decimal(string: "25.00")!)
    }
}
