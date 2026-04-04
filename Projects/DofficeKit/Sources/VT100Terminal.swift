import Foundation
import AppKit

// ═══════════════════════════════════════════════════════
// MARK: - VT100 Terminal Emulator
// ═══════════════════════════════════════════════════════

/// 실제 터미널 에뮬레이터: 2D 문자 버퍼 + 커서 + ANSI/CSI 시퀀스 처리
public class VT100Terminal: ObservableObject {
    public struct Cell {
        public var char: Character = " "
        public var fg: Int = 37       // 기본 흰색
        public var bg: Int = 0        // 기본 배경
        public var bold: Bool = false
        public var dim: Bool = false
    }

    @Published public var needsRedraw: Int = 0

    public private(set) var rows: Int
    public private(set) var cols: Int
    private var buffer: [[Cell]]
    private var cursorRow: Int = 0
    private var cursorCol: Int = 0
    private var savedCursorRow: Int = 0
    private var savedCursorCol: Int = 0

    // SGR 상태
    private var currentFg: Int = 37
    private var currentBg: Int = 0
    private var currentBold: Bool = false
    private var currentDim: Bool = false

    // 파서 상태
    private enum ParseState {
        case normal
        case escape       // ESC 받음
        case csi          // ESC[ 받음
        case osc          // ESC] 받음
        case oscEsc       // OSC 안에서 ESC 받음
    }
    private var parseState: ParseState = .normal
    private var csiParams: String = ""
    private var oscBuffer: String = ""

    // 스크롤백 버퍼
    private var scrollback: [[Cell]] = []
    public var maxScrollback: Int = 5000

    public init(rows: Int = 50, cols: Int = 120) {
        self.rows = rows
        self.cols = cols
        self.buffer = Array(repeating: Array(repeating: Cell(), count: cols), count: rows)
    }

    public func resize(rows: Int, cols: Int) {
        guard rows > 0, cols > 0, (rows != self.rows || cols != self.cols) else { return }
        var newBuffer = Array(repeating: Array(repeating: Cell(), count: cols), count: rows)
        let copyRows = min(self.rows, rows)
        let copyCols = min(self.cols, cols)
        for r in 0..<copyRows {
            for c in 0..<copyCols {
                newBuffer[r][c] = buffer[r][c]
            }
        }
        self.rows = rows
        self.cols = cols
        self.buffer = newBuffer
        cursorRow = min(cursorRow, rows - 1)
        cursorCol = min(cursorCol, cols - 1)
    }

    // MARK: - 데이터 입력 (PTY에서 읽은 바이트)

    public func feed(_ text: String) {
        for ch in text {
            processChar(ch)
        }
        needsRedraw += 1
    }

    private func processChar(_ ch: Character) {
        switch parseState {
        case .normal:
            switch ch {
            case "\u{1B}": // ESC
                parseState = .escape
            case "\n": // LF
                lineFeed()
            case "\r": // CR
                cursorCol = 0
            case "\t": // Tab
                let nextTab = ((cursorCol / 8) + 1) * 8
                cursorCol = min(nextTab, cols - 1)
            case "\u{08}": // Backspace
                if cursorCol > 0 { cursorCol -= 1 }
            case "\u{07}": // BEL - 무시
                break
            default:
                if ch.asciiValue ?? 32 >= 32 { // 출력 가능 문자만
                    putChar(ch)
                }
            }

        case .escape:
            switch ch {
            case "[":
                parseState = .csi
                csiParams = ""
            case "]":
                parseState = .osc
                oscBuffer = ""
            case "7", "s": // DECSC - 커서 저장
                savedCursorRow = cursorRow
                savedCursorCol = cursorCol
                parseState = .normal
            case "8", "u": // DECRC - 커서 복원
                cursorRow = savedCursorRow
                cursorCol = savedCursorCol
                parseState = .normal
            case "M": // RI - 역방향 줄바꿈
                if cursorRow > 0 { cursorRow -= 1 } else { scrollDown() }
                parseState = .normal
            case "c": // RIS - 전체 리셋
                resetTerminal()
                parseState = .normal
            case "D": // IND
                lineFeed()
                parseState = .normal
            case "E": // NEL
                cursorCol = 0
                lineFeed()
                parseState = .normal
            case "(", ")", "*", "+": // 문자셋 지정 - 다음 1바이트 스킵 필요하지만 단순 무시
                parseState = .normal
            default:
                parseState = .normal
            }

        case .csi:
            if ch >= "\u{40}" && ch <= "\u{7E}" {
                // CSI 최종 바이트
                handleCSI(params: csiParams, final: ch)
                parseState = .normal
            } else if csiParams.count < 256 {
                csiParams.append(ch)
            } else {
                // 비정상적으로 긴 CSI 시퀀스 — 파서 리셋
                csiParams = ""
                parseState = .normal
            }

        case .osc:
            if ch == "\u{07}" { // BEL로 종료
                parseState = .normal
            } else if ch == "\u{1B}" {
                parseState = .oscEsc
            } else if oscBuffer.count < 4096 {
                oscBuffer.append(ch)
            } else {
                // 비정상적으로 긴 OSC 시퀀스 — 파서 리셋
                oscBuffer = ""
                parseState = .normal
            }

        case .oscEsc:
            if ch == "\\" { // ST (ESC \)로 종료
                parseState = .normal
            } else {
                parseState = .normal
            }
        }
    }

    // MARK: - 문자 출력

    private func putChar(_ ch: Character) {
        if cursorCol >= cols {
            cursorCol = 0
            lineFeed()
        }
        guard cursorRow >= 0 && cursorRow < buffer.count else { return }
        guard cursorCol >= 0 && cursorCol < buffer[cursorRow].count else { return }
        buffer[cursorRow][cursorCol] = Cell(
            char: ch, fg: currentFg, bg: currentBg,
            bold: currentBold, dim: currentDim
        )
        cursorCol += 1
    }

    private func lineFeed() {
        if cursorRow < rows - 1 {
            cursorRow += 1
        } else {
            scrollUp()
        }
    }

    private func scrollUp() {
        guard rows > 0 && buffer.count >= rows else { return }
        // 첫 줄을 스크롤백에 저장
        if scrollback.count >= maxScrollback { scrollback.removeFirst() }
        scrollback.append(buffer[0])
        // 나머지 줄을 위로 이동
        for r in 0..<(rows - 1) {
            buffer[r] = buffer[r + 1]
        }
        buffer[rows - 1] = Array(repeating: Cell(), count: cols)
    }

    private func scrollDown() {
        guard rows > 0 && buffer.count >= rows else { return }
        for r in stride(from: rows - 1, through: 1, by: -1) {
            buffer[r] = buffer[r - 1]
        }
        buffer[0] = Array(repeating: Cell(), count: cols)
    }

    // MARK: - CSI 시퀀스 처리

    private func handleCSI(params: String, final: Character) {
        let parts = params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) }
        let p1 = parts.first.flatMap { $0 } ?? 0

        switch final {
        case "m": // SGR - 색상/스타일
            handleSGR(parts)

        case "A": // 커서 위로
            cursorRow = max(0, cursorRow - max(1, p1))
        case "B": // 커서 아래로
            cursorRow = min(rows - 1, cursorRow + max(1, p1))
        case "C": // 커서 오른쪽
            cursorCol = min(cols - 1, cursorCol + max(1, p1))
        case "D": // 커서 왼쪽
            cursorCol = max(0, cursorCol - max(1, p1))
        case "E": // 커서 N줄 아래 첫 열
            cursorRow = min(rows - 1, cursorRow + max(1, p1))
            cursorCol = 0
        case "F": // 커서 N줄 위 첫 열
            cursorRow = max(0, cursorRow - max(1, p1))
            cursorCol = 0
        case "G": // 커서 열 이동
            cursorCol = min(cols - 1, max(0, max(1, p1) - 1))
        case "H", "f": // 커서 위치 설정
            let row = (parts.count >= 1 ? (parts[0] ?? 1) : 1)
            let col = (parts.count >= 2 ? (parts[1] ?? 1) : 1)
            cursorRow = min(rows - 1, max(0, row - 1))
            cursorCol = min(cols - 1, max(0, col - 1))

        case "J": // 화면 지우기
            guard cursorRow >= 0 && cursorRow < buffer.count else { break }
            switch p1 {
            case 0: // 커서부터 끝
                for c in cursorCol..<cols {
                    guard c >= 0 && c < buffer[cursorRow].count else { continue }
                    buffer[cursorRow][c] = Cell()
                }
                for r in (cursorRow + 1)..<rows {
                    guard r >= 0 && r < buffer.count else { continue }
                    buffer[r] = Array(repeating: Cell(), count: cols)
                }
            case 1: // 처음부터 커서
                for r in 0..<cursorRow {
                    guard r >= 0 && r < buffer.count else { continue }
                    buffer[r] = Array(repeating: Cell(), count: cols)
                }
                if !buffer[cursorRow].isEmpty {
                    for c in 0...min(cursorCol, buffer[cursorRow].count - 1) {
                        buffer[cursorRow][c] = Cell()
                    }
                }
            case 2, 3: // 전체 화면
                for r in 0..<rows {
                    guard r >= 0 && r < buffer.count else { continue }
                    buffer[r] = Array(repeating: Cell(), count: cols)
                }
                cursorRow = 0
                cursorCol = 0
            default: break
            }

        case "K": // 줄 지우기
            guard cursorRow >= 0 && cursorRow < buffer.count else { break }
            switch p1 {
            case 0: // 커서부터 줄 끝
                for c in cursorCol..<cols {
                    guard c >= 0 && c < buffer[cursorRow].count else { continue }
                    buffer[cursorRow][c] = Cell()
                }
            case 1: // 줄 처음부터 커서
                for c in 0...min(cursorCol, cols - 1) {
                    guard c >= 0 && c < buffer[cursorRow].count else { continue }
                    buffer[cursorRow][c] = Cell()
                }
            case 2: // 줄 전체
                buffer[cursorRow] = Array(repeating: Cell(), count: cols)
            default: break
            }

        case "L": // 줄 삽입
            let n = max(1, p1)
            for _ in 0..<n {
                guard rows > 0 && rows - 1 < buffer.count else { break }
                guard cursorRow >= 0 && cursorRow < buffer.count else { break }
                if cursorRow < rows - 1 {
                    buffer.remove(at: rows - 1)
                    buffer.insert(Array(repeating: Cell(), count: cols), at: cursorRow)
                }
            }

        case "M": // 줄 삭제
            let n = max(1, p1)
            for _ in 0..<n {
                guard cursorRow >= 0 && cursorRow < buffer.count else { break }
                if cursorRow < rows {
                    buffer.remove(at: cursorRow)
                    buffer.append(Array(repeating: Cell(), count: cols))
                }
            }

        case "P": // 문자 삭제
            guard cursorRow >= 0 && cursorRow < buffer.count else { break }
            let rowCount = buffer[cursorRow].count
            guard cursorCol >= 0 && cursorCol < rowCount else { break }
            let available = rowCount - cursorCol
            let n = min(max(1, p1), available)
            guard n > 0 else { break }
            buffer[cursorRow].removeSubrange(cursorCol..<(cursorCol + n))
            buffer[cursorRow].append(contentsOf: Array(repeating: Cell(), count: n))

        case "d": // 커서 행 이동 (절대)
            cursorRow = min(rows - 1, max(0, max(1, p1) - 1))

        case "h", "l": // 모드 설정/해제 (대부분 무시)
            break

        case "r": // 스크롤 영역 설정 (무시)
            break

        case "s": // 커서 저장
            savedCursorRow = cursorRow
            savedCursorCol = cursorCol
        case "u": // 커서 복원
            cursorRow = savedCursorRow
            cursorCol = savedCursorCol

        case "@": // 빈 문자 삽입
            guard cursorRow >= 0 && cursorRow < buffer.count else { break }
            guard cursorCol >= 0 && cursorCol <= buffer[cursorRow].count else { break }
            let n = min(max(1, p1), cols - cursorCol)
            for _ in 0..<n {
                buffer[cursorRow].insert(Cell(), at: cursorCol)
            }
            buffer[cursorRow] = Array(buffer[cursorRow].prefix(cols))

        default:
            break
        }
    }

    // MARK: - SGR (색상/스타일)

    private func handleSGR(_ parts: [Int?]) {
        let codes = parts.map { $0 ?? 0 }
        let effectiveCodes = codes.isEmpty ? [0] : codes
        var i = 0
        while i < effectiveCodes.count {
            let code = effectiveCodes[i]
            switch code {
            case 0:
                currentFg = 37; currentBg = 0; currentBold = false; currentDim = false
            case 1: currentBold = true
            case 2: currentDim = true
            case 22: currentBold = false; currentDim = false
            case 30...37: currentFg = code
            case 38: // 확장 색상
                if i + 1 < effectiveCodes.count && effectiveCodes[i + 1] == 5 && i + 2 < effectiveCodes.count {
                    currentFg = 1000 + effectiveCodes[i + 2] // 256색 마커
                    i += 2
                }
            case 39: currentFg = 37
            case 40...47: currentBg = code
            case 48: // 확장 배경색
                if i + 1 < effectiveCodes.count && effectiveCodes[i + 1] == 5 && i + 2 < effectiveCodes.count {
                    currentBg = 1000 + effectiveCodes[i + 2]
                    i += 2
                }
            case 49: currentBg = 0
            case 90...97: currentFg = code
            case 100...107: currentBg = code
            default: break
            }
            i += 1
        }
    }

    private func resetTerminal() {
        buffer = Array(repeating: Array(repeating: Cell(), count: cols), count: rows)
        cursorRow = 0; cursorCol = 0
        currentFg = 37; currentBg = 0; currentBold = false; currentDim = false
        scrollback.removeAll()
    }

    // MARK: - 렌더링

    public static let colorTable: [Int: NSColor] = [
        30: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1),
        31: NSColor(red: 0.9,  green: 0.3,  blue: 0.3,  alpha: 1),
        32: NSColor(red: 0.3,  green: 0.85, blue: 0.4,  alpha: 1),
        33: NSColor(red: 0.9,  green: 0.8,  blue: 0.3,  alpha: 1),
        34: NSColor(red: 0.4,  green: 0.5,  blue: 0.9,  alpha: 1),
        35: NSColor(red: 0.8,  green: 0.4,  blue: 0.8,  alpha: 1),
        36: NSColor(red: 0.3,  green: 0.8,  blue: 0.85, alpha: 1),
        37: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
        90: NSColor(red: 0.5,  green: 0.5,  blue: 0.5,  alpha: 1),
        91: NSColor(red: 1.0,  green: 0.4,  blue: 0.4,  alpha: 1),
        92: NSColor(red: 0.4,  green: 1.0,  blue: 0.5,  alpha: 1),
        93: NSColor(red: 1.0,  green: 0.9,  blue: 0.4,  alpha: 1),
        94: NSColor(red: 0.5,  green: 0.6,  blue: 1.0,  alpha: 1),
        95: NSColor(red: 0.9,  green: 0.5,  blue: 0.9,  alpha: 1),
        96: NSColor(red: 0.4,  green: 0.9,  blue: 1.0,  alpha: 1),
        97: NSColor.white,
    ]

    public func fgColor(_ fg: Int) -> NSColor {
        Self.colorTable[fg] ?? NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
    }

    /// 전체 화면을 NSAttributedString으로 렌더링 (스크롤백 최근 일부만 포함)
    public func render(fontSize: CGFloat, maxScrollbackLines: Int = 200) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let defaultFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        // 스크롤백 렌더링 — 메모리 절약을 위해 최근 N줄만
        let scrollbackStart = max(0, scrollback.count - maxScrollbackLines)
        for i in scrollbackStart..<scrollback.count {
            appendRow(scrollback[i], to: result, defaultFont: defaultFont, boldFont: boldFont)
            result.append(NSAttributedString(string: "\n"))
        }

        // 현재 화면 렌더링
        for r in 0..<rows {
            guard r < buffer.count else { break }
            if r > 0 { result.append(NSAttributedString(string: "\n")) }
            appendRow(buffer[r], to: result, defaultFont: defaultFont, boldFont: boldFont)
        }

        return result
    }

    private func appendRow(_ row: [Cell], to result: NSMutableAttributedString,
                           defaultFont: NSFont, boldFont: NSFont) {
        // 줄 끝 공백 제거
        var lastNonSpace = -1
        for c in stride(from: row.count - 1, through: 0, by: -1) {
            if row[c].char != " " || row[c].bg != 0 { lastNonSpace = c; break }
        }

        guard lastNonSpace >= 0 else { return }

        var runStart = 0
        while runStart <= lastNonSpace {
            let ref = row[runStart]
            var runEnd = runStart
            // 같은 스타일인 연속 셀을 모음
            while runEnd < lastNonSpace &&
                  row[runEnd + 1].fg == ref.fg && row[runEnd + 1].bg == ref.bg &&
                  row[runEnd + 1].bold == ref.bold && row[runEnd + 1].dim == ref.dim {
                runEnd += 1
            }

            let text = String(row[runStart...runEnd].map { $0.char })
            let font = ref.bold ? boldFont : defaultFont
            var color = fgColor(ref.fg)
            if ref.dim { color = color.withAlphaComponent(0.6) }

            result.append(NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color,
            ]))

            runStart = runEnd + 1
        }
    }
}
