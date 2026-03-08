import XCTest
@testable import Divvy

final class StockBrowserFilterTests: XCTestCase {

    // MARK: - MarketCapRange.matches

    func testAnyMatchesEverything() {
        XCTAssertTrue(MarketCapRange.any.matches(marketCap: nil))
        XCTAssertTrue(MarketCapRange.any.matches(marketCap: 0))
        XCTAssertTrue(MarketCapRange.any.matches(marketCap: 1_000_000_000_000))
    }

    func testNilMarketCapOnlyMatchesAny() {
        for range in MarketCapRange.allCases where range != .any {
            XCTAssertFalse(range.matches(marketCap: nil), "\(range) should not match nil")
        }
    }

    // MARK: - Mega: >= 200B

    func testMegaBoundary() {
        XCTAssertTrue(MarketCapRange.mega.matches(marketCap: 200_000_000_000))
        XCTAssertTrue(MarketCapRange.mega.matches(marketCap: 500_000_000_000))
        XCTAssertFalse(MarketCapRange.mega.matches(marketCap: 199_999_999_999))
    }

    // MARK: - Large: 10B–200B

    func testLargeBoundary() {
        XCTAssertTrue(MarketCapRange.large.matches(marketCap: 10_000_000_000))
        XCTAssertTrue(MarketCapRange.large.matches(marketCap: 100_000_000_000))
        XCTAssertTrue(MarketCapRange.large.matches(marketCap: 199_999_999_999))
        XCTAssertFalse(MarketCapRange.large.matches(marketCap: 200_000_000_000))
        XCTAssertFalse(MarketCapRange.large.matches(marketCap: 9_999_999_999))
    }

    // MARK: - Mid: 2B–10B

    func testMidBoundary() {
        XCTAssertTrue(MarketCapRange.mid.matches(marketCap: 2_000_000_000))
        XCTAssertTrue(MarketCapRange.mid.matches(marketCap: 5_000_000_000))
        XCTAssertTrue(MarketCapRange.mid.matches(marketCap: 9_999_999_999))
        XCTAssertFalse(MarketCapRange.mid.matches(marketCap: 10_000_000_000))
        XCTAssertFalse(MarketCapRange.mid.matches(marketCap: 1_999_999_999))
    }

    // MARK: - Small: 300M–2B

    func testSmallBoundary() {
        XCTAssertTrue(MarketCapRange.small.matches(marketCap: 300_000_000))
        XCTAssertTrue(MarketCapRange.small.matches(marketCap: 1_000_000_000))
        XCTAssertTrue(MarketCapRange.small.matches(marketCap: 1_999_999_999))
        XCTAssertFalse(MarketCapRange.small.matches(marketCap: 2_000_000_000))
        XCTAssertFalse(MarketCapRange.small.matches(marketCap: 299_999_999))
    }

    // MARK: - Micro: < 300M

    func testMicroBoundary() {
        XCTAssertTrue(MarketCapRange.micro.matches(marketCap: 0))
        XCTAssertTrue(MarketCapRange.micro.matches(marketCap: 100_000_000))
        XCTAssertTrue(MarketCapRange.micro.matches(marketCap: 299_999_999))
        XCTAssertFalse(MarketCapRange.micro.matches(marketCap: 300_000_000))
    }

    // MARK: - Ranges are exhaustive (non-overlapping, no gaps)

    func testRangesAreExhaustive() {
        let testValues: [Decimal] = [
            0, 100_000_000, 299_999_999, 300_000_000,
            1_999_999_999, 2_000_000_000, 9_999_999_999,
            10_000_000_000, 199_999_999_999, 200_000_000_000,
            1_000_000_000_000
        ]

        for value in testValues {
            let matching = MarketCapRange.allCases.filter { $0 != .any && $0.matches(marketCap: value) }
            XCTAssertEqual(matching.count, 1, "Value \(value) matched \(matching.count) ranges: \(matching)")
        }
    }
}
