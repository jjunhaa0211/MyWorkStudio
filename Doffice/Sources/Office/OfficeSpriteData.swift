import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Sprite Data Definitions (픽셀 아트 데이터)
// ═══════════════════════════════════════════════════════

// SpriteData = [[String]] — 각 셀은 hex 색상, "" = 투명
// 캐릭터: 16x24 (w x h), 가구: 가변

enum SpriteCatalog {

    private static func replacingRows(_ sprite: SpriteData, with replacements: [Int: [String]]) -> SpriteData {
        var copy = sprite
        for (row, pixels) in replacements {
            guard row >= 0 && row < copy.count, pixels.count == copy[row].count else { continue }
            copy[row] = pixels
        }
        return copy
    }

    // MARK: - Character Sprites (16x24, 탑다운)

    /// 기본 캐릭터 — skin/shirt/pants 플레이스홀더를 런타임에 교체
    /// S = skin, H = hair, T = shirt, P = pants, E = eye, . = transparent
    /// 실제 hex로 치환하는 함수: resolveCharacter()

    // ── 정면 (down) idle ──
    static let charDownIdle: [[String]] = [
        // row 0-3: 머리카락
        ["","","","","","H","H","H","H","H","H","","","","",""],
        ["","","","","H","H","H","H","H","H","H","H","","","",""],
        ["","","","H","H","H","H","H","H","H","H","H","H","","",""],
        ["","","","H","H","H","H","H","H","H","H","H","H","","",""],
        // row 4-8: 얼굴
        ["","","","H","S","S","S","S","S","S","S","S","H","","",""],
        ["","","","","S","S","S","S","S","S","S","S","","","",""],
        ["","","","","S","E","E","S","S","E","E","S","","","",""],
        ["","","","","S","S","S","S","S","S","S","S","","","",""],
        ["","","","","S","S","S","M","M","S","S","S","","","",""],
        // row 9-15: 몸통
        ["","","","","T","T","T","T","T","T","T","T","","","",""],
        ["","","","T","T","T","T","T","T","T","T","T","T","","",""],
        ["","","","T","T","T","T","T","T","T","T","T","T","","",""],
        ["","","S","T","T","T","T","T","T","T","T","T","T","S","",""],
        ["","","S","T","T","T","T","T","T","T","T","T","T","S","",""],
        ["","","","T","T","T","T","T","T","T","T","T","T","","",""],
        ["","","","","T","T","T","T","T","T","T","T","","","",""],
        // row 16-19: 바지
        ["","","","","P","P","P","P","P","P","P","P","","","",""],
        ["","","","","P","P","P","","","P","P","P","","","",""],
        ["","","","","P","P","P","","","P","P","P","","","",""],
        // row 20-23: 신발
        ["","","","P","P","P","P","","","P","P","P","P","","",""],
        ["","","","W","W","W","W","","","W","W","W","W","","",""],
        ["","","","","","","","","","","","","","","",""],
        ["","","","","","","","","","","","","","","",""],
        ["","","","","","","","","","","","","","","",""],
    ]

    // ── 정면 walk frame 1 (왼발 앞) ──
    static let charDownWalk1: [[String]] = {
        var s = charDownIdle
        s[17] = ["","","","","","P","P","P","","P","P","","","","",""]
        s[18] = ["","","","","P","P","P","","","P","P","P","","","",""]
        s[19] = ["","","","","P","P","P","","P","P","P","","","","",""]
        s[20] = ["","","","","W","W","W","","W","W","W","W","","","",""]
        return s
    }()

    // ── 정면 walk frame 2 (오른발 앞) ──
    static let charDownWalk2: [[String]] = {
        var s = charDownIdle
        s[17] = ["","","","","","P","P","","P","P","P","","","","",""]
        s[18] = ["","","","","P","P","","","","P","P","P","","","",""]
        s[19] = ["","","","","P","P","P","","","P","P","P","","","",""]
        s[20] = ["","","","","W","W","W","W","","W","W","W","","","",""]
        return s
    }()

    // ── 정면 typing frame 0 ──
    static let charDownType0: [[String]] = {
        var s = charDownIdle
        // 팔 올림 (타이핑 자세)
        s[11] = ["","","S","T","T","T","T","T","T","T","T","T","T","S","",""]
        s[12] = ["","","S","S","T","T","T","T","T","T","T","T","S","S","",""]
        s[13] = ["","","","","T","T","T","T","T","T","T","T","","","",""]
        return s
    }()

    // ── 정면 typing frame 1 ──
    static let charDownType1: [[String]] = {
        var s = charDownIdle
        s[11] = ["","","S","T","T","T","T","T","T","T","T","T","T","S","",""]
        s[12] = ["","S","S","","T","T","T","T","T","T","T","T","","S","S",""]
        s[13] = ["","","","","T","T","T","T","T","T","T","T","","","",""]
        return s
    }()

    // ── 뒷면 (up) idle ──
    static let charUpIdle: [[String]] = [
        ["","","","","","H","H","H","H","H","H","","","","",""],
        ["","","","","H","H","H","H","H","H","H","H","","","",""],
        ["","","","H","H","H","H","H","H","H","H","H","H","","",""],
        ["","","","H","H","H","H","H","H","H","H","H","H","","",""],
        ["","","","H","H","H","H","H","H","H","H","H","H","","",""],
        ["","","","","H","H","H","H","H","H","H","H","","","",""],
        ["","","","","S","S","S","S","S","S","S","S","","","",""],
        ["","","","","S","S","S","S","S","S","S","S","","","",""],
        ["","","","","S","S","S","S","S","S","S","S","","","",""],
        ["","","","","T","T","T","T","T","T","T","T","","","",""],
        ["","","","T","T","T","T","T","T","T","T","T","T","","",""],
        ["","","","T","T","T","T","T","T","T","T","T","T","","",""],
        ["","","S","T","T","T","T","T","T","T","T","T","T","S","",""],
        ["","","S","T","T","T","T","T","T","T","T","T","T","S","",""],
        ["","","","T","T","T","T","T","T","T","T","T","T","","",""],
        ["","","","","T","T","T","T","T","T","T","T","","","",""],
        ["","","","","P","P","P","P","P","P","P","P","","","",""],
        ["","","","","P","P","P","","","P","P","P","","","",""],
        ["","","","","P","P","P","","","P","P","P","","","",""],
        ["","","","P","P","P","P","","","P","P","P","P","","",""],
        ["","","","W","W","W","W","","","W","W","W","W","","",""],
        ["","","","","","","","","","","","","","","",""],
        ["","","","","","","","","","","","","","","",""],
        ["","","","","","","","","","","","","","","",""],
    ]

    static let charUpWalk1: [[String]] = {
        replacingRows(charUpIdle, with: [
            12: ["","","S","T","T","T","T","T","T","T","T","T","T","","",""],
            13: ["","","","","T","T","T","T","T","T","T","T","S","","",""],
            17: ["","","","","","P","P","P","","P","P","","","","",""],
            18: ["","","","","P","P","P","","","P","P","P","","","",""],
            19: ["","","","","P","P","P","","P","P","P","","","","",""],
            20: ["","","","","W","W","W","","W","W","W","W","","","",""],
        ])
    }()

    static let charUpWalk2: [[String]] = {
        replacingRows(charUpIdle, with: [
            12: ["","","","","S","T","T","T","T","T","T","T","T","S","",""],
            13: ["","","S","","T","T","T","T","T","T","T","T","","","",""],
            17: ["","","","","","P","P","","P","P","P","","","","",""],
            18: ["","","","","P","P","","","","P","P","P","","","",""],
            19: ["","","","","P","P","P","","","P","P","P","","","",""],
            20: ["","","","","W","W","W","W","","W","W","W","","","",""],
        ])
    }()

    static let charUpType0: [[String]] = {
        replacingRows(charUpIdle, with: [
            10: ["","","","T","T","T","T","T","T","T","T","T","T","","",""],
            11: ["","","S","S","T","T","T","T","T","T","T","T","S","S","",""],
            12: ["","S","S","","T","T","T","T","T","T","T","T","","S","S",""],
            13: ["","","","","T","T","T","T","T","T","T","T","","","",""],
        ])
    }()

    static let charUpType1: [[String]] = {
        replacingRows(charUpIdle, with: [
            10: ["","","","T","T","T","T","T","T","T","T","T","T","","",""],
            11: ["","S","S","","T","T","T","T","T","T","T","T","","S","S",""],
            12: ["","","S","S","T","T","T","T","T","T","T","T","S","S","",""],
            13: ["","","","","T","T","T","T","T","T","T","T","","","",""],
        ])
    }()

    // ── 오른쪽 (right) idle ──
    static let charRightIdle: [[String]] = [
        ["","","","","","","H","H","H","H","H","","","","",""],
        ["","","","","","H","H","H","H","H","H","H","","","",""],
        ["","","","","H","H","H","H","H","H","H","H","","","",""],
        ["","","","","H","H","H","H","H","H","H","H","","","",""],
        ["","","","","","S","S","S","S","S","S","H","","","",""],
        ["","","","","","S","S","S","S","S","S","","","","",""],
        ["","","","","","S","S","S","E","E","S","","","","",""],
        ["","","","","","S","S","S","S","S","S","","","","",""],
        ["","","","","","S","S","S","S","S","S","","","","",""],
        ["","","","","","T","T","T","T","T","T","","","","",""],
        ["","","","","T","T","T","T","T","T","T","T","","","",""],
        ["","","","","T","T","T","T","T","T","T","T","","","",""],
        ["","","","","T","T","T","T","T","T","T","T","S","","",""],
        ["","","","","T","T","T","T","T","T","T","T","S","","",""],
        ["","","","","T","T","T","T","T","T","T","T","","","",""],
        ["","","","","","T","T","T","T","T","T","","","","",""],
        ["","","","","","P","P","P","P","P","P","","","","",""],
        ["","","","","","P","P","","","P","P","","","","",""],
        ["","","","","","P","P","","","P","P","","","","",""],
        ["","","","","P","P","P","","P","P","P","","","","",""],
        ["","","","","W","W","W","","W","W","W","","","","",""],
        ["","","","","","","","","","","","","","","",""],
        ["","","","","","","","","","","","","","","",""],
        ["","","","","","","","","","","","","","","",""],
    ]

    static let charRightWalk1: [[String]] = {
        replacingRows(charRightIdle, with: [
            12: ["","","","","T","T","T","T","T","T","T","","S","S","",""],
            13: ["","","","","T","T","T","T","T","T","T","T","","S","",""],
            17: ["","","","","","P","P","P","P","P","","","","","",""],
            18: ["","","","","","P","P","","","P","P","P","","","",""],
            19: ["","","","","","","P","P","","","P","P","","","",""],
            20: ["","","","","","W","W","","","W","W","W","","","",""],
        ])
    }()

    static let charRightWalk2: [[String]] = {
        replacingRows(charRightIdle, with: [
            12: ["","","","","T","T","T","T","T","T","T","T","S","","",""],
            13: ["","","","","T","T","T","T","T","T","T","","S","S","",""],
            17: ["","","","","","P","P","P","P","P","P","","","","",""],
            18: ["","","","","","P","P","P","","","P","P","","","",""],
            19: ["","","","","","P","P","P","","","P","P","P","","",""],
            20: ["","","","","W","W","W","","","W","W","","","","",""],
        ])
    }()

    static let charRightType0: [[String]] = {
        replacingRows(charRightIdle, with: [
            10: ["","","","","T","T","T","T","T","T","T","T","","","",""],
            11: ["","","","","T","T","T","T","T","T","T","S","S","S","",""],
            12: ["","","","","T","T","T","T","T","T","S","S","","S","",""],
            13: ["","","","","T","T","T","T","T","T","T","S","S","","",""],
        ])
    }()

    static let charRightType1: [[String]] = {
        replacingRows(charRightIdle, with: [
            10: ["","","","","T","T","T","T","T","T","T","T","","","",""],
            11: ["","","","","T","T","T","T","T","T","S","S","S","","",""],
            12: ["","","","","T","T","T","T","T","T","T","S","S","","",""],
            13: ["","","","","T","T","T","T","T","T","S","S","","S","",""],
        ])
    }()

    // MARK: - Sprite Resolution

    /// 플레이스홀더 문자를 실제 색상으로 치환
    static func resolveCharacter(
        template: SpriteData,
        skin: String = "FFD5B8",
        hair: String = "4A3728",
        shirt: String = "5B9CF6",
        pants: String = "3A4050",
        shoes: String = "2A2E3A",
        eye: String = "333333",
        mouth: String = "CC8888"
    ) -> SpriteData {
        template.map { row in
            row.map { pixel in
                switch pixel {
                case "S": return skin
                case "H": return hair
                case "T": return shirt
                case "P": return pants
                case "W": return shoes
                case "E": return eye
                case "M": return mouth
                default: return pixel
                }
            }
        }
    }

    /// 좌우 반전
    static func flipHorizontal(_ sprite: SpriteData) -> SpriteData {
        sprite.map { $0.reversed() }
    }

    /// 완성된 캐릭터 스프라이트 세트 생성
    static func buildCharacterSprites(skin: String, hair: String, shirt: String, pants: String = "3A4050") -> CharacterSpriteSet {
        let resolve = { (t: SpriteData) in resolveCharacter(template: t, skin: skin, hair: hair, shirt: shirt, pants: pants) }

        let downIdle = resolve(charDownIdle)
        let downW1 = resolve(charDownWalk1)
        let downW2 = resolve(charDownWalk2)
        let downT0 = resolve(charDownType0)
        let downT1 = resolve(charDownType1)

        let upIdle = resolve(charUpIdle)
        let upW1 = resolve(charUpWalk1)
        let upW2 = resolve(charUpWalk2)
        let upT0 = resolve(charUpType0)
        let upT1 = resolve(charUpType1)

        let rightIdle = resolve(charRightIdle)
        let rightW1 = resolve(charRightWalk1)
        let rightW2 = resolve(charRightWalk2)
        let rightT0 = resolve(charRightType0)
        let rightT1 = resolve(charRightType1)

        let leftIdle = flipHorizontal(rightIdle)
        let leftW1 = flipHorizontal(rightW1)
        let leftW2 = flipHorizontal(rightW2)
        let leftT0 = flipHorizontal(rightT0)
        let leftT1 = flipHorizontal(rightT1)

        return CharacterSpriteSet(
            walk: [
                .down: [downIdle, downW1, downIdle, downW2],
                .up: [upIdle, upW1, upIdle, upW2],
                .right: [rightIdle, rightW1, rightIdle, rightW2],
                .left: [leftIdle, leftW1, leftIdle, leftW2],
            ],
            typing: [
                .down: [downT0, downT1],
                .up: [upT0, upT1],
                .right: [rightT0, rightT1],
                .left: [leftT0, leftT1],
            ],
            idle: [
                .down: downIdle,
                .up: upIdle,
                .right: rightIdle,
                .left: leftIdle,
            ]
        )
    }

    // MARK: - Furniture Sprites

    /// 책상 (3x1 타일 = 48x16)
    static let desk: SpriteData = {
        let w = 48, h = 16
        var rows = Array(repeating: Array(repeating: "", count: w), count: h)
        // 상판
        for y in 0..<4 { for x in 0..<w { rows[y][x] = "8B7355" } }
        // 상판 하이라이트
        for x in 0..<w { rows[0][x] = "A08B68" }
        // 앞면
        for y in 4..<14 { for x in 0..<w { rows[y][x] = "7A6548" } }
        // 다리
        for y in 14..<16 {
            for x in [2,3,44,45] { rows[y][x] = "6A5538" }
        }
        // 그림자
        for x in 0..<w { rows[15][x] = rows[15][x].isEmpty ? "" : "5A4528" }
        return rows
    }()

    /// 모니터 (1x1 타일 = 16x16)
    static let monitor: SpriteData = {
        var rows = Array(repeating: Array(repeating: "", count: 16), count: 16)
        // 화면 프레임
        for y in 1..<11 { for x in 2..<14 { rows[y][x] = "2A2E3A" } }
        // 화면 내부
        for y in 2..<10 { for x in 3..<13 { rows[y][x] = "1A2030" } }
        // 화면 빛
        for y in 3..<8 { for x in 4..<12 { rows[y][x] = "203050" } }
        // 코드 라인
        for x in 4..<9 { rows[4][x] = "4080D0" }
        for x in 5..<11 { rows[6][x] = "40A060" }
        // 받침대
        for x in 6..<10 { rows[11][x] = "3A3E4A"; rows[12][x] = "3A3E4A" }
        for x in 4..<12 { rows[13][x] = "4A4E5A" }
        return rows
    }()

    /// 의자 (1x1 = 16x16)
    static let chair: SpriteData = {
        var rows = Array(repeating: Array(repeating: "", count: 16), count: 16)
        // 등받이
        for y in 2..<6 { for x in 3..<13 { rows[y][x] = "4A4A5A" } }
        // 쿠션
        for y in 6..<11 { for x in 3..<13 { rows[y][x] = "5A5A6A" } }
        // 다리
        for y in 11..<14 { rows[y][4] = "3A3A4A"; rows[y][11] = "3A3A4A" }
        // 바퀴
        for x in [3,4,5,10,11,12] { rows[14][x] = "2A2A3A" }
        return rows
    }()

    /// 화분 (1x1 = 16x16)
    static let plant: SpriteData = {
        var rows = Array(repeating: Array(repeating: "", count: 16), count: 16)
        // 잎 (위쪽)
        for y in 0..<4 { for x in 3..<13 { rows[y][x] = "408040" } }
        for y in 1..<3 { for x in 5..<11 { rows[y][x] = "50A050" } }
        rows[0][7] = "60B860"; rows[0][8] = "60B860"
        // 줄기
        for y in 4..<8 { rows[y][7] = "306030"; rows[y][8] = "306030" }
        // 화분
        for y in 8..<14 { for x in 4..<12 { rows[y][x] = "B08060" } }
        for x in 3..<13 { rows[8][x] = "C09070" } // 림
        for y in 14..<16 { for x in 5..<11 { rows[y][x] = "A07050" } }
        return rows
    }()

    /// 커피머신 (1x1 = 16x16)
    static let coffeeMachine: SpriteData = {
        var rows = Array(repeating: Array(repeating: "", count: 16), count: 16)
        for y in 1..<13 { for x in 3..<13 { rows[y][x] = "606878" } }
        // 상단
        for x in 2..<14 { rows[0][x] = "707880"; rows[1][x] = "707880" }
        // 디스플레이
        for y in 3..<7 { for x in 5..<11 { rows[y][x] = "A0B0C0" } }
        // 드립 영역
        for y in 8..<12 { for x in 5..<11 { rows[y][x] = "404850" } }
        // 컵
        for y in 9..<12 { for x in 6..<10 { rows[y][x] = "F0ECE0" } }
        rows[10][10] = "F0ECE0"; rows[11][10] = "F0ECE0" // 손잡이
        // LED
        rows[3][6] = "40C040"
        return rows
    }()

    /// 소파 (3x2 = 48x32)
    static let sofa: SpriteData = {
        let w = 48, h = 32
        var rows = Array(repeating: Array(repeating: "", count: w), count: h)
        let sofaColor = "6A5080"
        let cushion = "7A6090"
        let arm = "5A4070"
        // 등받이
        for y in 2..<10 { for x in 2..<46 { rows[y][x] = sofaColor } }
        // 좌석
        for y in 10..<22 { for x in 4..<44 { rows[y][x] = cushion } }
        // 팔걸이
        for y in 4..<22 { for x in 0..<5 { rows[y][x] = arm }; for x in 43..<48 { rows[y][x] = arm } }
        // 쿠션 디테일
        for y in 12..<20 { for x in 8..<20 { rows[y][x] = "8A70A0" } }
        for y in 12..<20 { for x in 28..<40 { rows[y][x] = "8A70A0" } }
        // 다리
        for y in 22..<28 { rows[y][6] = "4A3060"; rows[y][41] = "4A3060" }
        return rows
    }()

    /// 화이트보드 (3x1 = 48x16)
    static let whiteboard: SpriteData = {
        let w = 48, h = 16
        var rows = Array(repeating: Array(repeating: "", count: w), count: h)
        // 프레임
        for y in 0..<h { for x in 0..<w { rows[y][x] = "A0A0B0" } }
        // 보드 면
        for y in 1..<(h-1) { for x in 1..<(w-1) { rows[y][x] = "F0F0F4" } }
        // 글씨
        for x in 4..<18 { rows[3][x] = "4060B0" }
        for x in 4..<28 { rows[6][x] = "4060B0" }
        for x in 4..<14 { rows[9][x] = "C04040" }
        for x in 18..<32 { rows[9][x] = "40A060" }
        return rows
    }()

    /// 책장 (2x1 = 32x16)
    static let bookshelf: SpriteData = {
        let w = 32, h = 16
        var rows = Array(repeating: Array(repeating: "", count: w), count: h)
        // 프레임
        for y in 0..<h { for x in 0..<w { rows[y][x] = "6A5030" } }
        // 선반
        for x in 0..<w { rows[0][x] = "7A6040"; rows[7][x] = "7A6040"; rows[15][x] = "7A6040" }
        // 책 (상단)
        let colors1 = ["C04040","4060C0","40A040","C0A040","8040C0","C06040"]
        for (i, c) in colors1.enumerated() {
            let bx = 2 + i * 4
            for y in 1..<7 { for x in bx..<min(bx+3, w-1) { rows[y][x] = c } }
        }
        // 책 (하단)
        let colors2 = ["40A0C0","C040A0","A0C040","6060C0","C08040"]
        for (i, c) in colors2.enumerated() {
            let bx = 3 + i * 5
            for y in 8..<14 { for x in bx..<min(bx+4, w-1) { rows[y][x] = c } }
        }
        return rows
    }()
}
