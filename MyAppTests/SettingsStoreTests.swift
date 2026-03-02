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
        keychain.delete(forKey: "apiKey")
        defaults.removePersistentDomain(forName: defaultsSuite)
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization

    func testInitLoadsUserAPIKeyFromKeychain() throws {
        try keychain.save("test-api-key", forKey: "apiKey")
        let store = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(store.userAPIKey, "test-api-key")
        XCTAssertEqual(store.apiKey, "test-api-key")
    }

    func testInitMigratesLegacyFMPAPIKey() throws {
        try keychain.save("legacy-fmp-key", forKey: "fmpAPIKey")
        let store = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(store.userAPIKey, "legacy-fmp-key")
        XCTAssertNil(keychain.load(forKey: "fmpAPIKey"), "Legacy key should be deleted after migration")
        XCTAssertEqual(keychain.load(forKey: "apiKey"), "legacy-fmp-key")
    }

    func testInitDefaultsUserAPIKeyToEmptyStringWhenKeychainEmpty() {
        XCTAssertEqual(sut.userAPIKey, "")
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

    // MARK: - userAPIKey mutations

    func testSettingUserAPIKeyPersistsToKeychain() {
        sut.userAPIKey = "new-key"
        XCTAssertEqual(keychain.load(forKey: "apiKey"), "new-key")
    }

    func testSettingUserAPIKeyToEmptyStringPersistsEmptyString() {
        sut.userAPIKey = "some-key"
        sut.userAPIKey = ""
        XCTAssertEqual(keychain.load(forKey: "apiKey"), "")
    }

    func testHasAPIKeyReflectsEffectiveKey() {
        // With placeholder empty arrays, EmbeddedAPIKey.key is "" so hasAPIKey depends on userAPIKey.
        // With real embedded bytes, hasAPIKey would be true even when userAPIKey is empty.
        sut.userAPIKey = "abc"
        XCTAssertTrue(sut.hasAPIKey)
    }

    // MARK: - apiKey fallback

    func testAPIKeyFallsBackToEmbeddedKeyWhenUserKeyEmpty() {
        sut.userAPIKey = ""
        XCTAssertEqual(sut.apiKey, EmbeddedAPIKey.key)
    }

    func testAPIKeyReturnsUserKeyWhenSet() {
        sut.userAPIKey = "custom-key"
        XCTAssertEqual(sut.apiKey, "custom-key")
    }

    func testIsUsingCustomKeyIsFalseWhenUserKeyEmpty() {
        sut.userAPIKey = ""
        XCTAssertFalse(sut.isUsingCustomKey)
    }

    func testIsUsingCustomKeyIsTrueWhenUserKeySet() {
        sut.userAPIKey = "my-key"
        XCTAssertTrue(sut.isUsingCustomKey)
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

    // MARK: - colorScheme

    func testColorSchemeDefaultsToLight() {
        XCTAssertEqual(sut.colorScheme, .light)
        XCTAssertEqual(sut.colorScheme.resolvedColorScheme, .light)
    }

    func testSettingColorSchemePersistsToDefaults() {
        sut.colorScheme = .dark
        XCTAssertEqual(defaults.string(forKey: "colorScheme"), "dark")
    }

    func testColorSchemeRoundTrip() {
        sut.colorScheme = .light
        let reloaded = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(reloaded.colorScheme, .light)
    }

    func testColorSchemeCorruptedValueFallsBackToLight() {
        defaults.set("invalid-value", forKey: "colorScheme")
        let store = SettingsStore(keychain: keychain, defaults: defaults)
        XCTAssertEqual(store.colorScheme, .light)
    }

    func testAllColorSchemeCasesMapToExpectedColorScheme() {
        XCTAssertEqual(AppColorScheme.light.resolvedColorScheme, .light)
        XCTAssertEqual(AppColorScheme.dark.resolvedColorScheme, .dark)
    }

    func testColorSchemeLabels() {
        XCTAssertEqual(AppColorScheme.light.label, "Light")
        XCTAssertEqual(AppColorScheme.dark.label, "Dark")
    }

    func testAppColorSchemeCaseCount() {
        XCTAssertEqual(AppColorScheme.allCases.count, 2)
    }

    func testInitDoesNotWriteToDefaultsWhenNoStoredColorScheme() {
        // Fresh store with empty defaults — no colorScheme key should be written on init.
        XCTAssertNil(defaults.string(forKey: "colorScheme"))
    }

    func testSettingSameColorSchemeIsIdempotent() {
        sut.colorScheme = .dark
        sut.colorScheme = .dark
        XCTAssertEqual(sut.colorScheme, .dark)
        XCTAssertEqual(defaults.string(forKey: "colorScheme"), "dark")
    }
}
