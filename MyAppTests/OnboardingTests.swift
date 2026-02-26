import XCTest
@testable import MyApp

@MainActor
final class OnboardingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: SettingsStore!

    private let suite = "com.myapp.tests.onboarding.\(UUID().uuidString)"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suite)!
        sut = SettingsStore(
            keychain: KeychainService(service: "com.myapp.tests.onboarding.\(UUID().uuidString)"),
            defaults: defaults
        )
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testHasCompletedOnboardingDefaultsToFalse() {
        XCTAssertFalse(sut.hasCompletedOnboarding)
    }

    // MARK: - Persistence

    func testCompletingOnboardingPersistsToDefaults() {
        sut.hasCompletedOnboarding = true
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    func testOnboardingStateRoundTrip() {
        sut.hasCompletedOnboarding = true
        let reloaded = SettingsStore(keychain: KeychainService(service: "com.myapp.tests.rt.\(UUID().uuidString)"),
                                     defaults: defaults)
        XCTAssertTrue(reloaded.hasCompletedOnboarding)
    }

    func testResettingOnboardingPersistsFalse() {
        sut.hasCompletedOnboarding = true
        sut.hasCompletedOnboarding = false
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding"))
    }
}
