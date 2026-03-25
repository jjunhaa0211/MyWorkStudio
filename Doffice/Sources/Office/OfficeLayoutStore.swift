import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Office Layout Persistence
// ═══════════════════════════════════════════════════════

struct OfficeLayoutSnapshot: Codable {
    let cols: Int
    let rows: Int
    var tiles: [[TileType]]
    var zones: [[OfficeZone?]]
    var furniture: [FurniturePlacement]
    var seats: [Seat]
}

final class OfficeLayoutStore {
    static let shared = OfficeLayoutStore()

    private let keyPrefix = "workman.office.layout"
    private let defaults = UserDefaults.standard

    private func key(for preset: OfficePreset) -> String {
        "\(keyPrefix).\(preset.rawValue).v1"
    }

    func applyStoredLayout(to map: OfficeMap, preset: OfficePreset) {
        guard
            let data = defaults.data(forKey: key(for: preset)),
            let snapshot = try? JSONDecoder().decode(OfficeLayoutSnapshot.self, from: data)
        else {
            return
        }
        map.applyLayoutSnapshot(snapshot)
    }

    func saveLayout(from map: OfficeMap, preset: OfficePreset) {
        guard let data = try? JSONEncoder().encode(map.layoutSnapshot()) else { return }
        defaults.set(data, forKey: key(for: preset))
    }

    func resetSavedLayout(preset: OfficePreset) {
        defaults.removeObject(forKey: key(for: preset))
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Office Map Layout Editing
// ═══════════════════════════════════════════════════════

extension OfficeMap {
    func layoutSnapshot() -> OfficeLayoutSnapshot {
        OfficeLayoutSnapshot(
            cols: cols,
            rows: rows,
            tiles: tiles,
            zones: zones,
            furniture: furniture,
            seats: seats.map {
                Seat(
                    id: $0.id,
                    position: $0.position,
                    deskId: $0.deskId,
                    facing: $0.facing,
                    assignedTabId: nil
                )
            }
        )
    }

    func applyLayoutSnapshot(_ snapshot: OfficeLayoutSnapshot) {
        guard snapshot.cols == cols, snapshot.rows == rows else { return }
        tiles = snapshot.tiles
        zones = snapshot.zones
        furniture = snapshot.furniture
        seats = snapshot.seats.map {
            Seat(
                id: $0.id,
                position: $0.position,
                deskId: $0.deskId,
                facing: $0.facing,
                assignedTabId: nil
            )
        }
        rebuildWalkability()
    }

    func selectedFurniture(at coord: TileCoord) -> FurniturePlacement? {
        furniture
            .sorted { $0.zY < $1.zY }
            .reversed()
            .first { placement in
                coord.col >= placement.position.col &&
                coord.col < placement.position.col + placement.size.w &&
                coord.row >= placement.position.row &&
                coord.row < placement.position.row + placement.size.h
            }
    }

    func movableAnchorId(for furnitureId: String) -> String {
        if furnitureId.hasPrefix("desk_") { return furnitureId }
        if furnitureId.hasPrefix("mon_") || furnitureId.hasPrefix("chair_") || furnitureId.hasPrefix("seat_") {
            let suffix = furnitureId.split(separator: "_").last.map(String.init) ?? ""
            return "desk_\(suffix)"
        }
        return furnitureId
    }

    func placeFurnitureGroup(anchorId: String, at newPosition: TileCoord) -> Bool {
        guard let anchor = furniture.first(where: { $0.id == anchorId }) else { return false }

        let groupIds = groupedFurnitureIds(for: anchorId)
        let ignored = Set(groupIds)
        let delta = TileCoord(col: newPosition.col - anchor.position.col, row: newPosition.row - anchor.position.row)

        var proposedFurniture: [String: TileCoord] = [:]
        for item in furniture where ignored.contains(item.id) {
            proposedFurniture[item.id] = TileCoord(col: item.position.col + delta.col, row: item.position.row + delta.row)
        }

        var proposedSeats: [String: TileCoord] = [:]
        for seat in seats where seat.deskId == anchorId {
            proposedSeats[seat.id] = TileCoord(col: seat.position.col + delta.col, row: seat.position.row + delta.row)
        }

        for item in furniture where ignored.contains(item.id) {
            guard let position = proposedFurniture[item.id] else { return false }
            guard isPlacementValid(item, at: position, ignoring: ignored) else { return false }
        }

        for seat in seats where seat.deskId == anchorId {
            guard let position = proposedSeats[seat.id] else { return false }
            guard isSeatValid(at: position, ignoring: ignored) else { return false }
        }

        for index in furniture.indices where ignored.contains(furniture[index].id) {
            if let position = proposedFurniture[furniture[index].id] {
                furniture[index].position = position
            }
        }

        for index in seats.indices where seats[index].deskId == anchorId {
            if let position = proposedSeats[seats[index].id] {
                seats[index] = Seat(
                    id: seats[index].id,
                    position: position,
                    deskId: seats[index].deskId,
                    facing: seats[index].facing,
                    assignedTabId: seats[index].assignedTabId
                )
            }
        }

        rebuildWalkability()
        return true
    }

    private func groupedFurnitureIds(for anchorId: String) -> [String] {
        guard anchorId.hasPrefix("desk_"),
              let suffix = anchorId.split(separator: "_").last
        else {
            return [anchorId]
        }

        return [
            anchorId,
            "mon_\(suffix)",
            "chair_\(suffix)"
        ]
    }

    private func isPlacementValid(_ item: FurniturePlacement, at position: TileCoord, ignoring ignoredIds: Set<String>) -> Bool {
        for row in 0..<item.size.h {
            for col in 0..<item.size.w {
                let coord = TileCoord(col: position.col + col, row: position.row + row)
                guard isInBounds(coord) else { return false }

                let tile = tileAt(coord)
                if OfficeLayoutCollision.isWallMounted(item.type) {
                    guard tile == .wall else { return false }
                } else {
                    guard tile.isWalkable, tile != .door else { return false }
                }
            }
        }

        for other in furniture where !ignoredIds.contains(other.id) {
            if OfficeLayoutCollision.canOverlap(item.type, with: other.type) { continue }
            if OfficeLayoutCollision.rectsIntersect(
                lhsPosition: position,
                lhsSize: item.size,
                rhsPosition: other.position,
                rhsSize: other.size
            ) {
                return false
            }
        }

        return true
    }

    private func isSeatValid(at position: TileCoord, ignoring ignoredIds: Set<String>) -> Bool {
        guard isInBounds(position) else { return false }
        let tile = tileAt(position)
        guard tile.isWalkable, tile != .door else { return false }

        for other in furniture where !ignoredIds.contains(other.id) {
            if OfficeLayoutCollision.isWallMounted(other.type) || other.type == .chair || other.type == .rug {
                continue
            }
            if OfficeLayoutCollision.rectContains(position, topLeft: other.position, size: other.size) {
                return false
            }
        }

        return true
    }
}

private enum OfficeLayoutCollision {
    static func isWallMounted(_ type: FurnitureType) -> Bool {
        [.pictureFrame, .clock, .whiteboard].contains(type)
    }

    static func canOverlap(_ lhs: FurnitureType, with rhs: FurnitureType) -> Bool {
        if lhs == .rug || rhs == .rug { return true }
        let lhsWall = isWallMounted(lhs)
        let rhsWall = isWallMounted(rhs)
        return lhsWall != rhsWall
    }

    static func rectContains(_ coord: TileCoord, topLeft: TileCoord, size: TileSize) -> Bool {
        coord.col >= topLeft.col &&
        coord.col < topLeft.col + size.w &&
        coord.row >= topLeft.row &&
        coord.row < topLeft.row + size.h
    }

    static func rectsIntersect(lhsPosition: TileCoord, lhsSize: TileSize, rhsPosition: TileCoord, rhsSize: TileSize) -> Bool {
        let lhsRight = lhsPosition.col + lhsSize.w
        let lhsBottom = lhsPosition.row + lhsSize.h
        let rhsRight = rhsPosition.col + rhsSize.w
        let rhsBottom = rhsPosition.row + rhsSize.h

        return lhsPosition.col < rhsRight &&
        lhsRight > rhsPosition.col &&
        lhsPosition.row < rhsBottom &&
        lhsBottom > rhsPosition.row
    }
}
