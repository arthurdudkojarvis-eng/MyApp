import XCTest
import SwiftData
@testable import Divvy

@MainActor
final class CacheStoreTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: CacheStore!

    override func setUpWithError() throws {
        container = try ModelContainer.makeContainer(inMemory: true)
        context = ModelContext(container)
        store = CacheStore(modelContext: context)
    }

    override func tearDownWithError() throws {
        store = nil
        context = nil
        container = nil
    }

    // MARK: - Fresh entry returned

    func test_get_returnsFreshEntry() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let cache = PriceTargetCache(
            ticker: ticker,
            targetHigh: 200, targetLow: 150,
            targetMean: 175, targetMedian: 170,
            lastUpdated: .now
        )
        context.insert(cache)
        try context.save()

        let result: PriceTargetCache? = store.get(ticker: ticker)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.ticker, ticker.uppercased())
        XCTAssertEqual(result?.targetMean, 175)
    }

    // MARK: - Expired entry returns nil

    func test_get_returnsNilForExpiredEntry() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let cache = PriceTargetCache(
            ticker: ticker,
            targetHigh: 200, targetLow: 150,
            targetMean: 175, targetMedian: 170,
            lastUpdated: .now
        )
        // Backdate fetchedAt beyond the 24h TTL
        cache.fetchedAt = Date.now.addingTimeInterval(-86401)
        context.insert(cache)
        try context.save()

        let result: PriceTargetCache? = store.get(ticker: ticker)
        XCTAssertNil(result, "Expired entry should return nil")
    }

    // MARK: - Write-then-read round trip

    func test_set_thenGet_roundTrip() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let cache = PriceTargetCache(
            ticker: ticker,
            targetHigh: 300, targetLow: 250,
            targetMean: 275, targetMedian: 270,
            lastUpdated: .now
        )

        store.set(ticker: ticker, value: cache)

        let result: PriceTargetCache? = store.get(ticker: ticker)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.targetHigh, 300)
        XCTAssertEqual(result?.targetLow, 250)
    }

    // MARK: - Overwrite expired entry with fresh data

    func test_set_overwritesExpiredEntry() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"

        // Insert an expired entry
        let old = PriceTargetCache(
            ticker: ticker,
            targetHigh: 100, targetLow: 80,
            targetMean: 90, targetMedian: 85,
            lastUpdated: .now
        )
        old.fetchedAt = Date.now.addingTimeInterval(-86401)
        context.insert(old)
        try context.save()

        // Verify it's expired
        let expired: PriceTargetCache? = store.get(ticker: ticker)
        XCTAssertNil(expired)

        // Overwrite with fresh entry
        let fresh = PriceTargetCache(
            ticker: ticker,
            targetHigh: 200, targetLow: 180,
            targetMean: 190, targetMedian: 185,
            lastUpdated: .now
        )
        store.set(ticker: ticker, value: fresh)

        let result: PriceTargetCache? = store.get(ticker: ticker)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.targetMean, 190)
    }

    // MARK: - Non-existent ticker returns nil

    func test_get_returnsNilForNonExistentTicker() throws {
        let result: PriceTargetCache? = store.get(ticker: "DOESNOTEXIST")
        XCTAssertNil(result)
    }

    // MARK: - Ticker casing

    func test_get_isCaseInsensitive() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let cache = PriceTargetCache(
            ticker: ticker.uppercased(),
            targetHigh: 200, targetLow: 150,
            targetMean: 175, targetMedian: 170,
            lastUpdated: .now
        )
        context.insert(cache)
        try context.save()

        let result: PriceTargetCache? = store.get(ticker: ticker.lowercased())
        XCTAssertNotNil(result, "get() should uppercase the ticker for lookup")
    }
}
