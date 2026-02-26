import XCTest
@testable import MyApp

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var keychain: KeychainService!
    private var defaults: UserDefaults!
    private var sut: SettingsStore!

    private let keychainService = "com.myapp.tests.settings.\(UUID().uuidString)"
    private let defaultsSuite  = "com.myapp.tests.settings.\(UUID().uuidString)"

    override func setUp() async throws {
        try await super.setUp()
        keychain = KeychainService(service: keychainService)
        defaults = UserDefaults(suiteName: defaultsSuite)!
        sut = SettingsStore(keychain: keychain, defaults: defaults)
    }

    override func tearDown() async throws {
        keychain.delete(forKey: "polygonAPIKey")
        defaults.removePersistentDomain(forName: defaultsSuite)
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization

    func testInitLoadsAPIKeyFromKeychain() throws {
        try keychain.save("test-api-key", forKey: "polygonAPIKey")
        let store = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(store.polygonAPIKey, "test-api-key")
    }

    func testInitDefaultsAPIKeyToEmptyStringWhenKeychainEmpty() {
        XCTAssertEqual(sut.polygonAPIKey, "")
    }

    func testInitLoadsExpenseTargetFromDefaults() {
        defaults.set("250.75", forKey: "monthlyExpenseTarget")
        let store = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(store.monthlyExpenseTarget, Decimal(string: "250.75")!)
    }

    func testInitDefaultsExpenseTargetToZeroWhenMissing() {
        XCTAssertEqual(sut.monthlyExpenseTarget, 0)
    }

    func testInitDefaultsExpenseTargetToZeroWhenStoredValueIsNegative() {
        defaults.set("-10", forKey: "monthlyExpenseTarget")
        let store = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(store.monthlyExpenseTarget, 0)
    }

    func testInitDefaultsExpenseTargetToZeroWhenStoredValueIsInvalid() {
        defaults.set("not-a-number", forKey: "monthlyExpenseTarget")
        let store = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(store.monthlyExpenseTarget, 0)
    }

    // MARK: - polygonAPIKey mutations

    func testSettingAPIKeyPersistsToKeychain() {
        sut.polygonAPIKey = "new-key"
        XCTAssertEqual(keychain.load(forKey: "polygonAPIKey"), "new-key")
    }

    func testSettingAPIKeyToEmptyStringPersistsEmptyString() {
        sut.polygonAPIKey = "some-key"
        sut.polygonAPIKey = ""
        XCTAssertEqual(keychain.load(forKey: "polygonAPIKey"), "")
    }

    func testHasPolygonAPIKeyIsFalseWhenEmpty() {
        XCTAssertFalse(sut.hasPolygonAPIKey)
    }

    func testHasPolygonAPIKeyIsTrueWhenNonEmpty() {
        sut.polygonAPIKey = "abc"
        XCTAssertTrue(sut.hasPolygonAPIKey)
    }

    // MARK: - monthlyExpenseTarget mutations

    func testSettingExpenseTargetPersistsToDefaults() {
        let value = Decimal(string: "500.50")!
        sut.monthlyExpenseTarget = value
        // Decimal.description normalises trailing zeros ("500.50" → "500.5"); compare round-trip value.
        let stored = defaults.string(forKey: "monthlyExpenseTarget").flatMap { Decimal(string: $0) }
        XCTAssertEqual(stored, value)
    }

    func testSettingExpenseTargetToZeroPersistsZero() {
        sut.monthlyExpenseTarget = Decimal(string: "100")!
        sut.monthlyExpenseTarget = 0
        XCTAssertEqual(defaults.string(forKey: "monthlyExpenseTarget"), "0")
    }

    func testDecimalStringRoundTripIsLossless() {
        let original = Decimal(string: "1234.56")!
        sut.monthlyExpenseTarget = original
        // Re-create the store from the same defaults to simulate app relaunch.
        let reloaded = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(reloaded.monthlyExpenseTarget, original)
    }
}
