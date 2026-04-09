import Foundation

// MARK: - PersistenceProviding

/// UserDefaults 추상화 프로토콜.
/// 테스트 시 인메모리 구현으로 교체 가능.
public protocol PersistenceProviding {
    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)

    func integer(forKey key: String) -> Int
    func set(_ value: Int, forKey key: String)

    func double(forKey key: String) -> Double
    func set(_ value: Double, forKey key: String)

    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)

    func data(forKey key: String) -> Data?
    func set(_ value: Data?, forKey key: String)

    func stringArray(forKey key: String) -> [String]?
    func set(_ value: [String]?, forKey key: String)

    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)

    func remove(forKey key: String)
}
