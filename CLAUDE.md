# Doffice (도피스)

macOS 네이티브 앱. AI 코딩 어시스턴트(Claude Code, Codex, Gemini CLI)를 픽셀아트 오피스에서 관리하는 비주얼 워크스페이스.

## Quick Reference

```bash
# 빌드 & 실행 (Tuist + mise 필요)
make dofi              # clean → generate → build → open

# 개별 단계
make generate          # Tuist 프로젝트 생성
make build-app         # xcodebuild
make open-app          # 빌드된 앱 실행

# 테스트
./Scripts/smoke-test.sh   # 4단계 전체 테스트 파이프라인
xcodebuild test -workspace Doffice.xcworkspace -scheme DesignSystem -destination 'platform=macOS'
xcodebuild test -workspace Doffice.xcworkspace -scheme DofficeKit -destination 'platform=macOS'
```

## Project Structure

```
Projects/
├── App/               # 메인 앱 (Tuist modular)
│   └── Sources/       # DofficeApp.swift, MainView.swift, ...
├── DofficeKit/        # 핵심 프레임워크 (비즈니스 로직)
│   ├── Sources/       # SessionManager, Models, AuditLog, CrashLogger, ...
│   └── Tests/         # Unit tests
└── DesignSystem/      # UI 컴포넌트, 테마, 토큰
    ├── Sources/       # Theme, Colors, Typography, Notifications
    ├── CatalogSources/ # 프리뷰 카탈로그 앱
    └── Tests/

Doffice/               # DEPRECATED — 수정하지 마세요. 모든 개발은 Projects/에서 진행.
```

## Module Dependencies

```
App → DofficeKit → DesignSystem
                → SwiftTerm (1.12.0)
                → OrderedCollections (swift-collections 1.4.1)
```

## Key Singletons

- `SessionManager.shared` — 탭/세션 생명주기
- `SessionStore.shared` — 세션 JSON 영속화 (`~/Library/Application Support/Doffice/sessions.json`)
- `AuditLog.shared` — 감사 이벤트 (최대 5000건)
- `CrashLogger.shared` — 파일 로그 (`~/Library/Logs/Doffice/`)
- `AppSettings.shared` — UserDefaults 래퍼
- `ShortcutManager.shared` — 동적 키보드 단축키

## Error Handling Conventions

- `fatalError()`, `try!`, `as!` 사용 금지 — 전부 optional binding 또는 do-catch
- 크래시 시그널: SIGTERM/SIGINT/SIGHUP (graceful) + SIGABRT/SIGBUS/SIGSEGV (fatal logging)
- 파일 I/O 실패 시 임시 디렉토리 fallback
- 크래시/에러 시 `CrashLogger.shared`에 기록

## Build Requirements

- macOS 14.0+ (Sonoma)
- Xcode 16.x (Swift 6.1)
- Tuist 4.x (`mise exec` 으로 관리)
- Bundle ID: `com.junha.doffice`

## CI/CD

- GitHub Actions: `.github/workflows/build.yml`
- Runner: macos-15
- 자동 릴리스: 버전 태그 push 시
