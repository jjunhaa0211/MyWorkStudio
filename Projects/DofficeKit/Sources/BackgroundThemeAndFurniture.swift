import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Background Theme
// ═══════════════════════════════════════════════════════

public enum BackgroundTheme: String, CaseIterable, Identifiable {
    case auto, sunny, clearSky, sunset, goldenHour, dusk
    case moonlit, starryNight, aurora, milkyWay
    case storm, rain, snow, fog
    case cherryBlossom, autumn, forest
    case neonCity, ocean, desert, volcano

    public var id: String { rawValue }

    public var displayName: String {
        NSLocalizedString("weather.\(rawValue)", comment: "")
    }

    public var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .sunny: return "sun.max.fill"
        case .clearSky: return "cloud.sun.fill"
        case .sunset: return "sunset.fill"
        case .goldenHour: return "sun.haze.fill"
        case .dusk: return "sun.horizon.fill"
        case .moonlit: return "moon.fill"
        case .starryNight: return "star.fill"
        case .aurora: return "wand.and.stars"
        case .milkyWay: return "sparkles"
        case .storm: return "cloud.bolt.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .fog: return "cloud.fog.fill"
        case .cherryBlossom: return "leaf.fill"
        case .autumn: return "leaf.fill"
        case .forest: return "tree.fill"
        case .neonCity: return "building.2.fill"
        case .ocean: return "water.waves"
        case .desert: return "sun.dust.fill"
        case .volcano: return "mountain.2.fill"
        }
    }

    public var skyColors: (top: String, bottom: String) {
        switch self {
        case .auto: return ("0a0d18", "0a0d18")
        case .sunny: return ("4a90d9", "87ceeb")
        case .clearSky: return ("2070c0", "60b0e8")
        case .sunset: return ("1a1040", "e06030")
        case .goldenHour: return ("d08030", "f0c060")
        case .dusk: return ("1a1838", "4a3060")
        case .moonlit: return ("0a1020", "1a2040")
        case .starryNight: return ("050810", "0a1020")
        case .aurora: return ("051018", "0a2030")
        case .milkyWay: return ("030508", "0a0d18")
        case .storm: return ("1a1e28", "2a3040")
        case .rain: return ("2a3040", "3a4858")
        case .snow: return ("b0c0d0", "d0d8e0")
        case .fog: return ("8090a0", "a0a8b0")
        case .cherryBlossom: return ("e8b0c0", "f0d0d8")
        case .autumn: return ("c06030", "d09040")
        case .forest: return ("2a5030", "4a8050")
        case .neonCity: return ("0a0818", "1a1030")
        case .ocean: return ("1040a0", "2060c0")
        case .desert: return ("c09050", "e0c080")
        case .volcano: return ("200808", "401010")
        }
    }

    public var floorColors: (base: String, dot: String) {
        switch self {
        case .snow: return ("e0e4e8", "c8ccd4")
        case .desert: return ("d0a860", "c09848")
        case .ocean: return ("1a3050", "1a2840")
        case .volcano: return ("2a1010", "3a1818")
        case .forest: return ("1a3020", "2a4030")
        case .neonCity: return ("0e0818", "1a1030")
        case .autumn: return ("6a4020", "5a3818")
        case .cherryBlossom: return ("d0c0c4", "c0b0b8")
        default: return ("", "")
        }
    }

    public var requiredLevel: Int? {
        switch self {
        case .auto, .sunny, .clearSky, .sunset, .moonlit, .rain: return nil  // 기본
        case .goldenHour, .dusk: return 3
        case .starryNight, .fog: return 5
        case .snow, .cherryBlossom: return 8
        case .aurora: return 12
        case .milkyWay: return 15
        case .storm: return 10
        case .autumn, .forest: return 7
        case .neonCity: return 20
        case .ocean: return 10
        case .desert: return 18
        case .volcano: return 25
        }
    }

    public var isUnlocked: Bool {
        if PersistenceService.shared.bool(forKey: "allContentUnlocked") { return true }
        guard let level = requiredLevel else { return true }
        return AchievementManager.shared.currentLevel.level >= level
    }

    public var lockReason: String {
        guard let level = requiredLevel else { return "" }
        let currentLevel = AchievementManager.shared.currentLevel.level
        if currentLevel < level { return String(format: NSLocalizedString("settings.level.required", comment: ""), level) }
        return ""
    }

}

// ═══════════════════════════════════════════════════════
// MARK: - Furniture Item Model
// ═══════════════════════════════════════════════════════

public struct FurnitureItem: Identifiable {
    public let id: String
    public let name: String
    public let icon: String
    public let defaultNormX: CGFloat  // 0-1 normalized within room
    public let defaultNormY: CGFloat  // 0-1 normalized (0=top wall, 1=floor)
    public let width: CGFloat
    public let height: CGFloat
    public let isWallItem: Bool       // constrained to upper wall zone
    public let requiredLevel: Int?          // nil = 기본 해금
    public let requiredAchievement: String? // nil = 레벨만 체크

    public init(id: String, name: String, icon: String, defaultNormX: CGFloat, defaultNormY: CGFloat, width: CGFloat, height: CGFloat, isWallItem: Bool, requiredLevel: Int?, requiredAchievement: String?) {
        self.id = id; self.name = name; self.icon = icon; self.defaultNormX = defaultNormX; self.defaultNormY = defaultNormY
        self.width = width; self.height = height; self.isWallItem = isWallItem
        self.requiredLevel = requiredLevel; self.requiredAchievement = requiredAchievement
    }

    public var isUnlocked: Bool {
        // 시크릿키로 전체 해금된 경우
        if PersistenceService.shared.bool(forKey: "allContentUnlocked") { return true }
        if let level = requiredLevel {
            let currentLevel = AchievementManager.shared.currentLevel.level
            if currentLevel < level { return false }
        }
        if let achievement = requiredAchievement {
            if !(AchievementManager.shared.achievements.first(where: { $0.id == achievement })?.unlocked ?? false) {
                return false
            }
        }
        return true
    }

    public var lockReason: String {
        if let level = requiredLevel {
            let currentLevel = AchievementManager.shared.currentLevel.level
            if currentLevel < level { return String(format: NSLocalizedString("furn.level.required.current", comment: ""), level, currentLevel) }
        }
        if let achievement = requiredAchievement {
            if let ach = AchievementManager.shared.achievements.first(where: { $0.id == achievement }), !ach.unlocked {
                return String(format: NSLocalizedString("furn.achievement.required", comment: ""), ach.name)
            }
        }
        return ""
    }

    public static let all: [FurnitureItem] = [
        // 기본 가구
        FurnitureItem(id: "sofa", name: NSLocalizedString("furn.sofa", comment: ""), icon: "sofa.fill", defaultNormX: 0.0, defaultNormY: 0.7, width: 49, height: 30, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "sideTable", name: NSLocalizedString("furn.sideTable", comment: ""), icon: "table.furniture.fill", defaultNormX: 0.45, defaultNormY: 0.75, width: 18, height: 14, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "coffeeMachine", name: NSLocalizedString("furn.coffeeMachine", comment: ""), icon: "cup.and.saucer.fill", defaultNormX: 0.45, defaultNormY: 0.5, width: 16, height: 28, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "plant", name: NSLocalizedString("furn.plant", comment: ""), icon: "leaf.fill", defaultNormX: 0.7, defaultNormY: 0.65, width: 14, height: 28, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "picture", name: NSLocalizedString("furn.picture", comment: ""), icon: "photo.artframe", defaultNormX: 0.55, defaultNormY: 0.1, width: 20, height: 16, isWallItem: true, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "neonSign", name: NSLocalizedString("furn.neonSign", comment: ""), icon: "lightbulb.fill", defaultNormX: 0.1, defaultNormY: 0.25, width: 64, height: 16, isWallItem: true, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "rug", name: NSLocalizedString("furn.rug", comment: ""), icon: "rectangle.fill", defaultNormX: 0.0, defaultNormY: 0.95, width: 100, height: 14, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        // 추가 악세서리
        FurnitureItem(id: "bookshelf", name: NSLocalizedString("furn.bookshelf", comment: ""), icon: "books.vertical.fill", defaultNormX: 0.8, defaultNormY: 0.4, width: 20, height: 36, isWallItem: false, requiredLevel: 5, requiredAchievement: nil),
        FurnitureItem(id: "aquarium", name: NSLocalizedString("furn.aquarium", comment: ""), icon: "fish.fill", defaultNormX: 0.6, defaultNormY: 0.7, width: 22, height: 18, isWallItem: false, requiredLevel: 8, requiredAchievement: nil),
        FurnitureItem(id: "arcade", name: NSLocalizedString("furn.arcade", comment: ""), icon: "gamecontroller.fill", defaultNormX: 0.85, defaultNormY: 0.55, width: 16, height: 30, isWallItem: false, requiredLevel: 10, requiredAchievement: "complete_50"),
        FurnitureItem(id: "whiteboard", name: NSLocalizedString("furn.whiteboard", comment: ""), icon: "rectangle.and.pencil.and.ellipsis", defaultNormX: 0.35, defaultNormY: 0.08, width: 30, height: 22, isWallItem: true, requiredLevel: 7, requiredAchievement: nil),
        FurnitureItem(id: "lamp", name: NSLocalizedString("furn.lamp", comment: ""), icon: "lamp.floor.fill", defaultNormX: 0.9, defaultNormY: 0.6, width: 10, height: 30, isWallItem: false, requiredLevel: 3, requiredAchievement: nil),
        FurnitureItem(id: "cat", name: NSLocalizedString("furn.cat", comment: ""), icon: "cat.fill", defaultNormX: 0.3, defaultNormY: 0.85, width: 12, height: 10, isWallItem: false, requiredLevel: 15, requiredAchievement: "night_owl_10"),
        FurnitureItem(id: "tv", name: "TV", icon: "tv.fill", defaultNormX: 0.7, defaultNormY: 0.15, width: 28, height: 18, isWallItem: true, requiredLevel: 12, requiredAchievement: nil),
        FurnitureItem(id: "fan", name: NSLocalizedString("furn.fan", comment: ""), icon: "fan.fill", defaultNormX: 0.5, defaultNormY: 0.65, width: 12, height: 22, isWallItem: false, requiredLevel: 6, requiredAchievement: nil),
        FurnitureItem(id: "calendar", name: NSLocalizedString("furn.calendar", comment: ""), icon: "calendar", defaultNormX: 0.8, defaultNormY: 0.12, width: 14, height: 14, isWallItem: true, requiredLevel: 4, requiredAchievement: nil),
        FurnitureItem(id: "poster", name: NSLocalizedString("furn.poster", comment: ""), icon: "doc.richtext.fill", defaultNormX: 0.45, defaultNormY: 0.08, width: 16, height: 20, isWallItem: true, requiredLevel: 9, requiredAchievement: nil),
        FurnitureItem(id: "trashcan", name: NSLocalizedString("furn.trashcan", comment: ""), icon: "trash.fill", defaultNormX: 0.95, defaultNormY: 0.85, width: 10, height: 12, isWallItem: false, requiredLevel: 2, requiredAchievement: nil),
        FurnitureItem(id: "cushion", name: NSLocalizedString("furn.cushion", comment: ""), icon: "circle.fill", defaultNormX: 0.15, defaultNormY: 0.88, width: 12, height: 8, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
    ]
}
