import XCTest
import SwiftData
@testable import Divvy

@MainActor
final class AIReportTests: XCTestCase {

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

    // MARK: - Model encoding round-trip

    func test_bullPoints_encodeDecode_roundTrip() {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let bull = ["Strong revenue growth", "Expanding margins", "Market leadership"]
        let report = AIReport(ticker: ticker, bullPoints: bull, bearPoints: [], generatedAt: .now)

        XCTAssertEqual(report.bullPoints, bull)
    }

    func test_bearPoints_encodeDecode_roundTrip() {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let bear = ["High valuation", "Competition risk", "Regulatory pressure"]
        let report = AIReport(ticker: ticker, bullPoints: [], bearPoints: bear, generatedAt: .now)

        XCTAssertEqual(report.bearPoints, bear)
    }

    func test_emptyPoints_decodeSafely() {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let report = AIReport(ticker: ticker, bullPoints: [], bearPoints: [], generatedAt: .now)

        XCTAssertEqual(report.bullPoints, [])
        XCTAssertEqual(report.bearPoints, [])
    }

    // MARK: - Ticker uppercased

    func test_init_uppercasesTicker() {
        let report = AIReport(ticker: "aapl", bullPoints: ["Growth"], bearPoints: ["Risk"], generatedAt: .now)

        XCTAssertEqual(report.ticker, "AAPL")
    }

    // MARK: - Cacheable conformance

    func test_defaultTTL_is72Hours() {
        XCTAssertEqual(AIReport.defaultTTL, 259200) // 72 * 60 * 60
    }

    // MARK: - CacheStore integration

    func test_cacheStore_setThenGet_roundTrip() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let report = AIReport(
            ticker: ticker,
            bullPoints: ["Revenue up 20%", "Strong moat"],
            bearPoints: ["Multiple compression risk"],
            generatedAt: .now
        )

        store.set(ticker: ticker, value: report)

        let result: AIReport? = store.get(ticker: ticker)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.ticker, ticker.uppercased())
        XCTAssertEqual(result?.bullPoints, ["Revenue up 20%", "Strong moat"])
        XCTAssertEqual(result?.bearPoints, ["Multiple compression risk"])
    }

    func test_cacheStore_returnsNilForExpiredReport() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let report = AIReport(
            ticker: ticker,
            bullPoints: ["Growth"],
            bearPoints: ["Risk"],
            generatedAt: .now
        )
        // Backdate fetchedAt beyond 72h TTL
        report.fetchedAt = Date.now.addingTimeInterval(-259201)
        context.insert(report)
        try context.save()

        let result: AIReport? = store.get(ticker: ticker)
        XCTAssertNil(result, "Expired report should return nil")
    }

    func test_cacheStore_overwritesExistingReport() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"

        let old = AIReport(
            ticker: ticker,
            bullPoints: ["Old bull"],
            bearPoints: ["Old bear"],
            generatedAt: .now
        )
        store.set(ticker: ticker, value: old)

        let updated = AIReport(
            ticker: ticker,
            bullPoints: ["New bull 1", "New bull 2"],
            bearPoints: ["New bear 1"],
            generatedAt: .now
        )
        store.set(ticker: ticker, value: updated)

        let result: AIReport? = store.get(ticker: ticker)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.bullPoints, ["New bull 1", "New bull 2"])
        XCTAssertEqual(result?.bearPoints, ["New bear 1"])
    }

    // MARK: - Stale detection

    func test_staleReport_detectedAfter72Hours() {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let report = AIReport(
            ticker: ticker,
            bullPoints: ["Growth"],
            bearPoints: ["Risk"],
            generatedAt: Date.now.addingTimeInterval(-259201)
        )
        report.fetchedAt = Date.now.addingTimeInterval(-259201)

        let isStale = Date.now.timeIntervalSince(report.fetchedAt) > AIReport.defaultTTL
        XCTAssertTrue(isStale)
    }

    func test_freshReport_notStale() {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let report = AIReport(
            ticker: ticker,
            bullPoints: ["Growth"],
            bearPoints: ["Risk"],
            generatedAt: .now
        )

        let isStale = Date.now.timeIntervalSince(report.fetchedAt) > AIReport.defaultTTL
        XCTAssertFalse(isStale)
    }

    // MARK: - Non-existent ticker

    func test_cacheStore_returnsNilForNonExistentTicker() {
        let result: AIReport? = store.get(ticker: "DOESNOTEXIST")
        XCTAssertNil(result)
    }

    // MARK: - Case-insensitive lookup

    func test_cacheStore_isCaseInsensitive() throws {
        let ticker = "T-\(UUID().uuidString.prefix(8))"
        let report = AIReport(
            ticker: ticker.uppercased(),
            bullPoints: ["Growth"],
            bearPoints: ["Risk"],
            generatedAt: .now
        )
        context.insert(report)
        try context.save()

        let result: AIReport? = store.get(ticker: ticker.lowercased())
        XCTAssertNotNil(result, "get() should uppercase the ticker for lookup")
    }
}
