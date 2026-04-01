import SwiftUI
import DesignSystem
import DofficeKit

extension SettingsView {
    private struct TokenPlanOption: Identifiable {
        enum LimitMode {
            case preset(Int)
            case manual
            case usageBased
        }

        let name: String
        let subtitle: String
        let limitMode: LimitMode

        var id: String { name }

        var weeklyLimit: Int {
            switch limitMode {
            case .preset(let limit):
                return limit
            case .manual, .usageBased:
                return 0
            }
        }
    }

    // MARK: - 토큰 탭

    var tokenTab: some View {
        let protectionReason = tokenTracker.startBlockReason(isAutomation: false)
        return VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.usage", comment: ""), subtitle: NSLocalizedString("settings.usage.subtitle", comment: "")) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        usageMetricCard(
                            title: NSLocalizedString("settings.usage.today", comment: ""),
                            value: tokenTracker.formatTokens(tokenTracker.todayTokens),
                            secondary: "$" + String(format: "%.2f", tokenTracker.todayCost),
                            tint: Theme.accent,
                            progress: tokenTracker.dailyUsagePercent
                        )
                        usageMetricCard(
                            title: NSLocalizedString("settings.usage.week", comment: ""),
                            value: tokenTracker.formatTokens(tokenTracker.weekTokens),
                            secondary: "$" + String(format: "%.2f", tokenTracker.weekCost),
                            tint: Theme.cyan,
                            progress: tokenTracker.weeklyUsagePercent
                        )
                    }

                    if settings.tokenProtectionEnabled {
                        HStack(spacing: 12) {
                            tokenLimitField(title: NSLocalizedString("settings.token.daily.limit", comment: ""), value: $tokenTracker.dailyTokenLimit)
                            tokenLimitField(title: NSLocalizedString("settings.token.weekly.limit", comment: ""), value: $tokenTracker.weeklyTokenLimit)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if !settings.tokenProtectionEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.slash")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                    .foregroundColor(Theme.textDim)
                                Text("토큰 보호 비활성 — 일간/주간 한도 없이 무제한 사용")
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textDim)
                            }
                        } else if let protectionReason {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                    .foregroundColor(Theme.orange)
                                Text(protectionReason)
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                    .foregroundColor(Theme.green)
                                Text(NSLocalizedString("settings.token.ok.desc", comment: ""))
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 10) {
                            if settings.tokenProtectionEnabled {
                                Button(action: {
                                    tokenTracker.applyRecommendedMinimumLimits()
                                }) {
                                    Text(NSLocalizedString("settings.token.apply.min", comment: ""))
                                        .font(Theme.mono(9, weight: .bold))
                                        .foregroundColor(Theme.cyan)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cyan.opacity(0.1)))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cyan.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: { showTokenResetConfirm = true }) {
                                Text(NSLocalizedString("settings.token.reset", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                                    .foregroundColor(Theme.orange)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.orange.opacity(0.1)))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.orange.opacity(0.25), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface.opacity(0.85)))
                }
            }

            settingsSection(title: "토큰 보호", subtitle: "전역 보호 · Provider별 세션 한도 · 토큰 계산기") {
                VStack(spacing: 10) {
                    settingsToggleRow(
                        title: "토큰 보호 활성화",
                        subtitle: settings.tokenProtectionEnabled ? "일간/주간 한도 초과 시 자동 차단" : "보호 꺼짐 — 일간/주간 한도 무시",
                        isOn: Binding(
                            get: { settings.tokenProtectionEnabled },
                            set: { settings.tokenProtectionEnabled = $0 }
                        ),
                        tint: settings.tokenProtectionEnabled ? Theme.green : Theme.textDim
                    )

                    if settings.tokenProtectionEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Provider별 세션 토큰 한도 (0 = 무제한)")
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textDim)

                            HStack(spacing: 8) {
                                providerTokenLimitField("🔵 Claude", value: Binding(
                                    get: { settings.claudeSessionTokenLimit },
                                    set: { settings.claudeSessionTokenLimit = $0 }
                                ))
                                providerTokenLimitField("◉ Codex", value: Binding(
                                    get: { settings.codexSessionTokenLimit },
                                    set: { settings.codexSessionTokenLimit = $0 }
                                ))
                                providerTokenLimitField("💎 Gemini", value: Binding(
                                    get: { settings.geminiSessionTokenLimit },
                                    set: { settings.geminiSessionTokenLimit = $0 }
                                ))
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface.opacity(0.85)))

                        // ── 토큰 계산기 ──
                        tokenCalculatorSection
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.automation", comment: ""), subtitle: NSLocalizedString("settings.automation.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    settingsToggleRow(
                        title: NSLocalizedString("settings.automation.parallel", comment: ""),
                        subtitle: settings.allowParallelSubagents ? NSLocalizedString("settings.automation.allowed", comment: "") : NSLocalizedString("settings.automation.blocked", comment: ""),
                        isOn: Binding(
                            get: { settings.allowParallelSubagents },
                            set: { settings.allowParallelSubagents = $0 }
                        ),
                        tint: Theme.purple
                    )

                    settingsToggleRow(
                        title: NSLocalizedString("settings.automation.terminal.light", comment: ""),
                        subtitle: settings.terminalSidebarLightweight ? NSLocalizedString("settings.enabled", comment: "") : NSLocalizedString("settings.disabled", comment: ""),
                        isOn: Binding(
                            get: { settings.terminalSidebarLightweight },
                            set: { settings.terminalSidebarLightweight = $0 }
                        ),
                        tint: Theme.cyan
                    )

                    HStack(spacing: 10) {
                        limitStepperCard(
                            title: NSLocalizedString("settings.automation.review.max", comment: ""),
                            subtitle: NSLocalizedString("settings.automation.review.sub", comment: ""),
                            value: Binding(
                                get: { settings.reviewerMaxPasses },
                                set: { settings.reviewerMaxPasses = min(3, max(0, $0)) }
                            ),
                            range: 0...3,
                            tint: Theme.yellow
                        )
                        limitStepperCard(
                            title: "QA 최대",
                            subtitle: NSLocalizedString("settings.automation.qa.sub", comment: ""),
                            value: Binding(
                                get: { settings.qaMaxPasses },
                                set: { settings.qaMaxPasses = min(3, max(0, $0)) }
                            ),
                            range: 0...3,
                            tint: Theme.green
                        )
                    }

                    limitStepperCard(
                        title: NSLocalizedString("settings.automation.revision.max", comment: ""),
                        subtitle: NSLocalizedString("settings.automation.revision.sub", comment: ""),
                        value: Binding(
                            get: { settings.automationRevisionLimit },
                            set: { settings.automationRevisionLimit = min(5, max(1, $0)) }
                        ),
                        range: 1...5,
                        tint: Theme.accent
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: Theme.iconSize(11), weight: .bold))
                            .foregroundColor(Theme.orange)
                        Text(NSLocalizedString("settings.automation.worker.limit", comment: ""))
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.orange.opacity(0.08))
                    )
                }
            }
        }
    }

    // MARK: - Token Calculator (Provider별)

    private var tokenCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "function")
                    .font(.system(size: Theme.iconSize(10), weight: .bold))
                    .foregroundColor(Theme.purple)
                Text("토큰 계산기")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("공식 플랜 이름 + 내부 가드레일")
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textDim)
            }

            Text("Codex는 공식 플랜이 5시간 rate limit, 주간 코드리뷰, 크레딧 기준으로 안내되어 토큰 총량이 직접 공개되지 않습니다. Codex 항목은 공식 플랜 이름을 정리하고, 토큰 한도는 위 Provider별 세션 한도로 직접 맞추도록 유지합니다.")
                .font(Theme.mono(7))
                .foregroundColor(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)

            // 전체 주간 합산 요약
            let totalWeekly = settings.claudeWeeklyLimit + settings.codexWeeklyLimit + settings.geminiWeeklyLimit
            let totalDaily = totalWeekly / 7
            if totalWeekly > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "sum").font(.system(size: 9, weight: .bold)).foregroundColor(Theme.accent)
                    Text("합산: 주 \(tokenTracker.formatTokens(totalWeekly)) · 일 \(tokenTracker.formatTokens(totalDaily))")
                        .font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.accent)
                    Spacer()
                    Button("합산 한도 적용") {
                        tokenTracker.weeklyTokenLimit = totalWeekly
                        tokenTracker.dailyTokenLimit = totalDaily
                    }
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent))
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.08)))
            }

            // Claude
            providerPlanSection(
                icon: "🔵", provider: "Claude", color: Theme.accent,
                plans: [
                    TokenPlanOption(name: "Pro", subtitle: "주 25.0M", limitMode: .preset(25_000_000)),
                    TokenPlanOption(name: "Max 5x", subtitle: "주 125.0M", limitMode: .preset(125_000_000)),
                    TokenPlanOption(name: "Max 20x", subtitle: "주 500.0M", limitMode: .preset(500_000_000)),
                    TokenPlanOption(name: "Team", subtitle: "주 50.0M", limitMode: .preset(50_000_000)),
                    TokenPlanOption(name: "Enterprise", subtitle: "주 100.0M", limitMode: .preset(100_000_000)),
                ],
                selectedPlan: settings.claudePlanName,
                weeklyLimit: settings.claudeWeeklyLimit,
                onSelect: { plan in
                    settings.claudePlanName = plan.name
                    settings.claudeWeeklyLimit = plan.weeklyLimit
                    settings.claudeSessionTokenLimit = plan.weeklyLimit / 7
                },
                onClear: {
                    settings.claudePlanName = ""
                    settings.claudeWeeklyLimit = 0
                    settings.claudeSessionTokenLimit = 0
                }
            )

            // Codex
            providerPlanSection(
                icon: "◉", provider: "Codex", color: Theme.green,
                plans: [
                    TokenPlanOption(name: "Free", subtitle: "한시 포함", limitMode: .manual),
                    TokenPlanOption(name: "Go", subtitle: "한시 포함", limitMode: .manual),
                    TokenPlanOption(name: "Plus", subtitle: "CLI 포함", limitMode: .manual),
                    TokenPlanOption(name: "Pro", subtitle: "CLI 포함", limitMode: .manual),
                    TokenPlanOption(name: "Business", subtitle: "CLI 포함", limitMode: .manual),
                    TokenPlanOption(name: "Enterprise/Edu", subtitle: "CLI 포함", limitMode: .manual),
                    TokenPlanOption(name: "API Key", subtitle: "사용량 기반", limitMode: .usageBased),
                ],
                selectedPlan: settings.codexPlanName,
                weeklyLimit: settings.codexWeeklyLimit,
                onSelect: { plan in
                    settings.codexPlanName = plan.name
                    if case .preset(let weekly) = plan.limitMode {
                        settings.codexWeeklyLimit = weekly
                        settings.codexSessionTokenLimit = weekly / 7
                    } else {
                        settings.codexWeeklyLimit = 0
                    }
                },
                onClear: {
                    settings.codexPlanName = ""
                    settings.codexWeeklyLimit = 0
                    settings.codexSessionTokenLimit = 0
                }
            )

            // Gemini
            providerPlanSection(
                icon: "💎", provider: "Gemini", color: Theme.cyan,
                plans: [
                    TokenPlanOption(name: "Advanced", subtitle: "주 40.0M", limitMode: .preset(40_000_000)),
                    TokenPlanOption(name: "Business", subtitle: "주 80.0M", limitMode: .preset(80_000_000)),
                ],
                selectedPlan: settings.geminiPlanName,
                weeklyLimit: settings.geminiWeeklyLimit,
                onSelect: { plan in
                    settings.geminiPlanName = plan.name
                    settings.geminiWeeklyLimit = plan.weeklyLimit
                    settings.geminiSessionTokenLimit = plan.weeklyLimit / 7
                },
                onClear: {
                    settings.geminiPlanName = ""
                    settings.geminiWeeklyLimit = 0
                    settings.geminiSessionTokenLimit = 0
                }
            )
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface.opacity(0.85)))
    }

    private func providerPlanSection(
        icon: String, provider: String, color: Color,
        plans: [TokenPlanOption],
        selectedPlan: String, weeklyLimit: Int,
        onSelect: @escaping (TokenPlanOption) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(icon).font(.system(size: 10))
                Text(provider).font(Theme.mono(9, weight: .bold)).foregroundColor(color)
                if !selectedPlan.isEmpty {
                    Text(selectedPlan).font(Theme.mono(8)).foregroundColor(Theme.textDim)
                    Text(weeklyLimit > 0 ? "· 주 \(tokenTracker.formatTokens(weeklyLimit))" : "· 토큰 한도 직접 설정")
                        .font(Theme.mono(7, weight: .semibold)).foregroundColor(color)
                    Spacer()
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textDim)
                    }.buttonStyle(.plain)
                } else {
                    Text("미설정").font(Theme.mono(8)).foregroundColor(Theme.textMuted)
                    Spacer()
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 4)], spacing: 4) {
                ForEach(plans, id: \.name) { plan in
                    let isActive = selectedPlan == plan.name
                    Button(action: { onSelect(plan) }) {
                        VStack(spacing: 2) {
                            Text(plan.name)
                                .font(Theme.mono(7, weight: .bold))
                                .foregroundColor(isActive ? .white : Theme.textPrimary)
                            Text(plan.subtitle)
                                .font(Theme.mono(6))
                                .foregroundColor(isActive ? .white.opacity(0.8) : Theme.textDim)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? color : Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActive ? color : Theme.border.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}
