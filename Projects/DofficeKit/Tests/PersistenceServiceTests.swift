import XCTest
@testable import DofficeKit

final class PersistenceServiceTests: XCTestCase {

    private var sut: PersistenceService!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PersistenceServiceTests")!
        defaults.removePersistentDomain(forName: "PersistenceServiceTests")
        sut = PersistenceService(store: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "PersistenceServiceTests")
        defaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Bool

    func testBoolRoundTrip() {
        XCTAssertFalse(sut.bool(forKey: "testBool"))
        sut.set(true, forKey: "testBool")
        XCTAssertTrue(sut.bool(forKey: "testBool"))
    }

    // MARK: - Int

    func testIntRoundTrip() {
        XCTAssertEqual(sut.integer(forKey: "testInt"), 0)
        sut.set(42, forKey: "testInt")
        XCTAssertEqual(sut.integer(forKey: "testInt"), 42)
    }

    // MARK: - Double

    func testDoubleRoundTrip() {
        XCTAssertEqual(sut.double(forKey: "testDouble"), 0.0)
        sut.set(3.14, forKey: "testDouble")
        XCTAssertEqual(sut.double(forKey: "testDouble"), 3.14, accuracy: 0.001)
    }

    // MARK: - String

    func testStringRoundTrip() {
        XCTAssertNil(sut.string(forKey: "testStr"))
        sut.set("hello", forKey: "testStr")
        XCTAssertEqual(sut.string(forKey: "testStr"), "hello")
    }

    func testStringNilClear() {
        sut.set("hello", forKey: "testStr")
        sut.set(nil as String?, forKey: "testStr")
        XCTAssertNil(sut.string(forKey: "testStr"))
    }

    // MARK: - Data

    func testDataRoundTrip() {
        let data = "test".data(using: .utf8)!
        XCTAssertNil(sut.data(forKey: "testData"))
        sut.set(data, forKey: "testData")
        XCTAssertEqual(sut.data(forKey: "testData"), data)
    }

    // MARK: - StringArray

    func testStringArrayRoundTrip() {
        XCTAssertNil(sut.stringArray(forKey: "testArr"))
        sut.set(["a", "b", "c"], forKey: "testArr")
        XCTAssertEqual(sut.stringArray(forKey: "testArr"), ["a", "b", "c"])
    }

    // MARK: - Remove

    func testRemove() {
        sut.set(42, forKey: "toRemove")
        XCTAssertEqual(sut.integer(forKey: "toRemove"), 42)
        sut.remove(forKey: "toRemove")
        XCTAssertEqual(sut.integer(forKey: "toRemove"), 0)
    }

    // MARK: - Isolation

    func testIsolatedFromStandard() {
        let key = "persistenceServiceIsolationTest_\(UUID().uuidString)"
        sut.set(true, forKey: key)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
    }
}
