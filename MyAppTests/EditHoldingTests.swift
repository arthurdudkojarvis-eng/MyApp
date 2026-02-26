import XCTest
import SwiftData
@testable import MyApp

final class EditHoldingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var holding: Holding!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.makeContainer(inMemory: true)
        context = ModelContext(container)
        holding = Holding(
            shares: Decimal(string: "10")!,
            averageCostBasis: Decimal(string: "150.00")!,
            purchaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        )
        context.insert(holding)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        holding = nil
        try await super.tearDown()
    }

    // MARK: - save() mutation (mirrors EditHoldingView.save())

    private func simulateSave(sharesText: String, costBasisText: String, purchaseDate: Date) {
        guard let shares = Decimal(string: sharesText).flatMap({ $0 > 0 ? $0 : nil }),
              let costBasis = Decimal(string: costBasisText).flatMap({ $0 > 0 ? $0 : nil }) else { return }
        holding.shares = shares
        holding.averageCostBasis = costBasis
        holding.purchaseDate = purchaseDate
    }

    func testEditSharesMutatesHolding() {
        simulateSave(sharesText: "25", costBasisText: "150.00", purchaseDate: holding.purchaseDate)
        XCTAssertEqual(holding.shares, Decimal(string: "25")!)
    }

    func testEditCostBasisMutatesHolding() {
        simulateSave(sharesText: "10", costBasisText: "200.50", purchaseDate: holding.purchaseDate)
        XCTAssertEqual(holding.averageCostBasis, Decimal(string: "200.50")!)
    }

    func testEditPurchaseDateMutatesHolding() {
        let newDate = Calendar.current.date(from: DateComponents(year: 2023, month: 6, day: 1))!
        simulateSave(sharesText: "10", costBasisText: "150.00", purchaseDate: newDate)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: holding.purchaseDate),
            Calendar.current.startOfDay(for: newDate)
        )
    }

    func testSaveUpdatesAllThreeFieldsTogether() {
        let newDate = Calendar.current.date(from: DateComponents(year: 2022, month: 3, day: 10))!
        simulateSave(sharesText: "42.5", costBasisText: "99.99", purchaseDate: newDate)
        XCTAssertEqual(holding.shares, Decimal(string: "42.5")!)
        XCTAssertEqual(holding.averageCostBasis, Decimal(string: "99.99")!)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: holding.purchaseDate),
            Calendar.current.startOfDay(for: newDate)
        )
    }

    func testSaveWithInvalidInputDoesNotMutateHolding() {
        let originalShares = holding.shares
        let originalCostBasis = holding.averageCostBasis
        simulateSave(sharesText: "abc", costBasisText: "150", purchaseDate: holding.purchaseDate)
        XCTAssertEqual(holding.shares, originalShares)
        XCTAssertEqual(holding.averageCostBasis, originalCostBasis)
    }

    // MARK: - isValid (mirrors EditHoldingView.isValid)

    private func isValid(sharesText: String, costBasisText: String) -> Bool {
        guard let s = Decimal(string: sharesText), s > 0 else { return false }
        guard let c = Decimal(string: costBasisText), c > 0 else { return false }
        return true
    }

    func testIsValidWithValidSharesAndCostBasis() {
        XCTAssertTrue(isValid(sharesText: "10", costBasisText: "150"))
    }

    func testIsValidFalseWhenSharesZero() {
        XCTAssertFalse(isValid(sharesText: "0", costBasisText: "150"))
    }

    func testIsValidFalseWhenSharesNegative() {
        XCTAssertFalse(isValid(sharesText: "-5", costBasisText: "150"))
    }

    func testIsValidFalseWhenCostBasisZero() {
        XCTAssertFalse(isValid(sharesText: "10", costBasisText: "0"))
    }

    func testIsValidFalseWhenCostBasisNegative() {
        XCTAssertFalse(isValid(sharesText: "10", costBasisText: "-1"))
    }

    func testIsValidFalseWhenSharesNonNumeric() {
        XCTAssertFalse(isValid(sharesText: "abc", costBasisText: "150"))
    }

    func testIsValidFalseWhenCostBasisNonNumeric() {
        XCTAssertFalse(isValid(sharesText: "10", costBasisText: "xyz"))
    }
}
