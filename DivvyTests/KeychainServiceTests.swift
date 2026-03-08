import XCTest
@testable import Divvy

final class KeychainServiceTests: XCTestCase {
    // Use a unique service string so tests never touch the real app Keychain.
    private var sut: KeychainService!
    private let testService = "com.divvy.tests.keychain.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        sut = KeychainService(service: testService)
    }

    override func tearDown() {
        sut.delete(forKey: "testKey")
        sut.delete(forKey: "keyA")
        sut.delete(forKey: "keyB")
        sut = nil
        super.tearDown()
    }

    // MARK: - Save & Load

    func testSaveThenLoadReturnsSameValue() throws {
        try sut.save("hello-world", forKey: "testKey")
        XCTAssertEqual(sut.load(forKey: "testKey"), "hello-world")
    }

    func testLoadForUnknownKeyReturnsNil() {
        XCTAssertNil(sut.load(forKey: "nonExistentKey"))
    }

    func testSaveOverwritesExistingValue() throws {
        try sut.save("first", forKey: "testKey")
        try sut.save("second", forKey: "testKey")
        XCTAssertEqual(sut.load(forKey: "testKey"), "second")
    }

    func testSaveEmptyStringRoundTrips() throws {
        try sut.save("", forKey: "testKey")
        XCTAssertEqual(sut.load(forKey: "testKey"), "")
    }

    // MARK: - Delete

    func testDeleteRemovesPreviouslySavedValue() throws {
        try sut.save("value", forKey: "testKey")
        sut.delete(forKey: "testKey")
        XCTAssertNil(sut.load(forKey: "testKey"))
    }

    func testDeleteOnNonExistentKeyDoesNotCrash() {
        // Should complete without throwing or crashing.
        sut.delete(forKey: "neverSaved")
    }

    // MARK: - Service Isolation

    func testDifferentServiceStringsIsolateData() throws {
        let serviceA = KeychainService(service: "\(testService).a")
        let serviceB = KeychainService(service: "\(testService).b")
        defer {
            serviceA.delete(forKey: "keyA")
            serviceB.delete(forKey: "keyA")
        }

        try serviceA.save("alpha", forKey: "keyA")
        try serviceB.save("beta", forKey: "keyA")

        XCTAssertEqual(serviceA.load(forKey: "keyA"), "alpha")
        XCTAssertEqual(serviceB.load(forKey: "keyA"), "beta")
    }
}
