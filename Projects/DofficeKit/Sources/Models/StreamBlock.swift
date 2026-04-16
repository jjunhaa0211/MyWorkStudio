import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Stream Event Architecture
// ═══════════════════════════════════════════════════════

/// 실시간 이벤트 블록 - 각 블록은 UI에서 독립적으로 렌더링됨
public struct StreamBlock: Identifiable {
    public enum PresentationStyle: String, Equatable {
        case normal
        case secret
    }

    public let id = UUID()
    public let timestamp = Date()
    public let blockType: BlockType
    public var content: String = ""
    public var isComplete: Bool = false
    public var isError: Bool = false
    public var exitCode: Int?
    public var presentationStyle: PresentationStyle = .normal
    public var imageURLs: [URL] = []

    public enum BlockType: Equatable {
        case sessionStart(model: String, sessionId: String)
        case thought                    // 💭 AI 사고 텍스트
        case toolUse(name: String, input: String) // ⏺ 도구 실행 (Bash, Read, Edit 등)
        case toolOutput                 // ⎿ 도구 결과 (stdout)
        case toolError                  // ✗ 도구 에러 (stderr)
        case toolEnd(success: Bool)     // 도구 완료
        case text                       // 일반 텍스트 응답
        case fileChange(path: String, action: String) // 파일 변경
        case status(message: String)    // 상태 메시지
        case completion(cost: Double?, duration: Int?) // 완료
        case error(message: String)     // 에러
        case userPrompt                 // 사용자 입력
    }

    public init(type: BlockType, content: String = "", presentationStyle: PresentationStyle = .normal) {
        self.blockType = type
        self.content = content
        self.presentationStyle = presentationStyle
    }

    public mutating func append(_ text: String) {
        content += text
    }
}
