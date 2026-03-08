import XCTest
@testable import Divvy

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: SettingsStore!

    private let defaultsSuite = "com.divvy.tests.settings.\(UUID().uuidString)"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: defaultsSuite)!
        sut = SettingsStore(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: defaultsSuite)
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization

    func testInitLoadsExpenseTargetFromDefaults() {
        defaults.set("250.75", forKey: "monthlyExpenseTarget")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.monthlyExpenseTarget, Decimal(string: "250.75")!)
    }

    func testInitDefaultsExpenseTargetToZeroWhenMissing() {
        XCTAssertEqual(sut.monthlyExpenseTarget, 0)
    }

    func testInitDefaultsExpenseTargetToZeroWhenStoredValueIsNegative() {
        defaults.set("-10", forKey: "monthlyExpenseTarget")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.monthlyExpenseTarget, 0)
    }

    func testInitDefaultsExpenseTargetToZeroWhenStoredValueIsInvalid() {
        defaults.set("not-a-number", forKey: "monthlyExpenseTarget")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.monthlyExpenseTarget, 0)
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
        let reloaded = SettingsStore(defaults: defaults)
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
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.colorScheme, .light)
    }

    func testColorSchemeCorruptedValueFallsBackToLight() {
        defaults.set("invalid-value", forKey: "colorScheme")
        let store = SettingsStore(defaults: defaults)
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
