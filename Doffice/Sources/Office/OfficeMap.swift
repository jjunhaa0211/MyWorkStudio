import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Office Map (타일맵 + 가구 + 좌석)
// ═══════════════════════════════════════════════════════

class OfficeMap: ObservableObject {
    let cols: Int
    let rows: Int
    var tiles: [[TileType]]
    var zones: [[OfficeZone?]]
    @Published var furniture: [FurniturePlacement]
    @Published var seats: [Seat]
    private var _walkable: [[Bool]]

    init(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
        self.tiles = Array(repeating: Array(repeating: TileType.void, count: cols), count: rows)
        self.zones = Array(repeating: Array(repeating: nil as OfficeZone?, count: cols), count: rows)
        self.furniture = []
        self.seats = []
        self._walkable = Array(repeating: Array(repeating: true, count: cols), count: rows)
    }

    // MARK: - Queries

    func isInBounds(_ c: TileCoord) -> Bool {
        c.col >= 0 && c.col < cols && c.row >= 0 && c.row < rows
    }

    func isWalkable(_ c: TileCoord) -> Bool {
        guard isInBounds(c) else { return false }
        return _walkable[c.row][c.col]
    }

    func tileAt(_ c: TileCoord) -> TileType {
        guard isInBounds(c) else { return .void }
        return tiles[c.row][c.col]
    }

    func zoneAt(_ c: TileCoord) -> OfficeZone? {
        guard isInBounds(c) else { return nil }
        return zones[c.row][c.col]
    }

    // MARK: - Walkability

    func rebuildWalkability() {
        invalidatePathCache()
        _walkable = Array(repeating: Array(repeating: false, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                let t = tiles[r][c]
                _walkable[r][c] = t.isWalkable
            }
        }
        // 가구가 있는 곳은 걸을 수 없음 (의자, 러그 제외)
        for f in furniture {
            let walkableTypes: Set<FurnitureType> = [.rug, .chair]
            if walkableTypes.contains(f.type) { continue }
            for dr in 0..<f.size.h {
                for dc in 0..<f.size.w {
                    let r = f.position.row + dr
                    let c = f.position.col + dc
                    if r >= 0 && r < rows && c >= 0 && c < cols {
                        _walkable[r][c] = false
                    }
                }
            }
        }
    }

    // MARK: - A* Pathfinding (with cache)

    /// 최근 경로 캐시 — 같은 출발/도착점 중복 계산 방지
    private var _pathCache: [UInt64: [TileCoord]] = [:]
    private var _pathCacheAge: Int = 0
    private static let pathCacheMaxSize = 64

    private func pathCacheKey(_ from: TileCoord, _ to: TileCoord) -> UInt64 {
        UInt64(from.col) | (UInt64(from.row) << 16) | (UInt64(to.col) << 32) | (UInt64(to.row) << 48)
    }

    /// 경로 캐시 무효화 (가구 배치 변경 시)
    func invalidatePathCache() { _pathCache.removeAll() }

    func findPath(from start: TileCoord, to end: TileCoord) -> [TileCoord] {
        guard isInBounds(start), isInBounds(end) else { return [] }
        guard isWalkable(end) else {
            for d in Direction.allCases {
                let adj = end + d.delta
                if isWalkable(adj) { return findPath(from: start, to: adj) }
            }
            return []
        }
        if start == end { return [] }

        // 캐시 확인
        let key = pathCacheKey(start, end)
        if let cached = _pathCache[key] { return cached }

        // 캐시가 너무 크면 절반 제거
        _pathCacheAge += 1
        if _pathCache.count > Self.pathCacheMaxSize {
            _pathCache.removeAll(keepingCapacity: true)
        }

        struct Node {
            let coord: TileCoord
            let g: Int
            let f: Int
        }

        // Binary search insertion into descending-sorted array (best node at end for O(1) pop).
        func insertSorted(_ node: Node, into array: inout [Node]) {
            var lo = 0, hi = array.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if array[mid].f > node.f { lo = mid + 1 } else { hi = mid }
            }
            array.insert(node, at: lo)
        }

        var open: [Node] = [Node(coord: start, g: 0, f: start.distance(to: end))]
        var closed = Set<TileCoord>()
        var came: [TileCoord: TileCoord] = [:]
        var gScore: [TileCoord: Int] = [start: 0]

        while !open.isEmpty {
            let current = open.removeLast() // best f-score (smallest) is at end
            if current.coord == end {
                // O(n) 재구성: append + reverse (insert(at:0)은 O(n²))
                var path: [TileCoord] = [end]
                var c = end
                while let prev = came[c] { path.append(prev); c = prev }
                path.reverse()
                if !path.isEmpty { path.removeFirst() } // start 제거
                _pathCache[key] = path
                return path
            }
            if closed.contains(current.coord) { continue }
            closed.insert(current.coord)
            for d in Direction.allCases {
                let neighbor = current.coord + d.delta
                guard isWalkable(neighbor), !closed.contains(neighbor) else { continue }
                let g = current.g + 1
                if g < (gScore[neighbor] ?? Int.max) {
                    gScore[neighbor] = g
                    came[neighbor] = current.coord
                    let f = g + neighbor.distance(to: end)
                    insertSorted(Node(coord: neighbor, g: g, f: f), into: &open)
                }
            }
        }
        _pathCache[key] = []
        return [] // 경로 없음
    }

    // MARK: - Default Layout

    static func defaultOffice(preset: OfficePreset = .cozy) -> OfficeMap {
        let cols = 42
        let rows = 20
        let map = OfficeMap(cols: cols, rows: rows)

        // ── 벽 그리기 ──
        for c in 0..<cols {
            map.tiles[0][c] = .wall        // 상단 벽
            map.tiles[1][c] = .wall        // 벽 상단 두께
            map.tiles[rows-1][c] = .wall   // 하단 벽
        }
        for r in 0..<rows {
            map.tiles[r][0] = .wall        // 좌측 벽
            map.tiles[r][cols-1] = .wall   // 우측 벽
        }

        // ── 내부 벽 (존 구분) ──
        // 세로 벽: col=28 (메인오피스 | 팬트리+미팅)
        for r in 0..<rows {
            map.tiles[r][28] = .wall
        }
        // 가로 벽: row=11 (팬트리 | 미팅룸) — col 29~41
        for c in 29..<cols-1 {
            map.tiles[11][c] = .wall
        }

        // ── 문 ──
        map.tiles[6][28] = .door   // 메인→팬트리
        map.tiles[7][28] = .door
        map.tiles[14][28] = .door  // 메인→미팅룸
        map.tiles[15][28] = .door

        // ── 바닥 채우기 ──
        // 메인 오피스 (col 1~27, row 2~18)
        for r in 2..<rows-1 {
            for c in 1..<28 {
                map.tiles[r][c] = .floor1
                map.zones[r][c] = .mainOffice
            }
        }
        // 팬트리 (col 29~40, row 2~10)
        for r in 2..<11 {
            for c in 29..<cols-1 {
                map.tiles[r][c] = .floor2
                map.zones[r][c] = .pantry
            }
        }
        // 미팅룸 (col 29~40, row 12~18)
        for r in 12..<rows-1 {
            for c in 29..<cols-1 {
                map.tiles[r][c] = .carpet
                map.zones[r][c] = .meetingRoom
            }
        }

        // ── 가구 배치 ──
        var furnitureList: [FurniturePlacement] = []
        var seatList: [Seat] = []
        var deskIdx = 0

        // 메인 오피스: 책상 3줄 x 4열
        for row in [4, 8, 12] {
            for col in [3, 8, 13, 18] {
                let deskId = "desk_\(deskIdx)"
                furnitureList.append(FurniturePlacement(
                    id: deskId, type: .desk, position: TileCoord(col: col, row: row),
                    size: TileSize(w: 3, h: 1), zone: .mainOffice
                ))
                // 모니터
                furnitureList.append(FurniturePlacement(
                    id: "mon_\(deskIdx)", type: .monitor, position: TileCoord(col: col + 1, row: row),
                    size: TileSize(w: 1, h: 1), zone: .mainOffice
                ))
                // 의자 (책상 아래)
                furnitureList.append(FurniturePlacement(
                    id: "chair_\(deskIdx)", type: .chair, position: TileCoord(col: col + 1, row: row + 1),
                    size: TileSize(w: 1, h: 1), zone: .mainOffice
                ))
                // 좌석
                seatList.append(Seat(
                    id: "seat_\(deskIdx)", position: TileCoord(col: col + 1, row: row + 1),
                    deskId: deskId, facing: .up
                ))
                deskIdx += 1
            }
        }

        // 메인 오피스: 책상 군집마다 러그를 깔고, 상단 벽은 서가/액자로 채워서 게임 맵처럼 보이게
        furnitureList.append(FurniturePlacement(id: "rug_office_0", type: .rug, position: TileCoord(col: 2, row: 4), size: TileSize(w: 10, h: 5), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "rug_office_1", type: .rug, position: TileCoord(col: 12, row: 4), size: TileSize(w: 10, h: 5), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "rug_office_2", type: .rug, position: TileCoord(col: 2, row: 11), size: TileSize(w: 10, h: 5), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "rug_office_3", type: .rug, position: TileCoord(col: 12, row: 11), size: TileSize(w: 10, h: 5), zone: .mainOffice))

        for (idx, col) in [2, 7, 12, 17, 22].enumerated() {
            furnitureList.append(FurniturePlacement(
                id: "bookshelf_top_\(idx)",
                type: .bookshelf,
                position: TileCoord(col: col, row: 2),
                size: TileSize(w: 2, h: 1),
                zone: .mainOffice
            ))
        }

        furnitureList.append(FurniturePlacement(id: "bookshelf_side_0", type: .bookshelf, position: TileCoord(col: 24, row: 6), size: TileSize(w: 2, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "bookshelf_side_1", type: .bookshelf, position: TileCoord(col: 24, row: 10), size: TileSize(w: 2, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "printer_0", type: .printer, position: TileCoord(col: 23, row: 16), size: TileSize(w: 2, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "trash_0", type: .trashBin, position: TileCoord(col: 25, row: 16), size: TileSize(w: 1, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "picture_office_0", type: .pictureFrame, position: TileCoord(col: 4, row: 1), size: TileSize(w: 3, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "picture_office_1", type: .pictureFrame, position: TileCoord(col: 11, row: 1), size: TileSize(w: 3, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "picture_office_2", type: .pictureFrame, position: TileCoord(col: 18, row: 1), size: TileSize(w: 3, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "plant_0", type: .plant, position: TileCoord(col: 1, row: 2), size: TileSize(w: 1, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "plant_1", type: .plant, position: TileCoord(col: 26, row: 2), size: TileSize(w: 1, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "plant_2", type: .plant, position: TileCoord(col: 1, row: 17), size: TileSize(w: 1, h: 1), zone: .mainOffice))
        furnitureList.append(FurniturePlacement(id: "plant_3", type: .plant, position: TileCoord(col: 26, row: 17), size: TileSize(w: 1, h: 1), zone: .mainOffice))

        // 팬트리
        furnitureList.append(FurniturePlacement(id: "rug_pantry_0", type: .rug, position: TileCoord(col: 33, row: 3), size: TileSize(w: 7, h: 5), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "coffee_0", type: .coffeeMachine, position: TileCoord(col: 30, row: 2), size: TileSize(w: 1, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "water_0", type: .waterCooler, position: TileCoord(col: 32, row: 2), size: TileSize(w: 1, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "sofa_0", type: .sofa, position: TileCoord(col: 35, row: 3), size: TileSize(w: 3, h: 2), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "rtable_0", type: .roundTable, position: TileCoord(col: 36, row: 6), size: TileSize(w: 2, h: 2), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "chair_p0", type: .chair, position: TileCoord(col: 35, row: 6), size: TileSize(w: 1, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "chair_p1", type: .chair, position: TileCoord(col: 38, row: 6), size: TileSize(w: 1, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "chair_p2", type: .chair, position: TileCoord(col: 36, row: 8), size: TileSize(w: 1, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "chair_p3", type: .chair, position: TileCoord(col: 37, row: 8), size: TileSize(w: 1, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "bookshelf_pantry", type: .bookshelf, position: TileCoord(col: 33, row: 9), size: TileSize(w: 2, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "picture_pantry", type: .pictureFrame, position: TileCoord(col: 34, row: 1), size: TileSize(w: 3, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "plant_p0", type: .plant, position: TileCoord(col: 39, row: 2), size: TileSize(w: 1, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "plant_p1", type: .plant, position: TileCoord(col: 30, row: 9), size: TileSize(w: 1, h: 1), zone: .pantry))
        furnitureList.append(FurniturePlacement(id: "plant_p2", type: .plant, position: TileCoord(col: 39, row: 9), size: TileSize(w: 1, h: 1), zone: .pantry))

        // 미팅룸
        furnitureList.append(FurniturePlacement(id: "rug_meeting_0", type: .rug, position: TileCoord(col: 31, row: 13), size: TileSize(w: 8, h: 5), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "wb_0", type: .whiteboard, position: TileCoord(col: 31, row: 11), size: TileSize(w: 4, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "picture_meeting", type: .pictureFrame, position: TileCoord(col: 37, row: 11), size: TileSize(w: 3, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "mtable_0", type: .roundTable, position: TileCoord(col: 33, row: 14), size: TileSize(w: 4, h: 3), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "chair_m0", type: .chair, position: TileCoord(col: 33, row: 13), size: TileSize(w: 1, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "chair_m1", type: .chair, position: TileCoord(col: 36, row: 13), size: TileSize(w: 1, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "chair_m2", type: .chair, position: TileCoord(col: 33, row: 17), size: TileSize(w: 1, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "chair_m3", type: .chair, position: TileCoord(col: 36, row: 17), size: TileSize(w: 1, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "bookshelf_meeting_0", type: .bookshelf, position: TileCoord(col: 30, row: 17), size: TileSize(w: 2, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "bookshelf_meeting_1", type: .bookshelf, position: TileCoord(col: 38, row: 17), size: TileSize(w: 2, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "plant_m0", type: .plant, position: TileCoord(col: 39, row: 12), size: TileSize(w: 1, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "plant_m1", type: .plant, position: TileCoord(col: 29, row: 17), size: TileSize(w: 1, h: 1), zone: .meetingRoom))
        furnitureList.append(FurniturePlacement(id: "lamp_m0", type: .lamp, position: TileCoord(col: 39, row: 17), size: TileSize(w: 1, h: 1), zone: .meetingRoom))

        map.furniture = furnitureList
        map.seats = seatList
        applyPresetDecor(preset, to: map)
        map.rebuildWalkability()
        return map
    }

    static func defaultLayoutSnapshot(preset: OfficePreset = .cozy) -> OfficeLayoutSnapshot {
        defaultOffice(preset: preset).layoutSnapshot()
    }

    private static func applyPresetDecor(_ preset: OfficePreset, to map: OfficeMap) {
        switch preset {
        case .cozy:
            return
        case .collaboration:
            upsertFurniture(
                FurniturePlacement(
                    id: "whiteboard_collab_main",
                    type: .whiteboard,
                    position: TileCoord(col: 22, row: 1),
                    size: TileSize(w: 4, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "collab_table_main",
                    type: .roundTable,
                    position: TileCoord(col: 23, row: 12),
                    size: TileSize(w: 3, h: 3),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "collab_chair_main_0",
                    type: .chair,
                    position: TileCoord(col: 22, row: 12),
                    size: TileSize(w: 1, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "collab_chair_main_1",
                    type: .chair,
                    position: TileCoord(col: 26, row: 12),
                    size: TileSize(w: 1, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "collab_chair_main_2",
                    type: .chair,
                    position: TileCoord(col: 23, row: 15),
                    size: TileSize(w: 1, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "collab_chair_main_3",
                    type: .chair,
                    position: TileCoord(col: 25, row: 15),
                    size: TileSize(w: 1, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "plant_collab_corner",
                    type: .plant,
                    position: TileCoord(col: 27, row: 12),
                    size: TileSize(w: 1, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "bookshelf_collab_meeting",
                    type: .bookshelf,
                    position: TileCoord(col: 30, row: 12),
                    size: TileSize(w: 2, h: 1),
                    zone: .meetingRoom
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "lamp_collab_meeting",
                    type: .lamp,
                    position: TileCoord(col: 30, row: 17),
                    size: TileSize(w: 1, h: 1),
                    zone: .meetingRoom
                ),
                into: map
            )

        case .focus:
            upsertFurniture(
                FurniturePlacement(
                    id: "focus_bookshelf_0",
                    type: .bookshelf,
                    position: TileCoord(col: 24, row: 4),
                    size: TileSize(w: 2, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "focus_bookshelf_1",
                    type: .bookshelf,
                    position: TileCoord(col: 24, row: 14),
                    size: TileSize(w: 2, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "focus_lamp_0",
                    type: .lamp,
                    position: TileCoord(col: 27, row: 16),
                    size: TileSize(w: 1, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "focus_picture_extra",
                    type: .pictureFrame,
                    position: TileCoord(col: 23, row: 1),
                    size: TileSize(w: 3, h: 1),
                    zone: .mainOffice
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "focus_side_table",
                    type: .roundTable,
                    position: TileCoord(col: 30, row: 14),
                    size: TileSize(w: 2, h: 2),
                    zone: .meetingRoom
                ),
                into: map
            )
            upsertFurniture(
                FurniturePlacement(
                    id: "focus_side_chair",
                    type: .chair,
                    position: TileCoord(col: 30, row: 13),
                    size: TileSize(w: 1, h: 1),
                    zone: .meetingRoom
                ),
                into: map
            )
        }
    }

    private static func upsertFurniture(_ placement: FurniturePlacement, into map: OfficeMap) {
        if let index = map.furniture.firstIndex(where: { $0.id == placement.id }) {
            map.furniture[index] = placement
        } else {
            map.furniture.append(placement)
        }
    }
}
