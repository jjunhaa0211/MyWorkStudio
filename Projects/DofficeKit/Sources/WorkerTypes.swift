import SwiftUI
import DesignSystem

public enum WorkerJob: String, Codable, CaseIterable, Identifiable {
    case developer
    case qa
    case reporter
    case boss
    case planner
    case reviewer
    case designer
    case sre

    public var id: String { rawValue }

    /// 프롬프트 자동 주입 설정에서 사용하는 키 (AutomationTemplateKind rawValue와 매핑)
    public var promptRoleKey: String? {
        switch self {
        case .planner: return "planner"
        case .designer: return "designer"
        case .developer: return "developerExecution"
        case .reviewer: return "reviewer"
        case .qa: return "qa"
        case .reporter: return "reporter"
        case .sre: return "sre"
        case .boss: return nil  // boss는 프롬프트 템플릿 없음
        }
    }

    /// 현재 설정에서 이 직업의 프롬프트가 활성화되어 있는지 확인
    public var isPromptEnabledInSettings: Bool {
        guard let key = promptRoleKey else { return true }
        return AppSettings.shared.isPromptEnabled(for: key)
    }

    /// 설정에서 활성화된 직업만 반환
    public static var enabledCases: [WorkerJob] {
        allCases.filter { $0.isPromptEnabledInSettings }
    }

    public var displayName: String {
        switch self {
        case .developer: return NSLocalizedString("job.developer", comment: "")
        case .qa: return NSLocalizedString("job.qa", comment: "")
        case .reporter: return NSLocalizedString("job.reporter", comment: "")
        case .boss: return NSLocalizedString("job.boss", comment: "")
        case .planner: return NSLocalizedString("job.planner", comment: "")
        case .reviewer: return NSLocalizedString("job.reviewer", comment: "")
        case .designer: return NSLocalizedString("job.designer", comment: "")
        case .sre: return NSLocalizedString("job.sre", comment: "")
        }
    }

    public var shortLabel: String {
        switch self {
        case .developer: return "DEV"
        case .qa: return "QA"
        case .reporter: return "MD"
        case .boss: return "CEO"
        case .planner: return "PM"
        case .reviewer: return "REV"
        case .designer: return "DES"
        case .sre: return "SRE"
        }
    }

    public var icon: String {
        switch self {
        case .developer: return "laptopcomputer"
        case .qa: return "checkmark.shield.fill"
        case .reporter: return "doc.text.fill"
        case .boss: return "crown.fill"
        case .planner: return "list.bullet.clipboard.fill"
        case .reviewer: return "checklist.checked"
        case .designer: return "paintpalette.fill"
        case .sre: return "server.rack"
        }
    }

    public var description: String {
        switch self {
        case .developer:
            return NSLocalizedString("job.desc.developer", comment: "")
        case .qa:
            return NSLocalizedString("job.desc.qa", comment: "")
        case .reporter:
            return NSLocalizedString("job.desc.reporter", comment: "")
        case .boss:
            return NSLocalizedString("job.desc.boss", comment: "")
        case .planner:
            return NSLocalizedString("job.desc.planner", comment: "")
        case .reviewer:
            return NSLocalizedString("job.desc.reviewer", comment: "")
        case .designer:
            return NSLocalizedString("job.desc.designer", comment: "")
        case .sre:
            return NSLocalizedString("job.desc.sre", comment: "")
        }
    }

    public var relationshipHint: String {
        switch self {
        case .developer:
            return NSLocalizedString("job.hint.developer", comment: "")
        case .qa:
            return NSLocalizedString("job.hint.qa", comment: "")
        case .reporter:
            return NSLocalizedString("job.hint.reporter", comment: "")
        case .boss:
            return NSLocalizedString("job.hint.boss", comment: "")
        case .planner:
            return NSLocalizedString("job.hint.planner", comment: "")
        case .reviewer:
            return NSLocalizedString("job.hint.reviewer", comment: "")
        case .designer:
            return NSLocalizedString("job.hint.designer", comment: "")
        case .sre:
            return NSLocalizedString("job.hint.sre", comment: "")
        }
    }

    public var usesExtraTokensWarning: Bool {
        self != .developer
    }

    public var participatesInAutoPipeline: Bool {
        self == .reviewer || self == .qa || self == .reporter
    }

    public var takesManualCodingSessions: Bool {
        self == .developer
    }

    /// 1:1 세션 전용 역할인지 여부. 개발자만 한 세션에 전담.
    public var isExclusiveSession: Bool {
        self == .developer
    }
}

public struct WorkerCharacter: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var archetype: String
    public let hairColor: String
    public let skinTone: String
    public let shirtColor: String
    public let pantsColor: String
    public let hatType: HatType
    public let accessory: Accessory
    public let species: Species
    public var isHired: Bool = false
    public var hiredAt: Date?
    public var requiredAchievement: String?  // nil이면 자유 고용, 있으면 해당 업적 달성 필요
    public var jobRole: WorkerJob = .developer
    public var isOnVacation: Bool = false

    public var localizedArchetype: String {
        let key = "archetype.\(id)"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? archetype : localized
    }

    public var isPluginCharacter: Bool { id.hasPrefix("plugin_") }
    public var isFleaMarketHiddenCharacter: Bool { id.hasPrefix("plugin_flea-market-hidden-pack_") }

    /// 플러그인 팩 이름 추출 (예: "plugin_vacation-beach-pack_lifeguard" → "vacation-beach-pack")
    public var pluginPackName: String? {
        guard isPluginCharacter else { return nil }
        let parts = id.split(separator: "_", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        return String(parts[1])
    }

    /// 플러그인 팩 뱃지 텍스트
    public var pluginBadgeText: String? {
        guard let pack = pluginPackName else { return nil }
        switch pack {
        case "flea-market-hidden-pack": return "히든"
        case "vacation-beach-pack": return "바캉스"
        case "battleground-pack": return "배그"
        case "typing-combo-pack": return "콤보"
        case "premium-furniture-pack": return "프리미엄"
        default:
            // 알 수 없는 플러그인 → 팩 이름에서 추출
            let name = pack.replacingOccurrences(of: "-pack", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .prefix(8)
            return String(name)
        }
    }

    public enum HatType: String, Codable, CaseIterable {
        case none, beanie, cap, hardhat, wizard, crown, headphones, beret

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = HatType(rawValue: raw) ?? .cap
        }
    }

    public enum Accessory: String, Codable, CaseIterable {
        case none, glasses, sunglasses, scarf, mask, earring

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Accessory(rawValue: raw) ?? .none
        }
    }

    public enum Species: String, Codable, CaseIterable {
        case human = "Human"
        case cat = "Cat"
        case dog = "Dog"
        case rabbit = "Rabbit"
        case bear = "Bear"
        case penguin = "Penguin"
        case fox = "Fox"
        case robot = "Robot"
        case claude = "Claude"
        case alien = "Alien"
        case ghost = "Ghost"
        case dragon = "Dragon"
        case chicken = "Chicken"
        case owl = "Owl"
        case frog = "Frog"
        case panda = "Panda"
        case unicorn = "Unicorn"
        case skeleton = "Skeleton"

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Species(rawValue: raw) ?? .human
        }

        public var localizationKey: String {
            switch self {
            case .human: return "species.human"
            case .cat: return "species.cat"
            case .dog: return "species.dog"
            case .rabbit: return "species.rabbit"
            case .bear: return "species.bear"
            case .penguin: return "species.penguin"
            case .fox: return "species.fox"
            case .robot: return "species.robot"
            case .claude: return "species.claude"
            case .alien: return "species.alien"
            case .ghost: return "species.ghost"
            case .dragon: return "species.dragon"
            case .chicken: return "species.chicken"
            case .owl: return "species.owl"
            case .frog: return "species.frog"
            case .panda: return "species.panda"
            case .unicorn: return "species.unicorn"
            case .skeleton: return "species.skeleton"
            }
        }
        public var localizedName: String { NSLocalizedString(localizationKey, comment: "") }
    }

    public init(
        id: String,
        name: String,
        archetype: String,
        hairColor: String,
        skinTone: String,
        shirtColor: String,
        pantsColor: String,
        hatType: HatType,
        accessory: Accessory,
        species: Species,
        isHired: Bool = false,
        hiredAt: Date? = nil,
        requiredAchievement: String? = nil,
        jobRole: WorkerJob = .developer,
        isOnVacation: Bool = false
    ) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.hairColor = hairColor
        self.skinTone = skinTone
        self.shirtColor = shirtColor
        self.pantsColor = pantsColor
        self.hatType = hatType
        self.accessory = accessory
        self.species = species
        self.isHired = isHired
        self.hiredAt = hiredAt
        self.requiredAchievement = requiredAchievement
        self.jobRole = jobRole
        self.isOnVacation = isOnVacation
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, archetype, hairColor, skinTone, shirtColor, pantsColor
        case hatType, accessory, species, isHired, hiredAt, requiredAchievement
        case jobRole, isOnVacation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        archetype = try container.decode(String.self, forKey: .archetype)
        hairColor = try container.decode(String.self, forKey: .hairColor)
        skinTone = try container.decode(String.self, forKey: .skinTone)
        shirtColor = try container.decode(String.self, forKey: .shirtColor)
        pantsColor = try container.decode(String.self, forKey: .pantsColor)
        hatType = try container.decode(HatType.self, forKey: .hatType)
        accessory = try container.decode(Accessory.self, forKey: .accessory)
        species = try container.decode(Species.self, forKey: .species)
        isHired = try container.decodeIfPresent(Bool.self, forKey: .isHired) ?? false
        hiredAt = try container.decodeIfPresent(Date.self, forKey: .hiredAt)
        requiredAchievement = try container.decodeIfPresent(String.self, forKey: .requiredAchievement)
        jobRole = try container.decodeIfPresent(WorkerJob.self, forKey: .jobRole) ?? .developer
        isOnVacation = try container.decodeIfPresent(Bool.self, forKey: .isOnVacation) ?? false
    }
}
