import Foundation

// MARK: - CharacterRegistryProviding

/// CharacterRegistry 캐릭터 관리 인터페이스.
public protocol CharacterRegistryProviding: AnyObject {
    var allCharacters: [WorkerCharacter] { get }
    var hiredCharacters: [WorkerCharacter] { get }
    var canHireMore: Bool { get }

    func character(with id: String?) -> WorkerCharacter?
    func isUnlocked(_ character: WorkerCharacter) -> Bool
    func hire(_ id: String)
    func fire(_ id: String)
    func hiredCharacters(for role: WorkerJob, allowVacation: Bool) -> [WorkerCharacter]
}
