import SwiftUI
import UniformTypeIdentifiers
import os


enum AutomationTemplateKind: String, CaseIterable, Identifiable {
    case planner
    case designer
    case developerExecution
    case developerRevision
    case reviewer
    case qa
    case reporter
    case sre

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planner: return NSLocalizedString("template.pipeline.planner", comment: "")
        case .designer: return NSLocalizedString("template.pipeline.designer", comment: "")
        case .developerExecution: return NSLocalizedString("template.pipeline.dev.exec", comment: "")
        case .developerRevision: return NSLocalizedString("template.pipeline.dev.revision", comment: "")
        case .reviewer: return NSLocalizedString("template.pipeline.reviewer", comment: "")
        case .qa: return "QA"
        case .reporter: return NSLocalizedString("template.pipeline.reporter", comment: "")
        case .sre: return "SRE"
        }
    }

    var shortLabel: String {
        switch self {
        case .developerExecution: return NSLocalizedString("template.pipeline.dev.exec.short", comment: "")
        case .developerRevision: return NSLocalizedString("template.pipeline.dev.revision.short", comment: "")
        default: return displayName
        }
    }

    var icon: String {
        switch self {
        case .planner: return "list.bullet.rectangle.portrait.fill"
        case .designer: return "paintbrush.pointed.fill"
        case .developerExecution: return "hammer.fill"
        case .developerRevision: return "arrow.triangle.2.circlepath"
        case .reviewer: return "checklist.checked"
        case .qa: return "checkmark.seal.fill"
        case .reporter: return "doc.text.fill"
        case .sre: return "server.rack"
        }
    }

    var summary: String {
        switch self {
        case .planner: return NSLocalizedString("template.pipeline.planner.desc", comment: "")
        case .designer: return NSLocalizedString("template.pipeline.designer.desc", comment: "")
        case .developerExecution: return NSLocalizedString("template.pipeline.dev.exec.desc", comment: "")
        case .developerRevision: return NSLocalizedString("template.pipeline.dev.revision.desc", comment: "")
        case .reviewer: return NSLocalizedString("template.pipeline.reviewer.desc", comment: "")
        case .qa: return NSLocalizedString("template.pipeline.qa.desc", comment: "")
        case .reporter: return NSLocalizedString("template.pipeline.reporter.desc", comment: "")
        case .sre: return NSLocalizedString("template.pipeline.sre.desc", comment: "")
        }
    }

    var placeholderTokens: [String] {
        switch self {
        case .planner:
            return ["{{project_name}}", "{{project_path}}", "{{request}}"]
        case .designer:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}"]
        case .developerExecution:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}"]
        case .developerRevision:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}", "{{feedback_role}}", "{{feedback}}"]
        case .reviewer:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}", "{{dev_summary}}", "{{changed_files}}"]
        case .qa:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}", "{{dev_summary}}", "{{review_summary}}", "{{changed_files}}"]
        case .reporter:
            return ["{{project_name}}", "{{report_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}", "{{dev_summary}}", "{{review_summary}}", "{{qa_summary}}", "{{validation_summary}}", "{{changed_files}}"]
        case .sre:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{dev_summary}}", "{{qa_summary}}", "{{validation_summary}}", "{{changed_files}}"]
        }
    }

    var pinnedLines: [String] {
        switch self {
        case .planner:
            return ["PLANNER_STATUS: READY"]
        case .designer:
            return ["DESIGN_STATUS: READY"]
        case .reviewer:
            return ["REVIEW_STATUS: PASS", "REVIEW_STATUS: FAIL", "REVIEW_STATUS: BLOCKED"]
        case .qa:
            return ["QA_STATUS: PASS", "QA_STATUS: FAIL", "QA_STATUS: BLOCKED"]
        case .reporter:
            return ["REPORT_STATUS: WRITTEN", "REPORT_PATH: {{report_path}}"]
        case .sre:
            return ["SRE_STATUS: CHECKED"]
        case .developerExecution, .developerRevision:
            return []
        }
    }

    var defaultTemplate: String {
        switch self {
        case .planner:
            return """
당신은 도피스의 기획자입니다.
아래 사용자 요구사항을 보고 개발자가 바로 구현할 수 있게 정리하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

사용자 요구사항:
{{request}}

정리 양식:
- 요구사항 한 줄 요약
- 반드시 구현할 핵심 항목
- 수용 기준
- 주의할 점
- 디자이너/개발자 메모
"""
        case .designer:
            return """
당신은 도피스의 디자이너입니다.
아래 요구사항과 기획 요약을 바탕으로 UI/UX, 상호작용, 화면 흐름 관점의 정리본을 만들어 주세요.

프로젝트: {{project_name}}
경로: {{project_path}}

원래 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

정리 양식:
- 화면/상태 흐름
- 사용자 경험상 주의할 점
- edge case
- 개발 메모
"""
        case .developerExecution:
            return """
아래 요구사항을 구현하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

원래 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인/경험 메모:
{{design_summary}}

구현 지침:
1. 필요한 코드를 직접 수정하세요.
2. 변경 파일과 검증 결과를 명확히 남기세요.
3. 작업을 마치면 완료 요약을 짧게 정리하세요.
"""
        case .developerRevision:
            return """
아래 요구사항을 다시 구현하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

원래 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인/경험 메모:
{{design_summary}}

추가 수정 피드백 ({{feedback_role}}):
{{feedback}}

재작업 지침:
1. 피드백을 반영해 필요한 코드를 직접 수정하세요.
2. 어떤 점을 고쳤는지 완료 요약에 꼭 포함하세요.
3. 검증 결과까지 함께 남기세요.
"""
        case .reviewer:
            return """
당신은 도피스의 코드 리뷰어입니다.
아래 개발 작업이 완료되었고 코드 수정도 발생했습니다. 코드는 수정하지 말고, 변경 내용과 리스크를 검토하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

최근 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인 요약:
{{design_summary}}

개발 완료 요약:
{{dev_summary}}

변경된 파일:
{{changed_files}}

검토 양식:
- 핵심 findings
- 테스트/검증 부족
- 오픈 질문 또는 우려점
- 최종 판단
"""
        case .qa:
            return """
당신은 도피스의 QA 담당자입니다.
아래 개발 작업이 완료되었습니다. 변경된 흐름을 직접 실행/테스트해 검증하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

최근 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인 요약:
{{design_summary}}

개발 완료 요약:
{{dev_summary}}

코드 리뷰 요약:
{{review_summary}}

변경된 파일:
{{changed_files}}

검증 양식:
- 실제로 실행/테스트한 항목
- 확인 결과
- 재현 단계 또는 관찰 내용
- 남은 리스크
- 최종 판단
"""
        case .reporter:
            return """
당신은 도피스의 보고자입니다.
최종 Markdown 보고서를 작성하세요.

프로젝트: {{project_name}}
저장 경로: {{report_path}}

원래 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인 요약:
{{design_summary}}

개발 결과 요약:
{{dev_summary}}

코드 리뷰 요약:
{{review_summary}}

QA 결과:
{{qa_summary}}

추가 검증 요약:
{{validation_summary}}

변경 파일:
{{changed_files}}

보고서 기본 구조 (첫 줄의 주석은 반드시 포함하세요):
<!-- 도피스:Reporter -->
# 작업 보고서
## 요구사항
## 구현 결과
## QA 검증 결과
## 변경 파일
## 남은 리스크 및 다음 단계
"""
        case .sre:
            return """
당신은 도피스의 SRE입니다.
아래 구현 결과를 운영/배포/실행 안정성 관점에서 점검하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

원래 요구사항:
{{request}}

개발 결과 요약:
{{dev_summary}}

QA 요약:
{{qa_summary}}

추가 검증 요약:
{{validation_summary}}

변경 파일:
{{changed_files}}

점검 양식:
- 배포/실행 리스크
- 환경 변수/설정 포인트
- 모니터링/알람 제안
- 롤백/수동 점검 포인트
- 최종 안정성 메모
"""
        }
    }

    var automationContract: String {
        switch self {
        case .planner:
            return """
자동화 상태 계약:
- 응답 마지막 줄에 정확히 아래 한 줄을 남기세요.
PLANNER_STATUS: READY
"""
        case .designer:
            return """
자동화 상태 계약:
- 응답 마지막 줄에 정확히 아래 한 줄을 남기세요.
DESIGN_STATUS: READY
"""
        case .reviewer:
            return """
자동화 상태 계약:
- 응답 마지막 줄에는 아래 셋 중 하나만 정확히 한 줄로 남기세요.
REVIEW_STATUS: PASS
REVIEW_STATUS: FAIL
REVIEW_STATUS: BLOCKED
"""
        case .qa:
            return """
자동화 상태 계약:
- 응답 마지막 줄에는 아래 셋 중 하나만 정확히 한 줄로 남기세요.
QA_STATUS: PASS
QA_STATUS: FAIL
QA_STATUS: BLOCKED
"""
        case .reporter:
            return """
자동화 상태 계약:
- {{report_path}} 파일을 Markdown으로 작성하거나 갱신하세요.
- 응답 마지막 두 줄을 정확히 아래처럼 남기세요.
REPORT_STATUS: WRITTEN
REPORT_PATH: {{report_path}}
"""
        case .sre:
            return """
자동화 상태 계약:
- 응답 마지막 줄에 정확히 아래 한 줄을 남기세요.
SRE_STATUS: CHECKED
"""
        case .developerExecution, .developerRevision:
            return ""
        }
    }
}

final class AutomationTemplateStore: ObservableObject {
    static let shared = AutomationTemplateStore()

    private let saveKey = "doffice.automation.templates.v1"
    private let persistenceQueue = DispatchQueue(label: "doffice.automation-template-store", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?
    @Published private(set) var revision: Int = 0

    private var overrides: [String: String] = [:]

    private init() {
        load()
    }

    func template(for kind: AutomationTemplateKind) -> String {
        overrides[kind.rawValue] ?? kind.defaultTemplate
    }

    func binding(for kind: AutomationTemplateKind) -> Binding<String> {
        Binding(
            get: { self.template(for: kind) },
            set: { self.setTemplate($0, for: kind) }
        )
    }

    func isCustomized(_ kind: AutomationTemplateKind) -> Bool {
        overrides[kind.rawValue] != nil
    }

    func setTemplate(_ text: String, for kind: AutomationTemplateKind) {
        if text == kind.defaultTemplate {
            overrides.removeValue(forKey: kind.rawValue)
        } else {
            overrides[kind.rawValue] = text
        }
        revision &+= 1
        scheduleSave()
    }

    func reset(_ kind: AutomationTemplateKind) {
        overrides.removeValue(forKey: kind.rawValue)
        revision &+= 1
        scheduleSave()
    }

    func resetAll() {
        overrides.removeAll()
        revision &+= 1
        scheduleSave()
    }

    func render(_ kind: AutomationTemplateKind, context: [String: String]) -> String {
        // 프롬프트 자동 주입이 비활성화된 역할이면 빈 문자열 반환
        guard AppSettings.shared.isPromptEnabled(for: kind.rawValue) else { return "" }
        let body = renderText(template(for: kind), context: context)
        let contract = renderText(kind.automationContract, context: context)
        guard !contract.isEmpty else { return body }
        return body + "\n\n" + contract
    }

    private func renderText(_ template: String, context: [String: String]) -> String {
        var rendered = template
        for (key, value) in context {
            rendered = rendered.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return rendered
    }

    private func scheduleSave(delay: TimeInterval = 0.25) {
        saveWorkItem?.cancel()
        let snapshot = overrides
        let key = saveKey
        let workItem = DispatchWorkItem {
            if snapshot.isEmpty {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                do {
                    let data = try JSONEncoder().encode(snapshot)
                    UserDefaults.standard.set(data, forKey: key)
                } catch {
                    CrashLogger.shared.error("TokenOverrides: Failed to encode overrides — \(error.localizedDescription)")
                }
            }
        }
        saveWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        do {
            overrides = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            CrashLogger.shared.error("TokenOverrides: Failed to decode saved overrides — \(error.localizedDescription)")
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Background Theme
// ═══════════════════════════════════════════════════════

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case auto, sunny, clearSky, sunset, goldenHour, dusk
    case moonlit, starryNight, aurora, milkyWay
    case storm, rain, snow, fog
    case cherryBlossom, autumn, forest
    case neonCity, ocean, desert, volcano

    var id: String { rawValue }

    var displayName: String {
        NSLocalizedString("weather.\(rawValue)", comment: "")
    }

    var icon: String {
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

    var skyColors: (top: String, bottom: String) {
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

    var floorColors: (base: String, dot: String) {
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

    var requiredLevel: Int? {
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

    var isUnlocked: Bool {
        if UserDefaults.standard.bool(forKey: "allContentUnlocked") { return true }
        guard let level = requiredLevel else { return true }
        return AchievementManager.shared.currentLevel.level >= level
    }

    var lockReason: String {
        guard let level = requiredLevel else { return "" }
        let currentLevel = AchievementManager.shared.currentLevel.level
        if currentLevel < level { return String(format: NSLocalizedString("settings.level.required", comment: ""), level) }
        return ""
    }

}

// ═══════════════════════════════════════════════════════
// MARK: - Furniture Item Model
// ═══════════════════════════════════════════════════════

struct FurnitureItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let defaultNormX: CGFloat  // 0-1 normalized within room
    let defaultNormY: CGFloat  // 0-1 normalized (0=top wall, 1=floor)
    let width: CGFloat
    let height: CGFloat
    let isWallItem: Bool       // constrained to upper wall zone
    let requiredLevel: Int?          // nil = 기본 해금
    let requiredAchievement: String? // nil = 레벨만 체크

    var isUnlocked: Bool {
        // 시크릿키로 전체 해금된 경우
        if UserDefaults.standard.bool(forKey: "allContentUnlocked") { return true }
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

    var lockReason: String {
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

    static let all: [FurnitureItem] = [
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

struct CoffeeSupportTier: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let amount: Int
    let icon: String

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var amountLabel: String {
        let number = NSNumber(value: amount)
        let formatted = Self.formatter.string(from: number) ?? "\(amount)"
        return "\(formatted)원"
    }

    var tint: Color {
        switch id {
        case "starter": return Theme.orange
        case "booster": return Theme.cyan
        default: return Theme.pink
        }
    }

    static let presets: [CoffeeSupportTier] = [
        CoffeeSupportTier(id: "starter", title: NSLocalizedString("coffee.tier.americano", comment: ""), subtitle: NSLocalizedString("coffee.tier.americano.sub", comment: ""), amount: 3000, icon: "cup.and.saucer.fill"),
        CoffeeSupportTier(id: "booster", title: NSLocalizedString("coffee.tier.latte", comment: ""), subtitle: NSLocalizedString("coffee.tier.latte.sub", comment: ""), amount: 5000, icon: "mug.fill"),
        CoffeeSupportTier(id: "nightshift", title: NSLocalizedString("coffee.tier.nightshift", comment: ""), subtitle: NSLocalizedString("coffee.tier.nightshift.sub", comment: ""), amount: 10000, icon: "takeoutbag.and.cup.and.straw.fill")
    ]
}

// ═══════════════════════════════════════════════════════
// MARK: - ThemeLock (os_unfair_lock wrapper)
// ═══════════════════════════════════════════════════════

/// os_unfair_lock 기반 스레드 안전 잠금 — Theme 캐시 보호용
final class ThemeLock: @unchecked Sendable {
    private var _lock = os_unfair_lock()

    func lock() { os_unfair_lock_lock(&_lock) }
    func unlock() { os_unfair_lock_unlock(&_lock) }

    @inline(__always)
    func withLock<T>(_ body: () -> T) -> T {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return body()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Theme (동적 테마)
// ═══════════════════════════════════════════════════════

enum Theme {
    // ── Thread-safe Theme Cache ──
    // os_unfair_lock으로 멀티스레드 접근 보호
    private static let _lock = ThemeLock()

    private static var _cachedDark: Bool = false
    private static var _cachedIsCustom: Bool = false
    private static var _cachedCustomConfig: CustomThemeConfig?
    private static var _cachedScale: CGFloat = 1.5
    private static var _cacheSignature: Int = -1
    private static var _fontCache: [String: Font] = [:]

    /// settings 시그니처 — 메모이제이션으로 중복 해싱 방지
    /// ensureCache()가 렌더 당 수십~수백 번 호출되므로 빠른 비교가 핵심
    private static var _memoizedSigInputs: (Bool, String, Double, String) = (false, "", 0, "")
    private static var _memoizedSigValue: Int = -1

    private static func settingsSignature() -> Int {
        let s = AppSettings.shared
        let inputs = (s.isDarkMode, s.themeMode, s.fontSizeScale, s.customThemeJSON)
        _lock.lock()
        if inputs.0 == _memoizedSigInputs.0 &&
           inputs.1 == _memoizedSigInputs.1 &&
           inputs.2 == _memoizedSigInputs.2 &&
           inputs.3 == _memoizedSigInputs.3 {
            let cached = _memoizedSigValue
            _lock.unlock()
            return cached
        }
        _lock.unlock()
        var h = Hasher()
        h.combine(inputs.0)
        h.combine(inputs.1)
        h.combine(inputs.2)
        h.combine(inputs.3)
        let sig = h.finalize()
        _lock.lock()
        _memoizedSigInputs = inputs
        _memoizedSigValue = sig
        _lock.unlock()
        return sig
    }

    private static func ensureCache() {
        let sig = settingsSignature()
        _lock.lock()
        guard sig != _cacheSignature else { _lock.unlock(); return }
        _lock.unlock()
        let settings = AppSettings.shared
        let dark = settings.isDarkMode
        let isCustom = settings.themeMode == "custom"
        let config: CustomThemeConfig? = isCustom ? settings.customTheme : nil
        let scale = CGFloat(settings.fontSizeScale)
        _lock.lock()
        _cachedDark = dark
        _cachedIsCustom = isCustom
        _cachedCustomConfig = config
        _cachedScale = scale
        _fontCache.removeAll()
        _colorCache.removeAll()
        _cacheSignature = sig
        _lock.unlock()
    }

    /// 외부에서 강제 캐시 무효화 (스레드 안전)
    static func invalidateCache() {
        _lock.lock()
        _cacheSignature = -1
        _colorCache.removeAll()
        _lock.unlock()
    }

    // ── Color 캐시 — hex → Color 변환을 한 번만 수행 ──
    private static var _colorCache: [String: Color] = [:]

    private static func cachedColor(_ key: String, _ hex: String) -> Color {
        _lock.lock()
        if let c = _colorCache[key] { _lock.unlock(); return c }
        _lock.unlock()
        let c = Color(hex: hex)
        _lock.lock()
        _colorCache[key] = c
        _lock.unlock()
        return c
    }

    private static var dark: Bool { ensureCache(); return _lock.withLock { _cachedDark } }
    static var isCustomMode: Bool { ensureCache(); return _lock.withLock { _cachedIsCustom } }
    static var cachedCustomConfig: CustomThemeConfig? { ensureCache(); return _lock.withLock { _cachedCustomConfig } }

    private static var scale: CGFloat { ensureCache(); return _lock.withLock { _cachedScale } }
    /// UI 크롬(툴바, 사이드바, 필터 등)용 완화된 스케일 — 콘텐츠보다 덜 커짐
    private static var chromeScale: CGFloat { 1 + (scale - 1) * 0.5 }

    private static func cachedFont(key: String, create: () -> Font) -> Font {
        _lock.lock()
        if let cached = _fontCache[key] {
            _lock.unlock()
            return cached
        }
        _lock.unlock()

        let font = create()

        _lock.lock()
        if let cached = _fontCache[key] {
            _lock.unlock()
            return cached
        }
        _fontCache[key] = font
        _lock.unlock()
        return font
    }

    /// Clear font cache (call when font settings change)
    static func invalidateFontCache() {
        _lock.lock()
        _fontCache.removeAll()
        _cacheSignature = -1
        _lock.unlock()
    }

    // ═══════════════════════════════════════════════════════
    // 도피스 디자인 시스템 (Vercel Geist 재해석)
    //
    // 철학: 도피스의 세계관 + Vercel급 컴포넌트 정제도
    // - 순수 블랙/그레이스케일 surface 계층
    // - 얇은 1px border로 구조 표현, 그림자 없음
    // - 색상은 상태 표시에만 절제하여 사용
    // - UI는 산세리프, 코드/터미널만 monospaced
    // - 도트 캐릭터 영역은 그대로 보존
    // ═══════════════════════════════════════════════════════

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 1. COLOR TOKENS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // ── Background Surfaces (4-layer depth system) ──
    // Layer 0: App background (deepest)
    static var bg: Color {
        if let config = cachedCustomConfig, let hex = config.bgHex, !hex.isEmpty { return cachedColor("bg_\(hex)", hex) }
        return cachedColor(dark ? "bg_d" : "bg_l", dark ? "000000" : "fafafa")
    }
    // Layer 1: Card / elevated panel
    static var bgCard: Color {
        if let config = cachedCustomConfig, let hex = config.bgCardHex, !hex.isEmpty { return cachedColor("bgC_\(hex)", hex) }
        return cachedColor(dark ? "bgC_d" : "bgC_l", dark ? "0a0a0a" : "ffffff")
    }
    // Layer 2: Raised surface / nested element
    static var bgSurface: Color {
        if let config = cachedCustomConfig, let hex = config.bgSurfaceHex, !hex.isEmpty { return cachedColor("bgS_\(hex)", hex) }
        return cachedColor(dark ? "bgSf_d" : "bgSf_l", dark ? "111111" : "f5f5f5")
    }
    // Layer 3: Tertiary surface (badges, code blocks)
    static var bgTertiary: Color {
        if let config = cachedCustomConfig, let hex = config.bgTertiaryHex, !hex.isEmpty { return cachedColor("bgT_\(hex)", hex) }
        return cachedColor(dark ? "bgT_d" : "bgT_l", dark ? "1a1a1a" : "ebebeb")
    }

    // ── Functional backgrounds ──
    static var bgTerminal: Color {
        if let config = cachedCustomConfig, let hex = config.bgHex, !hex.isEmpty { return cachedColor("bgTm_\(hex)", hex) }
        return cachedColor(dark ? "bgTm_d" : "bgTm_l", dark ? "0a0a0a" : "fafafa")
    }
    static var bgInput: Color { cachedColor(dark ? "bgI_d" : "bgI_l", dark ? "000000" : "ffffff") }
    static var bgHover: Color { cachedColor(dark ? "bgH_d" : "bgH_l", dark ? "1a1a1a" : "f0f0f0") }
    static var bgSelected: Color { cachedColor(dark ? "bgSel_d" : "bgSel_l", dark ? "1a1a1a" : "eaeaea") }
    static var bgPressed: Color { cachedColor(dark ? "bgP_d" : "bgP_l", dark ? "222222" : "e5e5e5") }
    static var bgDisabled: Color { cachedColor(dark ? "bgD_d" : "bgD_l", dark ? "0a0a0a" : "f5f5f5") }
    static var bgOverlay: Color { dark ? Color(hex: "000000").opacity(0.7) : Color(hex: "000000").opacity(0.4) }
    static var bgPaneFocused: Color { dark ? Color(hex: "0d0d0d") : Color(hex: "f8f8f8") }
    static var dividerColor: Color { dark ? Color(hex: "2a2a2a") : Color(hex: "d0d0d0") }
    static var paneBorderActive: Color { accent.opacity(0.5) }
    static var paneBorderInactive: Color { border.opacity(0.3) }

    // NSColor 변환 (SwiftTerm용)
    static var resolvedBgTerminalNSColor: NSColor {
        if let config = cachedCustomConfig, let hex = config.bgHex, !hex.isEmpty {
            return NSColor(hex: hex)
        }
        return dark ? NSColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1) : NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
    }

    static var resolvedFgTerminalNSColor: NSColor {
        if let config = cachedCustomConfig, let hex = config.textPrimaryHex, !hex.isEmpty {
            return NSColor(hex: hex)
        }
        return dark ? NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1) : NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    }

    // ── Borders (single-weight system: always 1px, vary opacity) ──
    static var border: Color {
        if let config = cachedCustomConfig, let hex = config.borderHex, !hex.isEmpty { return cachedColor("bd_\(hex)", hex) }
        return cachedColor(dark ? "bd_d" : "bd_l", dark ? "282828" : "e5e5e5")
    }
    static var borderStrong: Color {
        if let config = cachedCustomConfig, let hex = config.borderStrongHex, !hex.isEmpty { return cachedColor("bds_\(hex)", hex) }
        return cachedColor(dark ? "bds_d" : "bds_l", dark ? "3e3e3e" : "d0d0d0")
    }
    static var borderActive: Color { cachedColor(dark ? "bda_d" : "bda_l", dark ? "555555" : "999999") }
    static var borderSubtle: Color { cachedColor(dark ? "bdsb_d" : "bdsb_l", dark ? "1e1e1e" : "eeeeee") }
    static var focusRing: Color { Color(hex: "0070f3").opacity(0.5) }

    // ── Text (5-step hierarchy) ──
    static var textPrimary: Color {
        if let config = cachedCustomConfig, let hex = config.textPrimaryHex, !hex.isEmpty { return cachedColor("tp_\(hex)", hex) }
        return cachedColor(dark ? "tp_d" : "tp_l", dark ? "ededed" : "171717")
    }
    static var textSecondary: Color {
        if let config = cachedCustomConfig, let hex = config.textSecondaryHex, !hex.isEmpty { return cachedColor("ts_\(hex)", hex) }
        return cachedColor(dark ? "ts_d" : "ts_l", dark ? "a1a1a1" : "636363")
    }
    static var textDim: Color {
        if let config = cachedCustomConfig, let hex = config.textDimHex, !hex.isEmpty { return cachedColor("td_\(hex)", hex) }
        return cachedColor(dark ? "td_d" : "td_l", dark ? "707070" : "8f8f8f")
    }
    static var textMuted: Color {
        if let config = cachedCustomConfig, let hex = config.textMutedHex, !hex.isEmpty { return cachedColor("tm_\(hex)", hex) }
        return cachedColor(dark ? "tm_d" : "tm_l", dark ? "484848" : "b0b0b0")
    }
    static var textTerminal: Color { dark ? Color(hex: "ededed") : Color(hex: "171717") }

    // ── System ──
    static var textOnAccent: Color {
        if let config = cachedCustomConfig, config.accentHex != nil {
            return accent.contrastingTextColor
        }
        return .white
    }
    static var overlay: Color { dark ? .white : .black }
    static var overlayBg: Color { dark ? .black : .white }

    // ── Semantic Accents ──
    static var accent: Color {
        if let config = cachedCustomConfig, let hex = config.accentHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return dark ? Color(hex: "3291ff") : Color(hex: "0070f3")
    }
    static var green: Color {
        if let config = cachedCustomConfig, let hex = config.greenHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "3ecf8e") : Color(hex: "18a058")
    }
    static var red: Color {
        if let config = cachedCustomConfig, let hex = config.redHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "f14c4c") : Color(hex: "e5484d")
    }
    static var yellow: Color {
        if let config = cachedCustomConfig, let hex = config.yellowHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "f5a623") : Color(hex: "ca8a04")
    }
    static var purple: Color {
        if let config = cachedCustomConfig, let hex = config.purpleHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf")
    }
    static var orange: Color {
        if let config = cachedCustomConfig, let hex = config.orangeHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "f97316") : Color(hex: "e5560a")
    }
    static var cyan: Color {
        if let config = cachedCustomConfig, let hex = config.cyanHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "06b6d4") : Color(hex: "0891b2")
    }
    static var pink: Color {
        if let config = cachedCustomConfig, let hex = config.pinkHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "e54d9e") : Color(hex: "d23197")
    }

    // ── Semantic accent backgrounds (soft fills for badges/indicators) ──
    static func accentBg(_ color: Color) -> Color { color.opacity(dark ? 0.12 : 0.08) }
    static func accentBorder(_ color: Color) -> Color { color.opacity(dark ? 0.25 : 0.2) }

    /// 그라데이션 또는 단색 accent 배경 (AnyShapeStyle) — Custom 모드에서만 그라데이션 적용
    static var accentBackground: AnyShapeStyle {
        if let config = cachedCustomConfig {
            if config.useGradient,
               let startHex = config.gradientStartHex, !startHex.isEmpty,
               let endHex = config.gradientEndHex, !endHex.isEmpty {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(hex: startHex), Color(hex: endHex)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            }
        }
        return AnyShapeStyle(accent)
    }

    /// 소프트 그라데이션 배경 (낮은 opacity) — 비 prominent accent 버튼 등에 사용
    static var accentSoftBackground: AnyShapeStyle {
        if let config = cachedCustomConfig {
            if config.useGradient,
               let startHex = config.gradientStartHex, !startHex.isEmpty,
               let endHex = config.gradientEndHex, !endHex.isEmpty {
                let opacity = dark ? 0.14 : 0.10
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(hex: startHex).opacity(opacity), Color(hex: endHex).opacity(opacity)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            }
        }
        return AnyShapeStyle(accentBg(accent))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 2. TYPOGRAPHY SYSTEM
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //
    // UI text: system sans-serif (.default)
    // Code/terminal/git hash: monospaced (.monospaced)
    // Pixel world labels: monospaced bold (preserved)
    //
    // Scale hierarchy:
    //   display: 18   title: 14   heading: 12   body: 11
    //   small: 10     micro: 9    tiny: 8

    // Pre-scaled convenience fonts
    static var monoTiny: Font { .system(size: round(8 * scale), design: .monospaced) }
    static var monoSmall: Font { .system(size: round(10 * scale), design: .monospaced) }
    static var monoNormal: Font { .system(size: round(12 * scale), design: .monospaced) }
    static var monoBold: Font { .system(size: round(11 * scale), weight: .semibold, design: .monospaced) }
    static var pixel: Font { .system(size: round(8 * chromeScale), weight: .bold, design: .monospaced) }

    /// 커스텀 테마에서 fontSize가 설정되어 있으면 해당 스케일 사용
    private static var customScale: CGFloat? {
        guard let config = cachedCustomConfig, let fs = config.fontSize, fs > 0 else { return nil }
        return CGFloat(fs / 11.0)
    }

    /// Primary UI text (Geist Sans equivalent — system san-serif)
    static func mono(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        let key = "mono-\(baseSize)-\(weight.hashValue)"
        return cachedFont(key: key) {
            let effectiveScale = customScale ?? scale
            if let config = cachedCustomConfig, let fontName = config.fontName, !fontName.isEmpty {
                return Font.custom(fontName, size: round(baseSize * effectiveScale)).weight(weight)
            }
            return .system(size: round(baseSize * effectiveScale), weight: weight, design: .default)
        }
    }

    /// Code, terminal, git hashes, file paths — 커스텀 폰트 미적용 (항상 monospaced)
    static func code(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        let key = "code-\(baseSize)-\(weight.hashValue)"
        return cachedFont(key: key) {
            .system(size: round(baseSize * scale), weight: weight, design: .monospaced)
        }
    }

    /// General scaled font
    static func scaled(_ baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let key = "scaled-\(baseSize)-\(weight.hashValue)-\(design.hashValue)"
        return cachedFont(key: key) {
            let effectiveScale = customScale ?? scale
            if let config = cachedCustomConfig, let fontName = config.fontName, !fontName.isEmpty, design == .default {
                return Font.custom(fontName, size: round(baseSize * effectiveScale)).weight(weight)
            }
            return .system(size: round(baseSize * effectiveScale), weight: weight, design: design)
        }
    }

    /// Chrome-only font (sidebar, toolbar — less aggressive scaling)
    static func chrome(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        let key = "chrome-\(baseSize)-\(weight.hashValue)"
        return cachedFont(key: key) {
            let effectiveChromeScale: CGFloat = {
                if let cs = customScale { return 1 + (cs - 1) * 0.5 }
                return chromeScale
            }()
            if let config = cachedCustomConfig, let fontName = config.fontName, !fontName.isEmpty {
                return Font.custom(fontName, size: round(baseSize * effectiveChromeScale)).weight(weight)
            }
            return .system(size: round(baseSize * effectiveChromeScale), weight: weight, design: .default)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 3. SPACING & SIZING
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //
    // 4px base grid. All spacing in multiples of 4.
    //
    // Naming: sp1=4, sp2=8, sp3=12, sp4=16, sp5=20, sp6=24, sp8=32

    static let sp1: CGFloat = 4
    static let sp2: CGFloat = 8
    static let sp3: CGFloat = 12
    static let sp4: CGFloat = 16
    static let sp5: CGFloat = 20
    static let sp6: CGFloat = 24
    static let sp8: CGFloat = 32

    // Row heights
    static let rowCompact: CGFloat = 28     // dense list rows, sidebar items
    static let rowDefault: CGFloat = 36     // standard list rows, table rows
    static let rowComfortable: CGFloat = 44 // touch-friendly / spacious rows

    // Panel padding
    static let panelPadding: CGFloat = 16
    static let cardPadding: CGFloat = 12
    static let toolbarHeight: CGFloat = 36
    static let sidebarItemHeight: CGFloat = 30

    // Icon sizes
    static func iconSize(_ baseSize: CGFloat) -> CGFloat { round(baseSize * scale) }
    static func chromeIconSize(_ baseSize: CGFloat) -> CGFloat { round(baseSize * chromeScale) }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 4. RADIUS / BORDER / SURFACE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //
    // Radius: tight and precise, never bubbly
    // Border: always 1px, full color (no opacity tricks)
    // Shadow: none (depth = border + surface color)

    static let cornerSmall: CGFloat = 5     // badges, tags, small chips
    static let cornerMedium: CGFloat = 6    // buttons, inputs, select
    static let cornerLarge: CGFloat = 8     // cards, panels, dialogs
    static let cornerXL: CGFloat = 12       // modals, sheets, large containers

    // Border defaults (for modifier compatibility)
    static let borderDefault: CGFloat = 1.0
    static let borderActiveOpacity: CGFloat = 1.0
    static let borderLight: CGFloat = 0.6

    // Interaction state opacities (consistent across all components)
    static let hoverOpacity: CGFloat = 0.08
    static let activeOpacity: CGFloat = 0.12
    static let strokeActiveOpacity: CGFloat = 0.25
    static let strokeInactiveOpacity: CGFloat = 0.15

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 5. PRESERVED TOKENS (pixel world)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    static var workerColors: [Color] {
        dark ? [
            Color(hex: "ee7878"), Color(hex: "68d498"), Color(hex: "eebb50"),
            Color(hex: "70b0ee"), Color(hex: "c08ce6"), Color(hex: "ee9858"),
            Color(hex: "58ccbb"), Color(hex: "ee78bb")
        ] : [
            Color(hex: "d04848"), Color(hex: "259248"), Color(hex: "b88000"),
            Color(hex: "2260d0"), Color(hex: "6a40d0"), Color(hex: "c86020"),
            Color(hex: "0a8888"), Color(hex: "c84080")
        ]
    }

    static var bgGradient: LinearGradient {
        dark ? LinearGradient(colors: [Color(hex: "000000"), Color(hex: "0a0a0a")], startPoint: .top, endPoint: .bottom)
             : LinearGradient(colors: [Color(hex: "ffffff"), Color(hex: "fafafa")], startPoint: .top, endPoint: .bottom)
    }
}

enum AppChromeTone: Equatable {
    case neutral
    case accent
    case green
    case red
    case yellow
    case purple
    case cyan
    case orange

    var color: Color {
        switch self {
        case .neutral: return Theme.textSecondary
        case .accent: return Theme.accent
        case .green: return Theme.green
        case .red: return Theme.red
        case .yellow: return Theme.yellow
        case .purple: return Theme.purple
        case .cyan: return Theme.cyan
        case .orange: return Theme.orange
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 도피스 컴포넌트 시스템 (Vercel-grade)
//
// 원칙:
// - 그림자 없음. depth = surface color + border
// - 보더는 항상 1px, Theme.border 사용
// - 배경은 surface 계층으로만 표현
// - prominent 버튼만 채색, 나머지는 border-only
// - hover/selected/pressed는 bgHover/bgSelected/bgPressed 사용
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// MARK: - Panel Modifier (카드, 섹션, 패널)

private struct AppPanelModifier: ViewModifier {
    let padding: CGFloat
    let radius: CGFloat
    let fill: Color
    let strokeOpacity: Double  // kept for API compat, border uses Theme.border
    let shadow: Bool           // ignored — no shadows in this system

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - Field Modifier (텍스트 입력, 셀렉트)

private struct AppFieldModifier: ViewModifier {
    let emphasized: Bool
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp2)
            .background(RoundedRectangle(cornerRadius: radius).fill(Theme.bgInput))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(emphasized ? Theme.accent : Theme.border, lineWidth: 1))
    }
}

// MARK: - Button Surface Modifier

private struct AppButtonSurfaceModifier: ViewModifier {
    let tone: AppChromeTone
    let prominent: Bool
    let compact: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let tint = tone.color
        let r: CGFloat = Theme.cornerMedium
        let bgFill: AnyShapeStyle = {
            if prominent {
                return tone == .accent ? Theme.accentBackground : AnyShapeStyle(tint)
            }
            return tone == .neutral ? AnyShapeStyle(Color.clear) :
                   (tone == .accent ? Theme.accentSoftBackground : AnyShapeStyle(Theme.accentBg(tint)))
        }()
        let base = content
            .padding(.horizontal, compact ? Theme.sp2 : Theme.sp3)
            .padding(.vertical, compact ? Theme.sp1 + 1 : Theme.sp2 - 1)
            .background(RoundedRectangle(cornerRadius: r).fill(bgFill))
            .overlay(RoundedRectangle(cornerRadius: r).stroke(prominent ? tint.opacity(0.2) : Theme.border, lineWidth: 1))

        // 구체 타입으로 foreground 적용 — AnyShapeStyle 타입 소거는 macOS 버튼에서 전파 안 됨
        // 스레드 안전: cachedCustomConfig 스냅샷 사용 (AppSettings 직접 접근 X)
        let ct = Theme.cachedCustomConfig
        if !prominent, tone == .accent, Theme.isCustomMode,
           let config = ct, config.useGradient,
           let s = config.gradientStartHex, !s.isEmpty,
           let e = config.gradientEndHex, !e.isEmpty {
            base.foregroundStyle(
                LinearGradient(colors: [Color(hex: s), Color(hex: e)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        } else if prominent {
            base.foregroundColor(Theme.textOnAccent)
        } else if tone == .neutral {
            base.foregroundColor(Theme.textSecondary)
        } else if tone == .accent {
            base.foregroundColor(Theme.accent)
        } else {
            base.foregroundColor(tint)
        }
    }
}

// MARK: - View Extensions

extension View {
    func appPanelStyle(
        padding: CGFloat = Theme.panelPadding,
        radius: CGFloat = Theme.cornerLarge,
        fill: Color = Theme.bgCard,
        strokeOpacity: Double = Theme.borderDefault,
        shadow: Bool = false
    ) -> some View {
        modifier(AppPanelModifier(padding: padding, radius: radius, fill: fill, strokeOpacity: strokeOpacity, shadow: shadow))
    }

    func appFieldStyle(emphasized: Bool = false, radius: CGFloat = CGFloat(Theme.cornerMedium)) -> some View {
        modifier(AppFieldModifier(emphasized: emphasized, radius: radius))
    }

    func appButtonSurface(
        tone: AppChromeTone = .neutral,
        prominent: Bool = false,
        compact: Bool = false
    ) -> some View {
        modifier(AppButtonSurfaceModifier(tone: tone, prominent: prominent, compact: compact))
    }

    /// Vercel-style divider (subtle horizontal line)
    func appDivider() -> some View {
        self.overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// Sidebar hover highlight
    func sidebarRowStyle(isSelected: Bool = false, isHovered: Bool = false) -> some View {
        self
            .padding(.horizontal, Theme.sp2)
            .padding(.vertical, Theme.sp1 + 1)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(isSelected ? Theme.bgSelected : (isHovered ? Theme.bgHover : .clear))
            )
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Color hex init
// ═══════════════════════════════════════════════════════

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        // Expand 3-character shorthand (e.g. "fff" -> "ffffff")
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else {
            // Fallback to magenta for debug visibility on invalid hex
            self.init(.sRGB, red: 1, green: 0, blue: 1)
            return
        }
        let r = int >> 16
        let g = int >> 8 & 0xFF
        let b = int & 0xFF
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// Color → 6자리 hex 문자열 (# 없음)
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    /// W3C 상대 휘도 (0 = 검정, 1 = 흰색)
    var luminance: Double {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linearize(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    /// 배경색 위 텍스트 가독성을 위한 자동 대비 색상
    var contrastingTextColor: Color {
        luminance > 0.179 ? .black : .white
    }
}

extension NSColor {
    convenience init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else {
            self.init(red: 1, green: 0, blue: 1, alpha: 1)
            return
        }
        let r = CGFloat(int >> 16) / 255
        let g = CGFloat(int >> 8 & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
