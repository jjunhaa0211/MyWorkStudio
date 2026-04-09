# Changelog

All notable changes to Doffice are documented here.

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
