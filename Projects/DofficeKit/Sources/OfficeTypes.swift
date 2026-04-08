import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Office Types (공유 타입 정의)
// ═══════════════════════════════════════════════════════

// MARK: - Tile Coordinate

public struct TileCoord: Hashable, Codable, Equatable {
    public let col: Int
    public let row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }

    public func distance(to other: TileCoord) -> Int {
        abs(col - other.col) + abs(row - other.row)
    }

    public static func + (lhs: TileCoord, rhs: TileCoord) -> TileCoord {
        TileCoord(col: lhs.col + rhs.col, row: lhs.row + rhs.row)
    }
}

// MARK: - Direction (4방향)

public enum Direction: Int, Codable, CaseIterable {
    case down = 0, left = 1, right = 2, up = 3

    public var delta: TileCoord {
        switch self {
        case .up: return TileCoord(col: 0, row: -1)
        case .down: return TileCoord(col: 0, row: 1)
        case .left: return TileCoord(col: -1, row: 0)
        case .right: return TileCoord(col: 1, row: 0)
        }
    }
}

// MARK: - Sprite Data (픽셀 아트 핵심)

/// 2D 배열: 각 셀은 hex 색상 문자열. "" = 투명
public typealias SpriteData = [[String]]

/// 캐릭터 스프라이트 세트: 방향별 프레임 배열
public struct CharacterSpriteSet {
    /// walk[direction] = [frame0, frame1, frame2, frame3]
    public var walk: [Direction: [SpriteData]]
    /// type[direction] = [frame0, frame1]
    public var typing: [Direction: [SpriteData]]
    /// idle: 정면 1프레임
    public var idle: [Direction: SpriteData]

    public init(walk: [Direction: [SpriteData]], typing: [Direction: [SpriteData]], idle: [Direction: SpriteData]) {
        self.walk = walk
        self.typing = typing
        self.idle = idle
    }
}

// MARK: - Tile Type

public enum TileType: Int, Codable {
    case void = 0
    case wall = 1
    case floor1 = 2       // 기본 회색 타일
    case floor2 = 3       // 밝은 타일 (팬트리)
    case floor3 = 4       // 나무 바닥
    case carpet = 5       // 카펫 (미팅룸)
    case door = 6

    public var isWalkable: Bool {
        switch self {
        case .void, .wall: return false
        default: return true
        }
    }
}

// MARK: - Office Preset

public enum OfficePreset: String, Codable, CaseIterable, Identifiable {
    case cozy
    case collaboration
    case focus

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cozy: return NSLocalizedString("preset.cozy", comment: "")
        case .collaboration: return NSLocalizedString("preset.collab", comment: "")
        case .focus: return NSLocalizedString("preset.focus", comment: "")
        }
    }

    public var subtitle: String {
        switch self {
        case .cozy: return NSLocalizedString("preset.cozy.desc", comment: "")
        case .collaboration: return NSLocalizedString("preset.collab.desc", comment: "")
        case .focus: return NSLocalizedString("preset.focus.desc", comment: "")
        }
    }

    public var icon: String {
        switch self {
        case .cozy: return "house.fill"
        case .collaboration: return "person.3.fill"
        case .focus: return "scope"
        }
    }
}

// MARK: - Office Zone

public enum OfficeZone: String, Codable, CaseIterable {
    case mainOffice = "OFFICE"
    case pantry = "PANTRY"
    case meetingRoom = "MEETING"
    case hallway = "HALL"
}

// MARK: - Furniture

public enum FurnitureType: String, Codable, CaseIterable {
    case desk, chair, monitor, bookshelf, plant, coffeeMachine
    case sofa, roundTable, whiteboard, waterCooler, printer
    case trashBin, lamp, rug, pictureFrame, clock
    case plugin
}

public struct TileSize: Codable, Hashable {
    public let w: Int
    public let h: Int

    public init(w: Int, h: Int) {
        self.w = w
        self.h = h
    }
}

public struct FurniturePlacement: Identifiable, Codable, Hashable {
    public let id: String
    public let type: FurnitureType
    public var position: TileCoord
    public let size: TileSize
    public var zone: OfficeZone
    public var mirrored: Bool = false
    public var pluginFurnitureId: String?

    public init(id: String, type: FurnitureType, position: TileCoord, size: TileSize, zone: OfficeZone, mirrored: Bool = false, pluginFurnitureId: String? = nil) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.zone = zone
        self.pluginFurnitureId = pluginFurnitureId
        self.mirrored = mirrored
    }

    /// Z-sort용 하단 Y값 (픽셀)
    public var zY: CGFloat {
        if type == .rug {
            return CGFloat(position.row) * OfficeConstants.tileSize + 1
        }
        if type == .pictureFrame || type == .clock || type == .whiteboard {
            return CGFloat(position.row) * OfficeConstants.tileSize + 2
        }
        return CGFloat(position.row + size.h) * OfficeConstants.tileSize
    }

    public static func == (lhs: FurniturePlacement, rhs: FurniturePlacement) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Seat

public struct Seat: Identifiable, Codable {
    public let id: String
    public let position: TileCoord
    public let deskId: String
    public let facing: Direction
    public var assignedTabId: String?

    public init(id: String, position: TileCoord, deskId: String, facing: Direction, assignedTabId: String? = nil) {
        self.id = id
        self.position = position
        self.deskId = deskId
        self.facing = facing
        self.assignedTabId = assignedTabId
    }
}

// MARK: - Character State

public enum OfficeCharacterState: Equatable {
    case sittingIdle
    case typing
    case thinking
    case searching
    case reading
    case celebrating
    case error
    case walkingTo(TileCoord)
    case wandering           // 비활성 시 돌아다니기
    case wanderPause         // 돌아다니다 멈춤
    case onBreak             // 팬트리에서 쉬기
    case seatRest            // 자리에서 쉬기
}

public enum OfficeSocialMode: Equatable {
    case greeting
    case chatting
    case brainstorming
    case coffee
    case highFive
}

public enum OfficeDestinationPurpose: Equatable {
    case seat
    case thinking
    case searching
    case reading
    case error
    case breakSpot
}

// MARK: - Office Character (런타임)

public struct OfficeCharacter {
    public var tabId: String? = nil
    public var rosterCharacterId: String? = nil
    public var displayName: String = ""
    public var accentColorHex: String = "5B9CF6"
    public var jobRole: WorkerJob = .developer
    public var isRosterOnly: Bool = false
    public var seatGroupKey: String
    public var groupId: String?
    public var groupIndex: Int = 0
    public var groupSize: Int = 1
    public var usesSeatPose: Bool = true
    public var pixelX: CGFloat
    public var pixelY: CGFloat
    public var tileCol: Int
    public var tileRow: Int
    public var targetTile: TileCoord?
    public var path: [TileCoord] = []
    public var state: OfficeCharacterState = .sittingIdle
    public var dir: Direction = .down
    public var frame: Int = 0
    public var frameTimer: Double = 0
    public var seatId: String?
    public var moveProgress: CGFloat = 0
    public var isActive: Bool = true
    public var activity: ClaudeActivity = .idle
    public var destinationPurpose: OfficeDestinationPurpose = .seat
    public var stateHoldTimer: Double = 0

    // Wander 행동
    public var wanderTimer: Double = 0
    public var wanderCount: Int = 0
    public var wanderLimit: Int = 3
    public var seatTimer: Double = 0
    public var socialMode: OfficeSocialMode? = nil
    public var socialRole: Int = 0
    public var socialTimer: Double = 0
    public var socialCooldown: Double = 0
    public var socialPartnerKey: String? = nil
    public var socialFocusTile: TileCoord? = nil
    public var recentBreakTargets: [TileCoord] = []

    public var tileCoord: TileCoord { TileCoord(col: tileCol, row: tileRow) }

    /// Z-sort용 Y (하단 기준)
    public var zY: CGFloat { pixelY + OfficeConstants.tileSize / 2 }

    public init(
        tabId: String? = nil, rosterCharacterId: String? = nil, displayName: String = "",
        accentColorHex: String = "5B9CF6", jobRole: WorkerJob = .developer, isRosterOnly: Bool = false,
        seatGroupKey: String, groupId: String? = nil, groupIndex: Int = 0, groupSize: Int = 1,
        usesSeatPose: Bool = true, pixelX: CGFloat, pixelY: CGFloat, tileCol: Int, tileRow: Int,
        targetTile: TileCoord? = nil, path: [TileCoord] = [], state: OfficeCharacterState = .sittingIdle,
        dir: Direction = .down, frame: Int = 0, frameTimer: Double = 0, seatId: String? = nil,
        moveProgress: CGFloat = 0, isActive: Bool = true, activity: ClaudeActivity = .idle,
        destinationPurpose: OfficeDestinationPurpose = .seat, stateHoldTimer: Double = 0,
        seatTimer: Double = 0
    ) {
        self.tabId = tabId; self.rosterCharacterId = rosterCharacterId; self.displayName = displayName
        self.accentColorHex = accentColorHex; self.jobRole = jobRole; self.isRosterOnly = isRosterOnly
        self.seatGroupKey = seatGroupKey; self.groupId = groupId; self.groupIndex = groupIndex; self.groupSize = groupSize
        self.usesSeatPose = usesSeatPose; self.pixelX = pixelX; self.pixelY = pixelY
        self.tileCol = tileCol; self.tileRow = tileRow; self.targetTile = targetTile; self.path = path
        self.state = state; self.dir = dir; self.frame = frame; self.frameTimer = frameTimer
        self.seatId = seatId; self.moveProgress = moveProgress; self.isActive = isActive
        self.activity = activity; self.destinationPurpose = destinationPurpose; self.stateHoldTimer = stateHoldTimer
        self.seatTimer = seatTimer
    }
}

// MARK: - Z-Sortable Drawable (value-type, no closure heap allocation)

public struct ZDrawable {
    public let zY: CGFloat
    public let kind: ZDrawableKind

    public init(zY: CGFloat, kind: ZDrawableKind) {
        self.zY = zY
        self.kind = kind
    }
}

public enum ZDrawableKind {
    case furniture(ZFurnitureInfo)
    case character(ZCharacterInfo)
}

public struct ZFurnitureInfo {
    public let type: FurnitureType
    public let x: CGFloat
    public let y: CGFloat
    public let w: CGFloat
    public let h: CGFloat
    public let dark: Bool
    public let frame: Int
    public let chromeImage: CGImage?
    public let pluginFurnitureId: String?

    public init(type: FurnitureType, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int, chromeImage: CGImage?, pluginFurnitureId: String? = nil) {
        self.type = type; self.x = x; self.y = y; self.w = w; self.h = h
        self.dark = dark; self.frame = frame; self.chromeImage = chromeImage
        self.pluginFurnitureId = pluginFurnitureId
    }
}

public struct ZCharacterInfo {
    public let char: OfficeCharacter
    public let workerColor: Color
    public let hashVal: Int
    public let dir: Direction
    public let state: OfficeCharacterState
    public let frame: Int
    public let dark: Bool
    public let rosterCharacter: WorkerCharacter?

    public init(char: OfficeCharacter, workerColor: Color, hashVal: Int, dir: Direction, state: OfficeCharacterState, frame: Int, dark: Bool, rosterCharacter: WorkerCharacter?) {
        self.char = char; self.workerColor = workerColor; self.hashVal = hashVal; self.dir = dir
        self.state = state; self.frame = frame; self.dark = dark; self.rosterCharacter = rosterCharacter
    }
}

// MARK: - Constants

public enum OfficeConstants {
    public static let tileSize: CGFloat = 16
    public static let walkSpeed: CGFloat = 56           // px/sec
    public static let walkFrameDuration: Double = 0.15  // 초당 프레임 전환
    public static let typeFrameDuration: Double = 0.3
    public static let wanderPauseMin: Double = 2.0
    public static let wanderPauseMax: Double = 5.0
    public static let wanderMovesMin: Int = 2
    public static let wanderMovesMax: Int = 5
    public static let seatRestMin: Double = 3.0
    public static let seatRestMax: Double = 8.0
    public static let relaxedWanderPauseMin: Double = 0.8
    public static let relaxedWanderPauseMax: Double = 2.2
    public static let relaxedWanderMovesMin: Int = 3
    public static let relaxedWanderMovesMax: Int = 7
    public static let relaxedSeatRestMin: Double = 1.5
    public static let relaxedSeatRestMax: Double = 4.0
    public static let socialInteractionMin: Double = 2.5
    public static let socialInteractionMax: Double = 5.5
    public static let socialCooldownMin: Double = 4.0
    public static let socialCooldownMax: Double = 8.5
    public static let socialEventCooldownMin: Double = 1.4
    public static let socialEventCooldownMax: Double = 3.2
    public static let socialScanInterval: Double = 1.5
    public static let recentBreakTargetLimit: Int = 3
    public static let fps: Double = 24.0
    public static let charSittingOffset: CGFloat = 3    // 앉을 때 Y 오프셋
}
