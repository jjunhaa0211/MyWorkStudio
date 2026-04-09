import Foundation

// ═══════════════════════════════════════════════════════
// MARK: - PersistenceService
// ═══════════════════════════════════════════════════════

/// UserDefaults를 래핑하는 영속화 서비스.
/// 테스트 시 `UserDefaults(suiteName:)`을 주입하여 격리된 저장소 사용 가능.
public final class PersistenceService: PersistenceProviding {

    public static let shared = PersistenceService(store: .standard)

    private let store: UserDefaults

    public init(store: UserDefaults) {
        self.store = store
    }

    // MARK: - Bool

    public func bool(forKey key: String) -> Bool {
        store.bool(forKey: key)
    }

    public func set(_ value: Bool, forKey key: String) {
        store.set(value, forKey: key)
    }

    // MARK: - Int

    public func integer(forKey key: String) -> Int {
        store.integer(forKey: key)
    }

    public func set(_ value: Int, forKey key: String) {
        store.set(value, forKey: key)
    }

    // MARK: - Double

    public func double(forKey key: String) -> Double {
        store.double(forKey: key)
    }

    public func set(_ value: Double, forKey key: String) {
        store.set(value, forKey: key)
    }

    // MARK: - String

    public func string(forKey key: String) -> String? {
        store.string(forKey: key)
    }

    public func set(_ value: String?, forKey key: String) {
        store.set(value, forKey: key)
    }

    // MARK: - Data

    public func data(forKey key: String) -> Data? {
        store.data(forKey: key)
    }

    public func set(_ value: Data?, forKey key: String) {
        store.set(value, forKey: key)
    }

    // MARK: - [String]

    public func stringArray(forKey key: String) -> [String]? {
        store.stringArray(forKey: key)
    }

    public func set(_ value: [String]?, forKey key: String) {
        store.set(value, forKey: key)
    }

    // MARK: - Any

    public func object(forKey key: String) -> Any? {
        store.object(forKey: key)
    }

    public func set(_ value: Any?, forKey key: String) {
        store.set(value, forKey: key)
    }

    // MARK: - Remove

    public func remove(forKey key: String) {
        store.removeObject(forKey: key)
    }

    public func removeObject(forKey key: String) {
        store.removeObject(forKey: key)
    }

    // MARK: - Dictionary / Array

    public func dictionary(forKey key: String) -> [String: Any]? {
        store.dictionary(forKey: key)
    }

    public func array(forKey key: String) -> [Any]? {
        store.array(forKey: key)
    }

    // MARK: - Synchronize (no-op, kept for compatibility)

    @discardableResult
    public func synchronize() -> Bool {
        store.synchronize()
    }
}
