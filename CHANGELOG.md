# Changelog

All notable changes to Doffice are documented here.

## [0.0.57] - 2026-04-16

### Added
- 채팅 내 이미지 미리보기: 사용자가 이미지를 첨부하면 메시지 스트림에 100x100 썸네일로 표시
- 사용량/쿼터 표시: ActionCenter에서 Claude 실제 플랜 사용량 + 로컬 토큰 추적 프로그래스 바
- 템플릿 일괄 끄기: 설정에서 모든 프롬프트 자동 주입을 한 번에 비활성화하는 마스터 토글
- UsageSummaryView: Claude/GPT/Gemini 사용량을 한 곳에서 확인 (ClaudeUsageFetcher 비동기 래퍼 포함)

### Improved
- 자동 업데이트: exit(0) 제거 → NSApplication.terminate로 정상 종료, 코드서명/번들/디스크 검증 추가
- 메시지 안정성: UTF-8 실패 시 Latin-1 폴백, JSON 파싱 에러 로깅, 1MB 버퍼 오버플로 복구 개선
- ClaudeUsageFetcher: 부팅 타임아웃 8초→5초, 폴링 간격 개선, 구조화된 UsageData 타입 추가
- 텔레그램풍 UI: 메시지 등장 애니메이션, 웨이브 도트 인디케이터, 호버 효과, 입력바 그림자

### Fixed
- toolUseContexts/seenToolUseIds 무한 증가 → 500/1000개 크기 제한 및 자동 트리밍
- appendBlock에서 trimTimelineIfNeeded 호출 누락 → timeline 무한 증가 방지
- API 키가 플러그인 프로세스에 노출되던 문제 → sanitizedPluginEnvironment()로 민감 키 필터링
- 플러그인 스크립트 경로 검증 없이 실행되던 문제 → 플러그인 디렉토리 내 경로만 허용
- SessionStore/CrashLogger 파일 퍼미션 미설정 → 디렉토리 0o700, 파일 0o600 적용
- @StateObject로 싱글톤(AppSettings.shared) 참조하던 13개 파일 → @ObservedObject로 수정
- UpdateChecker sleep/wake 옵저버 누수 → 참조 저장 및 deinit에서 제거
- MarkdownTextView 대용량 텍스트 UI 프리징 → 30,000자 초과 시 자동 truncation

## [0.0.56] - 2026-04-09

### Fixed
- Release CI no longer fails on localization drift caused by missing legacy `session.auto.hire` strings
- Homebrew tap workflow now skips cleanly with a warning when `HOMEBREW_TAP_TOKEN` is not configured
- Legacy `Doffice` localization files are back in sync with `Projects/App`

## [0.0.52] - 2026-04-08

### Added
- Plugin character filter button in character collection view
- Plugin character badges: 바캉스(cyan), 배그(red) per pack
- Plugin furniture rendering and placement in modular build
- Character tap in office shows action menu popover

### Fixed
- Plugin characters not loading (invalid enum values in characters.json)
- Plugin validation rejecting effects/furniture-only packs
- All bundled plugin data uses valid HatType/Accessory/Species values
- Enum fallback decoding: unknown values map gracefully instead of crash

### Changed
- Remove typing-combo-pack
- Max hired characters raised from 12 to 30

## [0.0.51] - 2026-04-08

### Fixed
- Plugin registry install: manifest-based download now fetches all related files
- Character hiring: raise max from 12 to 30, show achievement requirement notice
- Auto-update: launch binary directly instead of through LaunchServices
- /usage command: fix infinite "조회 중" hang, faster PTY startup detection

## [0.0.50] - 2026-04-08

### Added
- Localization key sync verification script (`Scripts/l10n-check.sh`) + CI step
- Code signing and notarization pipeline in CI
- Design system catalog: Modifiers, Extensions, Notifications sections (34 → 37)
- DSIconButton and DSButtonGroup demos in ButtonsCatalog

### Changed
- Sync-check improved: sums extension files, ±15% tolerance (9 drift → 4)
- Remove Tuist-generated xcodeproj/xcworkspace from git (-3,296 lines)
- Bump SwiftTerm to 1.13.0, actions/checkout to v6, action-gh-release to v2
- Sync 73 missing localization keys across en/ko/ja (both source trees)

### Fixed
- Homebrew cask app name: DofficeApp.app → Doffice.app

## [0.0.49] - 2026-04-07

### Added
- Custom license requiring author attribution and permission
- CI source sync check (`Scripts/sync-check.sh`) for Projects/ and Doffice/ parity
- Dependabot for Swift packages and GitHub Actions auto-update
- 7 legacy test files synced from DofficeKit (2 to 9 test files)
- Design system catalog: Modifiers, Extensions, Notifications sections
- DSIconButton and DSButtonGroup demos in catalog
- MIT LICENSE file (later replaced with custom license)

### Changed
- CI workflow split from single smoke test into 6 individual steps
- README Swift badge updated from 5.0 to 6.1
- README license badge updated to Custom
- Catalog sections: 34 to 37

## [0.0.48] - 2026-04-07

### Added
- Gemini CLI detection and session scanning
- Pipeline customization, custom jobs, and prompt toggle
- Pixel art set as default app icon

### Changed
- Theme.swift (6,210 lines) split into 5 focused files
- Tuist 4.x API migration and stability hardening

### Fixed
- Transparent modal backgrounds on all sheet views
- Tuist 4.x API compatibility in CI

## [0.0.47] - 2026-04-06

### Fixed
- Character rendering issues
- Performance optimization
- New settings options

## [0.0.46] - 2026-04-04

### Fixed
- Auto-update hardened to prevent install hangs and data loss
- Update checker pointed to wrong repo and app hung during install

## [0.0.45] - 2026-04-04

### Added
- Crash logging system (`CrashLogger`)
- Diagnostic report generation
- Smoke test pipeline (`Scripts/smoke-test.sh`)
- Unit tests for StreamBlock, AgentEnum, TokenTracker, CLI, TerminalTab

### Changed
- CI upgraded to macos-15 runner with Xcode 16.x
- Clean neutral gray palette (replaced blue-tinted)
- Large files split into focused extensions
- Types extracted from god objects into dedicated files
- README rewritten for multi-AI agent focus

### Fixed
- Memory leaks and crash-on-idle issues
- Text clipping and layout overflow in sidebar and office view
- Server hardening

## [0.0.43] - 2026-04-03

### Fixed
- Browser persistence and token calculator
- Hardcoded values replaced with fallback window

## [0.0.42] - 2026-04-02

### Added
- Unit tests for StreamBlock, AgentEnum, TokenTracker, CLI, TerminalTab

### Changed
- Legacy Doffice target synced with modular structure

### Fixed
- Provider switch session reset
- CJK bubble width calculation
- Browser navigation issues
