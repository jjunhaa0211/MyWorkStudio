import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Level System
// ═══════════════════════════════════════════════════════

struct WorkerLevel {
    let level: Int
    let title: String
    let xpRequired: Int
    let badge: String

    private struct Tier {
        let title: String
        let badge: String
        let xpStep: Int
    }

    private static let legacyLevels: [WorkerLevel] = [
        WorkerLevel(level: 1, title: "인턴", xpRequired: 0, badge: "🌱"),
        WorkerLevel(level: 2, title: "주니어", xpRequired: 100, badge: "🔰"),
        WorkerLevel(level: 3, title: "미들", xpRequired: 300, badge: "⚙️"),
        WorkerLevel(level: 4, title: "시니어", xpRequired: 600, badge: "🔧"),
        WorkerLevel(level: 5, title: "리드", xpRequired: 1000, badge: "⭐"),
        WorkerLevel(level: 6, title: "아키텍트", xpRequired: 1500, badge: "🏗"),
        WorkerLevel(level: 7, title: "CTO", xpRequired: 2500, badge: "🎯"),
        WorkerLevel(level: 8, title: "전설", xpRequired: 4000, badge: "🏆"),
        WorkerLevel(level: 9, title: "신", xpRequired: 6000, badge: "👑"),
        WorkerLevel(level: 10, title: "우주", xpRequired: 10000, badge: "🌌"),
    ]

    private static let advancedTiers: [Tier] = [
        Tier(title: "성운", badge: "🌠", xpStep: 100),
        Tier(title: "은하", badge: "🌌", xpStep: 120),
        Tier(title: "초신성", badge: "☄️", xpStep: 140),
        Tier(title: "차원", badge: "🌀", xpStep: 160),
        Tier(title: "특이점", badge: "♾️", xpStep: 180),
        Tier(title: "초월", badge: "🔱", xpStep: 200),
        Tier(title: "불멸", badge: "💎", xpStep: 220),
        Tier(title: "신화", badge: "🔥", xpStep: 240),
        Tier(title: "창세", badge: "☀️", xpStep: 260),
    ]

    static let levels: [WorkerLevel] = makeLevels()

    private static func makeLevels() -> [WorkerLevel] {
        var generated = legacyLevels
        var requiredXP = legacyLevels.last?.xpRequired ?? 0

        for level in 11...100 {
            let tierIndex = min((level - 11) / 10, advancedTiers.count - 1)
            let tier = advancedTiers[tierIndex]
            requiredXP += tier.xpStep

            generated.append(
                WorkerLevel(
                    level: level,
                    title: level == 100 ? "절대자" : tier.title,
                    xpRequired: requiredXP,
                    badge: level == 100 ? "🪐" : tier.badge
                )
            )
        }

        return generated
    }

    static func forXP(_ xp: Int) -> WorkerLevel { levels.last(where: { $0.xpRequired <= xp }) ?? levels[0] }

    static func progress(_ xp: Int) -> Double {
        let cur = forXP(xp)
        guard let curIdx = levels.firstIndex(where: { $0.level == cur.level }) else { return 1.0 }
        let nextIdx = curIdx + 1
        guard nextIdx < levels.count else { return 1.0 }
        let next = levels[nextIdx]
        if next.xpRequired <= cur.xpRequired { return 1.0 }
        return Double(xp - cur.xpRequired) / Double(next.xpRequired - cur.xpRequired)
    }

    static func nextLevel(_ xp: Int) -> WorkerLevel? {
        let cur = forXP(xp)
        guard let curIdx = levels.firstIndex(where: { $0.level == cur.level }) else { return nil }
        let nextIdx = curIdx + 1
        return nextIdx < levels.count ? levels[nextIdx] : nil
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement
// ═══════════════════════════════════════════════════════

enum AchievementRarity: String, Codable {
    case common = "일반"
    case rare = "희귀"
    case epic = "영웅"
    case legendary = "전설"

    var color: Color {
        switch self {
        case .common: return Theme.textSecondary
        case .rare: return Theme.accent
        case .epic: return Theme.purple
        case .legendary: return Theme.yellow
        }
    }

    var bgGlow: Color {
        switch self {
        case .common: return .clear
        case .rare: return Theme.accent.opacity(0.1)
        case .epic: return Theme.purple.opacity(0.15)
        case .legendary: return Theme.yellow.opacity(0.2)
        }
    }
}

struct Achievement: Identifiable, Codable {
    let id: String
    let icon: String
    let name: String
    let description: String
    let xpReward: Int
    let rarity: AchievementRarity
    var unlocked: Bool = false
    var unlockedAt: Date?
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Manager
// ═══════════════════════════════════════════════════════

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    @Published var achievements: [Achievement] = [
        // ─────────────────────────────────────────────
        // Common (일반) — 쉽게 달성 가능
        // ─────────────────────────────────────────────
        Achievement(id: "first_session", icon: "🎬", name: "첫 걸음", description: "첫 번째 세션을 시작했다", xpReward: 30, rarity: .common),
        Achievement(id: "first_complete", icon: "✅", name: "완료!", description: "첫 번째 작업을 완료했다", xpReward: 30, rarity: .common),
        Achievement(id: "first_bash", icon: "💻", name: "첫 명령어", description: "첫 Bash 명령을 실행했다", xpReward: 20, rarity: .common),
        Achievement(id: "first_edit", icon: "✏️", name: "첫 수정", description: "첫 번째 파일을 수정했다", xpReward: 20, rarity: .common),
        Achievement(id: "command_10", icon: "🔟", name: "열 번의 손짓", description: "명령을 10번 실행했다", xpReward: 25, rarity: .common),
        Achievement(id: "complete_5", icon: "🖐", name: "다섯 번째 성공", description: "작업을 5번 완료했다", xpReward: 30, rarity: .common),
        Achievement(id: "complete_10", icon: "🔄", name: "열 번째 성공", description: "작업을 10번 완료했다", xpReward: 35, rarity: .common),
        Achievement(id: "session_10", icon: "📋", name: "열 번째 출근", description: "세션을 10번 시작했다", xpReward: 30, rarity: .common),
        Achievement(id: "token_first_1k", icon: "🪙", name: "첫 천 토큰", description: "누적 1,000 토큰을 사용했다", xpReward: 25, rarity: .common),
        Achievement(id: "weekend_warrior", icon: "🎮", name: "주말 전사", description: "주말에 작업했다", xpReward: 30, rarity: .common),
        Achievement(id: "read_10", icon: "📖", name: "독서가", description: "한 세션에서 파일을 10번 읽었다", xpReward: 25, rarity: .common),
        Achievement(id: "cost_first", icon: "💵", name: "첫 지출", description: "API 비용이 발생했다", xpReward: 20, rarity: .common),
        Achievement(id: "five_sessions", icon: "🖐🏻", name: "다섯 손가락", description: "5개 세션을 동시에 실행했다", xpReward: 40, rarity: .common),
        Achievement(id: "file_edit_5", icon: "📝", name: "다섯 줄 수정", description: "파일을 5번 수정했다", xpReward: 25, rarity: .common),
        Achievement(id: "monday_blues", icon: "😩", name: "월요병", description: "월요일에 작업했다", xpReward: 25, rarity: .common),
        Achievement(id: "friday_coder", icon: "🎉", name: "불금 코더", description: "금요일에 작업했다", xpReward: 25, rarity: .common),

        // ─────────────────────────────────────────────
        // Rare (희귀) — 중간 난이도
        // ─────────────────────────────────────────────
        Achievement(id: "night_owl", icon: "🦉", name: "야행성", description: "자정~새벽 5시 사이에 작업했다", xpReward: 50, rarity: .rare),
        Achievement(id: "early_bird", icon: "🐦", name: "얼리버드", description: "새벽 4~6시 사이에 작업했다", xpReward: 50, rarity: .rare),
        Achievement(id: "speed_demon", icon: "⚡", name: "스피드 데몬", description: "5분 안에 작업을 완료했다", xpReward: 50, rarity: .rare),
        Achievement(id: "multi_tasker", icon: "🤹", name: "멀티태스커", description: "3개 이상 동시에 작업했다", xpReward: 50, rarity: .rare),
        Achievement(id: "pair_programmer", icon: "👯", name: "페어 프로그래머", description: "같은 프로젝트에 2명을 배정했다", xpReward: 50, rarity: .rare),
        Achievement(id: "bug_squasher", icon: "🪲", name: "벌레 사냥꾼", description: "에러 상태에서 복구했다", xpReward: 50, rarity: .rare),
        Achievement(id: "token_saver", icon: "💰", name: "절약왕", description: "1k 토큰 이하로 작업을 완료했다", xpReward: 50, rarity: .rare),
        Achievement(id: "command_50", icon: "5️⃣", name: "반백", description: "명령을 50번 실행했다", xpReward: 45, rarity: .rare),
        Achievement(id: "complete_25", icon: "🎖", name: "숙련공", description: "작업을 25번 완료했다", xpReward: 50, rarity: .rare),
        Achievement(id: "session_25", icon: "📊", name: "출근왕", description: "세션을 25번 시작했다", xpReward: 45, rarity: .rare),
        Achievement(id: "lunch_coder", icon: "🍱", name: "점심시간 코더", description: "점심시간(12~13시)에 작업했다", xpReward: 40, rarity: .rare),
        Achievement(id: "file_surgeon", icon: "🔪", name: "외과의사", description: "한 세션에서 5개 이상 파일을 수정했다", xpReward: 50, rarity: .rare),
        Achievement(id: "cost_1", icon: "💲", name: "첫 달러", description: "누적 비용 $1을 넘었다", xpReward: 50, rarity: .rare),
        Achievement(id: "focus_30", icon: "🧘", name: "집중력", description: "30분 이상 연속 작업했다", xpReward: 45, rarity: .rare),
        Achievement(id: "error_5", icon: "💪", name: "불굴의 의지", description: "에러에서 5번 복구했다", xpReward: 55, rarity: .rare),
        Achievement(id: "opus_user", icon: "🟣", name: "오퍼스 유저", description: "Opus 모델을 사용했다", xpReward: 40, rarity: .rare),
        Achievement(id: "haiku_user", icon: "🟢", name: "하이쿠 유저", description: "Haiku 모델을 사용했다", xpReward: 40, rarity: .rare),
        Achievement(id: "token_10k_total", icon: "📈", name: "만 토큰 클럽", description: "누적 10,000 토큰을 사용했다", xpReward: 50, rarity: .rare),
        Achievement(id: "git_first_branch", icon: "🌱", name: "가지치기", description: "Git 브랜치에서 작업했다", xpReward: 35, rarity: .rare),
        Achievement(id: "session_streak_3", icon: "🔥", name: "3일 연속", description: "3일 연속으로 작업했다", xpReward: 55, rarity: .rare),
        Achievement(id: "night_complete", icon: "🌙", name: "달빛 코더", description: "밤 10시 이후에 작업을 완료했다", xpReward: 40, rarity: .rare),
        Achievement(id: "morning_complete", icon: "🌅", name: "아침형 인간", description: "오전 9시 전에 작업을 완료했다", xpReward: 40, rarity: .rare),
        Achievement(id: "file_edit_25", icon: "🗂", name: "정리의 달인", description: "파일을 25번 수정했다", xpReward: 45, rarity: .rare),
        Achievement(id: "file_edit_50", icon: "📚", name: "리팩토링 장인", description: "파일을 50번 수정했다", xpReward: 55, rarity: .rare),
        Achievement(id: "cost_5", icon: "💳", name: "구독자", description: "누적 비용 $5를 넘었다", xpReward: 45, rarity: .rare),
        Achievement(id: "read_50", icon: "🔍", name: "탐정", description: "파일을 50번 읽었다", xpReward: 45, rarity: .rare),
        Achievement(id: "dawn_warrior", icon: "🌄", name: "새벽 전사", description: "새벽 3시에 작업 중이었다", xpReward: 55, rarity: .rare),
        Achievement(id: "token_5k_session", icon: "📊", name: "알찬 세션", description: "한 세션에서 5k 이상 토큰을 사용했다", xpReward: 45, rarity: .rare),

        // ─────────────────────────────────────────────
        // Epic (영웅) — 높은 난이도
        // ─────────────────────────────────────────────
        Achievement(id: "marathon", icon: "🏃", name: "마라톤", description: "1시간 이상 연속으로 작업했다", xpReward: 80, rarity: .epic),
        Achievement(id: "git_master", icon: "🌿", name: "Git 마스터", description: "한 세션에서 10개 이상 파일을 변경했다", xpReward: 80, rarity: .epic),
        Achievement(id: "centurion", icon: "💯", name: "백전노장", description: "명령을 100번 실행했다", xpReward: 80, rarity: .epic),
        Achievement(id: "token_whale", icon: "🐋", name: "토큰 고래", description: "한 세션에서 10k 이상 토큰을 사용했다", xpReward: 80, rarity: .epic),
        Achievement(id: "complete_50", icon: "🏅", name: "베테랑", description: "작업을 50번 완료했다", xpReward: 80, rarity: .epic),
        Achievement(id: "complete_100", icon: "🎯", name: "백전백승", description: "작업을 100번 완료했다", xpReward: 100, rarity: .epic),
        Achievement(id: "command_500", icon: "⚔️", name: "오백장군", description: "명령을 500번 실행했다", xpReward: 90, rarity: .epic),
        Achievement(id: "session_50", icon: "🏢", name: "근속상", description: "세션을 50번 시작했다", xpReward: 80, rarity: .epic),
        Achievement(id: "ultra_marathon", icon: "🏔", name: "울트라 마라톤", description: "3시간 이상 연속으로 작업했다", xpReward: 100, rarity: .epic),
        Achievement(id: "cost_10", icon: "💎", name: "큰손", description: "누적 비용 $10을 넘었다", xpReward: 90, rarity: .epic),
        Achievement(id: "token_100k_total", icon: "🏦", name: "토큰 부자", description: "누적 100,000 토큰을 사용했다", xpReward: 90, rarity: .epic),
        Achievement(id: "git_master_25", icon: "🌳", name: "Git 장인", description: "한 세션에서 25개 이상 파일을 변경했다", xpReward: 90, rarity: .epic),
        Achievement(id: "multi_5", icon: "🎪", name: "오케스트라 지휘자", description: "5개 이상 동시에 작업했다", xpReward: 85, rarity: .epic),
        Achievement(id: "error_10", icon: "🔥", name: "불사조", description: "에러에서 10번 복구했다", xpReward: 85, rarity: .epic),
        Achievement(id: "speed_2min", icon: "🚀", name: "번개", description: "2분 안에 작업을 완료했다", xpReward: 85, rarity: .epic),
        Achievement(id: "night_marathon", icon: "🌃", name: "야간 마라톤", description: "자정~5시에 1시간 이상 작업했다", xpReward: 95, rarity: .epic),
        Achievement(id: "three_models", icon: "🎨", name: "삼총사", description: "세 가지 모델을 모두 사용했다", xpReward: 80, rarity: .epic),
        Achievement(id: "session_streak_7", icon: "📆", name: "7일 연속", description: "7일 연속으로 작업했다", xpReward: 100, rarity: .epic),
        Achievement(id: "token_50k_session", icon: "🐳", name: "메가 세션", description: "한 세션에서 50k 이상 토큰을 사용했다", xpReward: 90, rarity: .epic),
        Achievement(id: "git_branch_5", icon: "🌲", name: "브랜치 달인", description: "5개 이상 다른 브랜치에서 작업했다", xpReward: 80, rarity: .epic),
        Achievement(id: "file_surgeon_10", icon: "⚕️", name: "집도의", description: "한 세션에서 10개 이상 파일을 수정했다", xpReward: 85, rarity: .epic),
        Achievement(id: "complete_200", icon: "🎗", name: "프로", description: "작업을 200번 완료했다", xpReward: 90, rarity: .epic),
        Achievement(id: "file_edit_100", icon: "🏗", name: "건축가", description: "파일을 100번 수정했다", xpReward: 85, rarity: .epic),
        Achievement(id: "read_200", icon: "📚", name: "학자", description: "파일을 200번 읽었다", xpReward: 80, rarity: .epic),
        Achievement(id: "error_25", icon: "🛡", name: "방패", description: "에러에서 25번 복구했다", xpReward: 95, rarity: .epic),
        Achievement(id: "cost_50", icon: "💰", name: "투자자", description: "누적 비용 $50을 넘었다", xpReward: 95, rarity: .epic),
        Achievement(id: "session_streak_14", icon: "🗓", name: "2주 연속", description: "14일 연속으로 작업했다", xpReward: 100, rarity: .epic),
        Achievement(id: "git_branch_10", icon: "🌴", name: "숲의 관리자", description: "10개 이상 다른 브랜치에서 작업했다", xpReward: 90, rarity: .epic),
        Achievement(id: "token_500k_total", icon: "🏧", name: "토큰 재벌", description: "누적 500,000 토큰을 사용했다", xpReward: 95, rarity: .epic),
        Achievement(id: "speed_1min", icon: "💨", name: "섬광", description: "1분 안에 작업을 완료했다", xpReward: 100, rarity: .epic),
        Achievement(id: "marathon_6h", icon: "🏕", name: "캠프파이어", description: "6시간 이상 연속으로 작업했다", xpReward: 110, rarity: .epic),
        Achievement(id: "token_100k_session", icon: "🦈", name: "메갈로돈", description: "한 세션에서 100k 이상 토큰을 사용했다", xpReward: 100, rarity: .epic),
        Achievement(id: "git_master_50", icon: "🏔", name: "산을 옮기다", description: "한 세션에서 50개 이상 파일을 변경했다", xpReward: 100, rarity: .epic),
        Achievement(id: "session_75", icon: "🎓", name: "졸업", description: "세션을 75번 시작했다", xpReward: 90, rarity: .epic),
        Achievement(id: "read_500", icon: "🧠", name: "브레인", description: "파일을 500번 읽었다", xpReward: 90, rarity: .epic),
        Achievement(id: "file_edit_200", icon: "⚒", name: "대장장이", description: "파일을 200번 수정했다", xpReward: 90, rarity: .epic),
        Achievement(id: "complete_300", icon: "🗻", name: "등산가", description: "작업을 300번 완료했다", xpReward: 95, rarity: .epic),
        Achievement(id: "night_owl_10", icon: "🦇", name: "박쥐", description: "심야 작업을 10일 이상 했다", xpReward: 95, rarity: .epic),

        // ─────────────────────────────────────────────
        // Legendary (전설) — 매우 높은 난이도
        // ─────────────────────────────────────────────
        Achievement(id: "level_5", icon: "⭐", name: "스타 개발자", description: "레벨 5에 도달했다", xpReward: 150, rarity: .legendary),
        Achievement(id: "level_8", icon: "🏆", name: "전설의 시작", description: "레벨 8에 도달했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "level_10", icon: "🌌", name: "우주의 끝", description: "레벨 10에 도달했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "complete_500", icon: "👑", name: "천하무적", description: "작업을 500번 완료했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "command_1000", icon: "🗡", name: "천 번의 손짓", description: "명령을 1,000번 실행했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "command_5000", icon: "⚜️", name: "만능 해커", description: "명령을 5,000번 실행했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "session_100", icon: "🏛", name: "출퇴근 달인", description: "세션을 100번 시작했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "token_million", icon: "💫", name: "백만장자", description: "누적 1,000,000 토큰을 사용했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "cost_100", icon: "🤑", name: "큰 후원자", description: "누적 비용 $100을 넘었다", xpReward: 200, rarity: .legendary),
        Achievement(id: "session_streak_30", icon: "🔱", name: "30일 연속", description: "30일 연속으로 작업했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "perfectionist", icon: "🎆", name: "완벽주의자", description: "전설 등급 외 모든 업적을 달성했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "complete_1000", icon: "🐉", name: "용", description: "작업을 1,000번 완료했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "command_10000", icon: "🌠", name: "별을 헤아리며", description: "명령을 10,000번 실행했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "file_edit_500", icon: "🗿", name: "불멸의 조각가", description: "파일을 500번 수정했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "error_50", icon: "🔮", name: "예언자", description: "에러에서 50번 복구했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "session_streak_100", icon: "💎", name: "다이아몬드", description: "100일 연속으로 작업했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "session_500", icon: "🏰", name: "성을 쌓다", description: "세션을 500번 시작했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "cost_500", icon: "🏦", name: "은행장", description: "누적 비용 $500을 넘었다", xpReward: 350, rarity: .legendary),
        Achievement(id: "token_5million", icon: "🪐", name: "행성", description: "누적 5,000,000 토큰을 사용했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "complete_2000", icon: "☀️", name: "태양", description: "작업을 2,000번 완료했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "session_streak_365", icon: "♾️", name: "무한", description: "365일 연속으로 작업했다", xpReward: 1000, rarity: .legendary),
        Achievement(id: "command_50000", icon: "🔨", name: "광부", description: "명령을 50,000번 실행했다", xpReward: 500, rarity: .legendary),
    ]

    @Published var totalXP: Int = 0
    @Published var commandCount: Int = 0
    @Published var recentUnlock: Achievement?

    // 확장 추적 변수
    @Published var totalSessions: Int = 0
    @Published var totalCompletions: Int = 0
    @Published var totalTokensUsed: Int = 0
    @Published var totalCost: Double = 0
    @Published var errorRecoveryCount: Int = 0
    @Published var totalFileEdits: Int = 0
    @Published var totalFileReads: Int = 0
    @Published var usedModels: Set<String> = []
    @Published var uniqueBranches: Set<String> = []
    @Published var activeDays: Set<String> = []  // "yyyy-MM-dd" 형식
    @Published var nightDays: Set<String> = []   // 심야 작업한 날

    private let saveKey = "WorkManAchievements"
    private var saveDebounceWork: DispatchWorkItem?
    private var toastQueue: [Achievement] = []
    private var toastDismissWork: DispatchWorkItem?
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    @Published var unlockedCount: Int = 0
    var currentLevel: WorkerLevel { WorkerLevel.forXP(totalXP) }

    init() { loadState() }

    func unlock(_ id: String) {
        guard let idx = achievements.firstIndex(where: { $0.id == id && !$0.unlocked }) else { return }
        achievements[idx].unlocked = true
        achievements[idx].unlockedAt = Date()
        unlockedCount += 1
        let unlockedAchievement = achievements[idx]
        enqueueRecentUnlock(unlockedAchievement)
        addXP(unlockedAchievement.xpReward)
        NSSound(named: "Hero")?.play()
        saveState()

        // 완벽주의자 체크: 전설 등급 외 모든 업적 달성 시
        let nonLegendary = achievements.filter { $0.rarity != .legendary }
        if nonLegendary.allSatisfy({ $0.unlocked }) { unlock("perfectionist") }
    }

    func dismissRecentUnlock() {
        toastDismissWork?.cancel()
        toastDismissWork = nil
        recentUnlock = nil
        showNextRecentUnlockIfNeeded()
    }

    func addXP(_ amount: Int) {
        totalXP += amount
        if totalXP >= 1000 { unlock("level_5") }
        if totalXP >= 4000 { unlock("level_8") }
        if totalXP >= 10000 { unlock("level_10") }
        saveState()
    }

    func incrementCommand() {
        commandCount += 1
        if commandCount >= 10 { unlock("command_10") }
        if commandCount >= 50 { unlock("command_50") }
        if commandCount >= 100 { unlock("centurion") }
        if commandCount >= 500 { unlock("command_500") }
        if commandCount >= 1000 { unlock("command_1000") }
        if commandCount >= 5000 { unlock("command_5000") }
        if commandCount >= 10000 { unlock("command_10000") }
        if commandCount >= 50000 { unlock("command_50000") }
        if commandCount == 1 { unlock("first_bash") }
        saveState()
    }

    func recordFileEdit() {
        totalFileEdits += 1
        if totalFileEdits == 1 { unlock("first_edit") }
        if totalFileEdits >= 5 { unlock("file_edit_5") }
        if totalFileEdits >= 25 { unlock("file_edit_25") }
        if totalFileEdits >= 50 { unlock("file_edit_50") }
        if totalFileEdits >= 100 { unlock("file_edit_100") }
        if totalFileEdits >= 200 { unlock("file_edit_200") }
        if totalFileEdits >= 500 { unlock("file_edit_500") }
        saveState()
    }

    func recordFileRead(sessionReadCount: Int) {
        totalFileReads += 1
        if sessionReadCount >= 10 { unlock("read_10") }
        if totalFileReads >= 50 { unlock("read_50") }
        if totalFileReads >= 200 { unlock("read_200") }
        if totalFileReads >= 500 { unlock("read_500") }
        saveState()
    }

    func recordModel(_ model: String) {
        usedModels.insert(model.lowercased())
        if usedModels.contains("opus") { unlock("opus_user") }
        if usedModels.contains("haiku") { unlock("haiku_user") }
        if usedModels.contains("opus") && usedModels.contains("sonnet") && usedModels.contains("haiku") {
            unlock("three_models")
        }
        saveState()
    }

    func recordBranch(_ branch: String) {
        guard !branch.isEmpty else { return }
        uniqueBranches.insert(branch)
        unlock("git_first_branch")
        if uniqueBranches.count >= 5 { unlock("git_branch_5") }
        if uniqueBranches.count >= 10 { unlock("git_branch_10") }
        saveState()
    }

    func recordCost(_ cost: Double) {
        totalCost += cost
        if totalCost > 0 { unlock("cost_first") }
        if totalCost >= 1.0 { unlock("cost_1") }
        if totalCost >= 5.0 { unlock("cost_5") }
        if totalCost >= 10.0 { unlock("cost_10") }
        if totalCost >= 50.0 { unlock("cost_50") }
        if totalCost >= 100.0 { unlock("cost_100") }
        if totalCost >= 500.0 { unlock("cost_500") }
        saveState()
    }

    private func recordActiveDay() {
        let today = dayFormatter.string(from: Date())
        activeDays.insert(today)
        checkStreakAchievements()
        saveState()
    }

    private func checkStreakAchievements() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var streak = 1
        var day = today
        while true {
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            let prevStr = dayFormatter.string(from: prev)
            if activeDays.contains(prevStr) { streak += 1; day = prev }
            else { break }
        }
        if streak >= 3 { unlock("session_streak_3") }
        if streak >= 7 { unlock("session_streak_7") }
        if streak >= 14 { unlock("session_streak_14") }
        if streak >= 30 { unlock("session_streak_30") }
        if streak >= 100 { unlock("session_streak_100") }
        if streak >= 365 { unlock("session_streak_365") }
    }

    func checkSessionAchievements(tabs: [TerminalTab]) {
        if tabs.count >= 1 { unlock("first_session") }
        if tabs.count >= 5 { unlock("five_sessions") }

        let runningCount = tabs.filter({ $0.isRunning && !$0.isCompleted }).count
        if runningCount >= 3 { unlock("multi_tasker") }
        if runningCount >= 5 { unlock("multi_5") }

        if tabs.contains(where: { $0.sessionCount >= 2 }) { unlock("pair_programmer") }

        for tab in tabs {
            if tab.gitInfo.changedFiles >= 10 { unlock("git_master") }
            if tab.gitInfo.changedFiles >= 25 { unlock("git_master_25") }
            if tab.gitInfo.changedFiles >= 50 { unlock("git_master_50") }
            if tab.fileChanges.count >= 5 { unlock("file_surgeon") }
            if tab.fileChanges.count >= 10 { unlock("file_surgeon_10") }
        }

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let weekday = Calendar.current.component(.weekday, from: now)

        if hour >= 0 && hour < 5 {
            unlock("night_owl")
            let today = dayFormatter.string(from: now)
            if !nightDays.contains(today) {
                nightDays.insert(today)
                if nightDays.count >= 10 { unlock("night_owl_10") }
                saveState()
            }
        }
        if hour >= 4 && hour < 6 { unlock("early_bird") }
        if hour >= 12 && hour < 13 { unlock("lunch_coder") }
        if weekday == 1 || weekday == 7 { unlock("weekend_warrior") }
        if weekday == 2 { unlock("monday_blues") }
        if weekday == 6 { unlock("friday_coder") }
        if hour == 3 { unlock("dawn_warrior") }

        // 야간 마라톤: 자정~5시에 1시간 이상 작업 중인 세션
        if hour >= 0 && hour < 5 {
            for tab in tabs where !tab.isCompleted {
                let dur = now.timeIntervalSince(tab.startTime)
                if dur > 3600 { unlock("night_marathon") }
            }
        }

        // 활동일 기록
        recordActiveDay()
    }

    func checkCompletionAchievements(tab: TerminalTab) {
        totalCompletions += 1
        totalSessions += 1
        totalTokensUsed += tab.tokensUsed

        unlock("first_complete")
        if totalCompletions >= 5 { unlock("complete_5") }
        if totalCompletions >= 10 { unlock("complete_10") }
        if totalCompletions >= 25 { unlock("complete_25") }
        if totalCompletions >= 50 { unlock("complete_50") }
        if totalCompletions >= 100 { unlock("complete_100") }
        if totalCompletions >= 200 { unlock("complete_200") }
        if totalCompletions >= 300 { unlock("complete_300") }
        if totalCompletions >= 500 { unlock("complete_500") }
        if totalCompletions >= 1000 { unlock("complete_1000") }
        if totalCompletions >= 2000 { unlock("complete_2000") }

        if totalSessions >= 10 { unlock("session_10") }
        if totalSessions >= 25 { unlock("session_25") }
        if totalSessions >= 50 { unlock("session_50") }
        if totalSessions >= 75 { unlock("session_75") }
        if totalSessions >= 100 { unlock("session_100") }
        if totalSessions >= 500 { unlock("session_500") }

        let dur = Date().timeIntervalSince(tab.startTime)
        if dur < 60 { unlock("speed_1min") }
        if dur < 120 { unlock("speed_2min") }
        if dur < 300 { unlock("speed_demon") }
        if dur > 1800 { unlock("focus_30") }
        if dur > 3600 { unlock("marathon") }
        if dur > 10800 { unlock("ultra_marathon") }
        if dur > 21600 { unlock("marathon_6h") }

        if tab.tokensUsed < 1000 && tab.tokensUsed > 0 { unlock("token_saver") }
        if tab.tokensUsed >= 5000 { unlock("token_5k_session") }
        if tab.tokensUsed >= 10000 { unlock("token_whale") }
        if tab.tokensUsed >= 50000 { unlock("token_50k_session") }
        if tab.tokensUsed >= 100000 { unlock("token_100k_session") }

        // 누적 토큰 체크
        if totalTokensUsed >= 1000 { unlock("token_first_1k") }
        if totalTokensUsed >= 10000 { unlock("token_10k_total") }
        if totalTokensUsed >= 100000 { unlock("token_100k_total") }
        if totalTokensUsed >= 500000 { unlock("token_500k_total") }
        if totalTokensUsed >= 1000000 { unlock("token_million") }
        if totalTokensUsed >= 5000000 { unlock("token_5million") }

        // 비용 기록
        recordCost(tab.totalCost)

        // 모델 기록
        recordModel(tab.selectedModel.rawValue)

        // 브랜치 기록
        if let branch = tab.branch { recordBranch(branch) }

        // 시간대 체크
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 5 { unlock("night_complete") }
        if hour >= 5 && hour < 9 { unlock("morning_complete") }

        addXP(30)
        saveState()
    }

    func checkErrorRecovery() {
        errorRecoveryCount += 1
        unlock("bug_squasher")
        if errorRecoveryCount >= 5 { unlock("error_5") }
        if errorRecoveryCount >= 10 { unlock("error_10") }
        if errorRecoveryCount >= 25 { unlock("error_25") }
        if errorRecoveryCount >= 50 { unlock("error_50") }
        saveState()
    }

    private func saveState() {
        // 디바운스: 연속 호출 시 마지막 호출만 실행 (2초 후)
        saveDebounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveStateNow()
        }
        saveDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func saveStateNow() {
        let data: [String: Any] = [
            "totalXP": totalXP,
            "commandCount": commandCount,
            "unlocked": achievements.filter { $0.unlocked }.map { $0.id },
            "totalSessions": totalSessions,
            "totalCompletions": totalCompletions,
            "totalTokensUsed": totalTokensUsed,
            "totalCost": totalCost,
            "errorRecoveryCount": errorRecoveryCount,
            "totalFileEdits": totalFileEdits,
            "totalFileReads": totalFileReads,
            "usedModels": Array(usedModels),
            "uniqueBranches": Array(uniqueBranches),
            "activeDays": Array(activeDays),
            "nightDays": Array(nightDays),
        ]
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func loadState() {
        guard let data = UserDefaults.standard.dictionary(forKey: saveKey) else { return }
        totalXP = data["totalXP"] as? Int ?? 0
        commandCount = data["commandCount"] as? Int ?? 0
        totalSessions = data["totalSessions"] as? Int ?? 0
        totalCompletions = data["totalCompletions"] as? Int ?? 0
        totalTokensUsed = data["totalTokensUsed"] as? Int ?? 0
        totalCost = data["totalCost"] as? Double ?? 0
        errorRecoveryCount = data["errorRecoveryCount"] as? Int ?? 0
        totalFileEdits = data["totalFileEdits"] as? Int ?? 0
        totalFileReads = data["totalFileReads"] as? Int ?? 0
        if let models = data["usedModels"] as? [String] { usedModels = Set(models) }
        if let branches = data["uniqueBranches"] as? [String] { uniqueBranches = Set(branches) }
        if let days = data["activeDays"] as? [String] { activeDays = Set(days) }
        if let nights = data["nightDays"] as? [String] { nightDays = Set(nights) }
        if let unlocked = data["unlocked"] as? [String] {
            for id in unlocked {
                if let idx = achievements.firstIndex(where: { $0.id == id }) {
                    achievements[idx].unlocked = true
                }
            }
        }
        unlockedCount = achievements.filter { $0.unlocked }.count
    }

    private func enqueueRecentUnlock(_ achievement: Achievement) {
        toastQueue.append(achievement)
        showNextRecentUnlockIfNeeded()
    }

    private func showNextRecentUnlockIfNeeded() {
        guard recentUnlock == nil, !toastQueue.isEmpty else { return }
        let nextAchievement = toastQueue.removeFirst()
        recentUnlock = nextAchievement
        scheduleRecentUnlockDismiss(for: nextAchievement.id)
    }

    private func scheduleRecentUnlockDismiss(for id: String) {
        toastDismissWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.recentUnlock?.id == id else { return }
            self.recentUnlock = nil
            self.toastDismissWork = nil
            self.showNextRecentUnlockIfNeeded()
        }

        toastDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Toast (팝업 알림)
// ═══════════════════════════════════════════════════════

struct AchievementToastView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var isVisible = false

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(achievement.rarity.color.opacity(0.16))
                    Text(achievement.icon)
                        .font(Theme.scaled(15))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.name)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text("도전과제 달성")
                        .font(Theme.mono(8, weight: .medium))
                        .foregroundColor(achievement.rarity.color)
                }

                Spacer(minLength: 8)

                Image(systemName: "xmark")
                    .font(.system(size: Theme.iconSize(8), weight: .bold))
                    .foregroundColor(Theme.textDim.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 180, maxWidth: 240, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(Theme.bgCard.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(achievement.rarity.color.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .help("클릭해서 닫기")
        .scaleEffect(isVisible ? 1 : 0.97)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                isVisible = true
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - XP Bar (사이드바용 — 컴팩트)
// ═══════════════════════════════════════════════════════

struct XPBarView: View {
    let xp: Int
    var body: some View {
        let level = WorkerLevel.forXP(xp)
        let progress = WorkerLevel.progress(xp)
        HStack(spacing: 6) {
            Text(level.badge).font(Theme.scaled(12))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Lv.\(level.level) \(level.title)")
                        .font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.yellow)
                    Spacer()
                    Text("\(xp) XP").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.bg).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Theme.yellow, Theme.orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(2, geo.size.width * CGFloat(progress)), height: 3)
                    }
                }.frame(height: 3)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - 도전과제 관리 시트 (풀 화면 패널)
// ═══════════════════════════════════════════════════════

struct AchievementCollectionView: View {
    @ObservedObject var mgr = AchievementManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedRarity: AchievementRarity? = nil
    @State private var showUnlockedOnly = false
    @State private var inspectedAchievement: Achievement? = nil

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    private var completionPercent: Int {
        Int(Double(mgr.unlockedCount) / Double(max(1, mgr.achievements.count)) * 100)
    }

    private func itemsFor(_ rarity: AchievementRarity) -> [Achievement] {
        mgr.achievements.filter { $0.rarity == rarity && (!showUnlockedOnly || $0.unlocked) }
    }

    // 모달 배경 — bg보다 한 톤 더 어둡게
    private var modalBg: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "0a0c12") : Color(hex: "f0f0f4")
    }
    private var panelBg: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "10131a") : Color(hex: "f6f6f9")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ═══════════ 상단: 헤더 영역 ═══════════
            headerSection
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 14)
                .background(
                    panelBg
                        .overlay(
                            // 하단 그라데이션 경계
                            VStack { Spacer(); LinearGradient(colors: [.clear, Theme.border.opacity(0.15)], startPoint: .top, endPoint: .bottom).frame(height: 1) }
                        )
                )

            // ═══════════ 중단: 필터 바 ═══════════
            filterBar
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(panelBg.opacity(0.7))

            Rectangle().fill(Theme.border.opacity(0.2)).frame(height: 1)

            // ═══════════ 본문: 카드 그리드 ═══════════
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    if selectedRarity == nil {
                        raritySection(.legendary)
                        raritySection(.epic)
                        raritySection(.rare)
                        raritySection(.common)
                    } else {
                        let items = mgr.achievements.filter { $0.rarity == selectedRarity && (!showUnlockedOnly || $0.unlocked) }
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(items) { ach in
                                AchievementCard(achievement: ach)
                                    .onTapGesture { if ach.unlocked { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { inspectedAchievement = ach } } }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 16)
            }
        }
        .background(modalBg)
        .overlay(detailOverlay)
    }

    // MARK: - Header

    private var headerSection: some View {
        let level = mgr.currentLevel
        let xpProgress = WorkerLevel.progress(mgr.totalXP)
        let next = WorkerLevel.nextLevel(mgr.totalXP)
        let progressFraction = Double(mgr.unlockedCount) / Double(max(1, mgr.achievements.count))

        return HStack(spacing: 0) {
            // 좌측: 프로그레스 링 + 제목
            HStack(spacing: 16) {
                progressRing(fraction: progressFraction)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACHIEVEMENTS")
                        .font(Theme.mono(13, weight: .heavy))
                        .foregroundColor(Theme.textPrimary).tracking(2)
                    Text("\(mgr.unlockedCount)개 달성 / 총 \(mgr.achievements.count)개")
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            // 중앙: 레벨 카드
            levelCard(level: level, xpProgress: xpProgress, next: next)
                .frame(width: 180)

            Spacer()

            // 우측: 통계
            HStack(spacing: 20) {
                statPill(icon: "⚡", value: "\(mgr.totalXP)", label: "XP", color: Theme.yellow)
                statPill(icon: "🎯", value: "\(mgr.commandCount)", label: "명령", color: Theme.accent)
                statPill(icon: "🪙", value: formatTokens(mgr.totalTokensUsed), label: "토큰", color: Theme.cyan)
                statPill(icon: "🔥", value: "\(mgr.activeDays.count)일", label: "활동", color: Theme.orange)
            }

            Spacer().frame(width: 16)

            // 닫기 버튼
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Theme.iconSize(18)))
                    .foregroundColor(Theme.textDim.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("닫기 (Esc)")
        }
    }

    private func progressRing(fraction: Double) -> some View {
        ZStack {
            Circle().stroke(Theme.border.opacity(0.15), lineWidth: 4).frame(width: 52, height: 52)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(colors: [Theme.yellow, Theme.orange, Theme.yellow], center: .center),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(completionPercent)")
                    .font(Theme.mono(15, weight: .black))
                    .foregroundColor(Theme.yellow)
                Text("%").font(Theme.mono(7, weight: .bold))
                    .foregroundColor(Theme.yellow.opacity(0.5))
            }
        }
    }

    private func levelCard(level: WorkerLevel, xpProgress: Double, next: WorkerLevel?) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.yellow.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: 20))
                    .frame(width: 38, height: 38)
                Text(level.badge).font(Theme.scaled(20))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Text("Lv.\(level.level)")
                        .font(Theme.mono(11, weight: .black))
                        .foregroundColor(Theme.yellow)
                    Text(level.title)
                        .font(Theme.mono(10, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.border.opacity(0.15)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Theme.yellow, Theme.orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(2, geo.size.width * CGFloat(xpProgress)), height: 4)
                            .shadow(color: Theme.yellow.opacity(0.3), radius: 3, y: 0)
                    }
                }.frame(height: 4)
                if let next = next {
                    Text("\(mgr.totalXP) / \(next.xpRequired) XP")
                        .font(Theme.mono(7)).foregroundColor(Theme.textDim)
                } else {
                    Text("MAX LEVEL").font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.yellow)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(Theme.bgCard)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.yellow.opacity(0.12), lineWidth: 1))
        )
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(icon).font(Theme.scaled(10))
            Text(value).font(Theme.mono(10, weight: .bold)).foregroundColor(color)
            Text(label).font(Theme.mono(7)).foregroundColor(Theme.textDim)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            filterTab(label: "전체", rarity: nil, count: mgr.achievements.count, unlocked: mgr.unlockedCount)
            ForEach([AchievementRarity.legendary, .epic, .rare, .common], id: \.rawValue) { r in
                filterTab(label: r.rawValue, rarity: r,
                          count: mgr.achievements.filter { $0.rarity == r }.count,
                          unlocked: mgr.achievements.filter { $0.rarity == r && $0.unlocked }.count)
            }

            Spacer()

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showUnlockedOnly.toggle() } }) {
                HStack(spacing: 5) {
                    Image(systemName: showUnlockedOnly ? "eye.fill" : "eye").font(.system(size: Theme.iconSize(11)))
                    Text(showUnlockedOnly ? "달성만" : "전부 보기")
                        .font(Theme.mono(11, weight: .medium))
                }
                .foregroundColor(showUnlockedOnly ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(
                    Capsule().fill(showUnlockedOnly ? Theme.accent.opacity(0.12) : Theme.bgSurface)
                        .overlay(Capsule().stroke(showUnlockedOnly ? Theme.accent.opacity(0.3) : Theme.border.opacity(0.2), lineWidth: 0.5))
                )
            }.buttonStyle(.plain)
        }
    }

    private func filterTab(label: String, rarity: AchievementRarity?, count: Int, unlocked: Int) -> some View {
        let isSelected = (selectedRarity == nil && rarity == nil) || selectedRarity == rarity
        let color = rarity?.color ?? Theme.yellow

        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedRarity = rarity } }) {
            HStack(spacing: 6) {
                if let r = rarity { Circle().fill(r.color).frame(width: 7, height: 7) }
                Text(label).font(Theme.mono(11, weight: isSelected ? .bold : .medium))
                Text("\(unlocked)/\(count)")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(isSelected ? color : Theme.textDim)
            }
            .foregroundColor(isSelected ? color : Theme.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.12) : .clear)
                    .overlay(Capsule().stroke(isSelected ? color.opacity(0.4) : Theme.border.opacity(0.15), lineWidth: isSelected ? 1 : 0.5))
            )
        }.buttonStyle(.plain)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000000 { return String(format: "%.1fM", Double(count) / 1000000) }
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
        return "\(count)"
    }

    // MARK: - Rarity Section

    private func raritySection(_ rarity: AchievementRarity) -> some View {
        let items = itemsFor(rarity)
        let unlocked = items.filter { $0.unlocked }.count
        let total = mgr.achievements.filter { $0.rarity == rarity }.count
        let progress = Double(unlocked) / Double(max(1, total))

        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    // 섹션 헤더
                    sectionHeader(rarity: rarity, unlocked: unlocked, total: total, progress: progress)

                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(items) { ach in
                            AchievementCard(achievement: ach)
                                .onTapGesture { if ach.unlocked { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { inspectedAchievement = ach } } }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(sectionBg(rarity))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(rarity.color.opacity(0.08), lineWidth: 1))
                )
            }
        }
    }

    private func sectionHeader(rarity: AchievementRarity, unlocked: Int, total: Int, progress: Double) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(rarity.color).frame(width: 3, height: 14)
            Text(rarity.rawValue.uppercased())
                .font(Theme.mono(10, weight: .heavy))
                .foregroundColor(rarity.color).tracking(2)

            Text("\(unlocked)/\(total)")
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(rarity.color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(rarity.color.opacity(0.1)).overlay(Capsule().stroke(rarity.color.opacity(0.2), lineWidth: 0.5)))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(rarity.color.opacity(0.06)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(rarity.color.opacity(0.4))
                        .frame(width: max(2, geo.size.width * CGFloat(progress)), height: 3)
                }
            }.frame(height: 3)

            if unlocked == total && total > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.green)
                    Text("COMPLETE").font(Theme.mono(7, weight: .heavy)).foregroundColor(Theme.green).tracking(1)
                }
            }
        }
    }

    private func sectionBg(_ rarity: AchievementRarity) -> Color {
        if AppSettings.shared.isDarkMode {
            switch rarity {
            case .legendary: return Color(hex: "12110d")
            case .epic: return Color(hex: "110f16")
            case .rare: return Color(hex: "0e1018")
            case .common: return Color(hex: "0e1014")
            }
        } else {
            switch rarity {
            case .legendary: return Color(hex: "faf6ed")
            case .epic: return Color(hex: "f4f0f8")
            case .rare: return Color(hex: "eef2f9")
            case .common: return Color(hex: "f2f2f5")
            }
        }
    }
    // MARK: - Detail Overlay (카드형 상세 뷰)

    @ViewBuilder
    private var detailOverlay: some View {
        if let ach = inspectedAchievement {
            ZStack {
                // 딤 배경
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { inspectedAchievement = nil } }

                AchievementDetailCard(achievement: ach) {
                    withAnimation(.easeOut(duration: 0.2)) { inspectedAchievement = nil }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Detail Card (수집형 카드)
// ═══════════════════════════════════════════════════════

struct AchievementDetailCard: View {
    let achievement: Achievement
    let onClose: () -> Void
    @State private var appeared = false

    private var rarityGradient: [Color] {
        switch achievement.rarity {
        case .legendary: return [Color(hex: "2a2410"), Color(hex: "1a1608"), Color(hex: "12100a")]
        case .epic: return [Color(hex: "1e1628"), Color(hex: "15101e"), Color(hex: "100c18")]
        case .rare: return [Color(hex: "101828"), Color(hex: "0c1220"), Color(hex: "0a0e18")]
        case .common: return [Color(hex: "161a22"), Color(hex: "12151c"), Color(hex: "0e1016")]
        }
    }

    private var rarityGradientLight: [Color] {
        switch achievement.rarity {
        case .legendary: return [Color(hex: "fef9ec"), Color(hex: "fdf5e0"), Color(hex: "faf0d4")]
        case .epic: return [Color(hex: "f8f2fc"), Color(hex: "f3ecf9"), Color(hex: "eee6f6")]
        case .rare: return [Color(hex: "eef4fc"), Color(hex: "e8eef8"), Color(hex: "e2e8f4")]
        case .common: return [Color(hex: "f6f6f9"), Color(hex: "f0f0f4"), Color(hex: "eaeaef")]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 카드 상단: 레어리티 배너 ──
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(achievement.rarity.color).frame(width: 7, height: 7)
                    Text(achievement.rarity.rawValue.uppercased())
                        .font(Theme.mono(9, weight: .heavy))
                        .foregroundColor(achievement.rarity.color).tracking(2)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                        .foregroundColor(Theme.textDim.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Theme.bgSurface.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

            // ── 아이콘 영역 ──
            ZStack {
                // 다중 글로우 링
                Circle()
                    .fill(RadialGradient(
                        colors: [achievement.rarity.color.opacity(0.2), achievement.rarity.color.opacity(0.05), .clear],
                        center: .center, startRadius: 0, endRadius: 60
                    ))
                    .frame(width: 120, height: 120)
                Circle()
                    .stroke(achievement.rarity.color.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(achievement.rarity.color.opacity(0.08), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Text(achievement.icon)
                    .font(Theme.scaled(52))
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.vertical, 10)

            // ── 이름 ──
            Text(achievement.name)
                .font(Theme.mono(18, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.top, 4)

            // ── 설명 ──
            Text(achievement.description)
                .font(Theme.mono(12))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.top, 6)

            Spacer().frame(height: 20)

            // ── 하단 정보 패널 ──
            VStack(spacing: 10) {
                Rectangle().fill(achievement.rarity.color.opacity(0.15)).frame(height: 1)
                    .padding(.horizontal, 16)

                HStack(spacing: 0) {
                    detailItem(label: "보상", value: "+\(achievement.xpReward) XP", color: Theme.yellow)
                    detailDivider
                    detailItem(label: "등급", value: achievement.rarity.rawValue, color: achievement.rarity.color)
                    detailDivider
                    if let date = achievement.unlockedAt {
                        detailItem(label: "달성일", value: fmtDateFull(date), color: Theme.green)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 280, height: 380)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: AppSettings.shared.isDarkMode ? rarityGradient : rarityGradientLight,
                        startPoint: .top, endPoint: .bottom
                    ))
                // 외곽 글로우 보더
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [achievement.rarity.color.opacity(0.5), achievement.rarity.color.opacity(0.15), achievement.rarity.color.opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1.5
                    )
            }
        )
        .shadow(color: achievement.rarity.color.opacity(0.35), radius: 30, y: 8)
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.1)) { appeared = true }
        }
    }

    private func detailItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(Theme.mono(7, weight: .medium))
                .foregroundColor(Theme.textDim).tracking(0.5)
            Text(value)
                .font(Theme.mono(11, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var detailDivider: some View {
        Rectangle().fill(Theme.border.opacity(0.15)).frame(width: 1, height: 28)
    }

    private func fmtDateFull(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yy.M.d"; return f.string(from: date)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Card
// ═══════════════════════════════════════════════════════

struct AchievementCard: View {
    let achievement: Achievement
    @State private var isHovered = false

    private var cardBg: Color {
        if AppSettings.shared.isDarkMode {
            switch achievement.rarity {
            case .legendary: return Color(hex: "1c1a12")
            case .epic: return Color(hex: "19161f")
            case .rare: return Color(hex: "141722")
            case .common: return Color(hex: "151820")
            }
        } else {
            switch achievement.rarity {
            case .legendary: return Color(hex: "fffcf3")
            case .epic: return Color(hex: "f9f5fd")
            case .rare: return Color(hex: "f2f6fc")
            case .common: return .white
            }
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            if achievement.unlocked {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: achievement.unlocked ? 100 : 70)
        .background(cardBackground)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovered = h } }
    }

    // MARK: - Unlocked

    private var unlockedContent: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [achievement.rarity.color.opacity(0.2), .clear], center: .center, startRadius: 0, endRadius: 20))
                    .frame(width: 36, height: 36)
                Text(achievement.icon).font(Theme.scaled(20))
            }
            Text(achievement.name)
                .font(Theme.mono(9, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            Text(achievement.description)
                .font(Theme.mono(7))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(minHeight: 18)
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.iconSize(6))).foregroundColor(Theme.green)
                if let date = achievement.unlockedAt {
                    Text(fmtDate(date)).font(Theme.mono(6)).foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("+\(achievement.xpReward)")
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundColor(Theme.yellow.opacity(0.8))
            }
        }
    }

    // MARK: - Locked

    private var lockedContent: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(Theme.bgSurface.opacity(0.3)).frame(width: 30, height: 30)
                Circle().stroke(Theme.border.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: 30, height: 30)
                Image(systemName: "lock.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.textDim.opacity(0.2))
            }
            Text("???")
                .font(Theme.mono(8, weight: .medium))
                .foregroundColor(Theme.textDim.opacity(0.3))
            if isHovered {
                Text(achievement.description)
                    .font(Theme.mono(6.5))
                    .foregroundColor(Theme.textDim.opacity(0.45))
                    .lineLimit(2).multilineTextAlignment(.center)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Image(systemName: "star.fill").font(.system(size: Theme.iconSize(5))).foregroundColor(Theme.yellow.opacity(0.15))
                Text("+\(achievement.xpReward)").font(Theme.mono(6.5)).foregroundColor(Theme.yellow.opacity(0.15))
                Spacer()
            }
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(achievement.unlocked ? cardBg : Theme.bgSurface.opacity(0.08))

            if achievement.unlocked {
                VStack {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(colors: [achievement.rarity.color.opacity(0.5), achievement.rarity.color.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 2)
                        .padding(.horizontal, 10)
                    Spacer()
                }
            }

            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    achievement.unlocked
                        ? achievement.rarity.color.opacity(isHovered ? 0.5 : 0.18)
                        : Theme.border.opacity(isHovered ? 0.2 : 0.06),
                    lineWidth: achievement.unlocked ? 1 : 0.5
                )
        }
        .shadow(color: achievement.unlocked ? achievement.rarity.color.opacity(isHovered ? 0.2 : 0.05) : .clear, radius: isHovered ? 10 : 3)
    }

    private func fmtDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - 사이드바용 업적 없음 (레벨만 유지)
// ═══════════════════════════════════════════════════════

struct AchievementsView: View {
    var body: some View { EmptyView() }
}
