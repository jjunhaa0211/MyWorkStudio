import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Usage Summary View (사용량 요약)
// ═══════════════════════════════════════════════════════

public struct UsageSummaryView: View {
    @ObservedObject private var tracker = TokenTracker.shared
    @State private var claudeUsage: ClaudeUsageFetcher.UsageData?
    @State private var isLoading = false
    @State private var lastRefresh: Date?
    public var compact: Bool = false

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            // 헤더
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: Theme.iconSize(compact ? 10 : 12), weight: .bold))
                    .foregroundColor(Theme.cyan)
                Text(NSLocalizedString("usage.title", comment: ""))
                    .font(Theme.mono(compact ? 10 : 11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Button(action: refreshUsage) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: Theme.iconSize(9), weight: .bold))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("usage.refresh", comment: ""))
                }
            }

            // Claude 플랜 사용량 (실제 데이터)
            if let usage = claudeUsage, !usage.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: Theme.iconSize(8)))
                            .foregroundColor(Theme.accent)
                        Text(NSLocalizedString("usage.claude.plan", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }

                    ForEach(usage.sections) { section in
                        usageBar(label: section.label, percent: section.percent, detail: section.resetInfo)
                    }

                    if !usage.extraInfo.isEmpty {
                        Text(usage.extraInfo)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textDim)
                    }
                }
            }

            // 로컬 토큰 추적 (모든 프로바이더)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.needle.fill")
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(Theme.green)
                    Text(NSLocalizedString("usage.local.tracking", comment: ""))
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }

                let dailyLimit = tracker.dailyTokenLimit
                let weeklyLimit = tracker.weeklyTokenLimit
                let dailyPct = dailyLimit > 0 ? min(100, tracker.todayTokens * 100 / dailyLimit) : 0
                let weeklyPct = weeklyLimit > 0 ? min(100, tracker.weekTokens * 100 / weeklyLimit) : 0

                usageBar(
                    label: NSLocalizedString("usage.today", comment: ""),
                    percent: dailyPct,
                    detail: formatTokens(tracker.todayTokens) + (dailyLimit > 0 ? " / \(formatTokens(dailyLimit))" : "")
                )
                usageBar(
                    label: NSLocalizedString("usage.week", comment: ""),
                    percent: weeklyPct,
                    detail: formatTokens(tracker.weekTokens) + (weeklyLimit > 0 ? " / \(formatTokens(weeklyLimit))" : "")
                )

                if tracker.todayCost > 0 {
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("usage.cost.today", comment: ""))
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textDim)
                        Text("$\(String(format: "%.4f", tracker.todayCost))")
                            .font(Theme.mono(8, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            if let lastRefresh {
                Text(String(format: NSLocalizedString("usage.last.refresh", comment: ""), lastRefresh.formatted(.dateTime.hour().minute())))
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .onAppear {
            if claudeUsage == nil {
                refreshUsage()
            }
        }
    }

    private func usageBar(label: String, percent: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(Theme.mono(compact ? 8 : 9))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("\(percent)%")
                    .font(Theme.mono(compact ? 8 : 9, weight: .bold))
                    .foregroundColor(barColor(for: percent))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.bgSurface)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(for: percent))
                        .frame(width: max(0, geo.size.width * CGFloat(percent) / 100.0))
                }
            }
            .frame(height: compact ? 4 : 6)

            if !detail.isEmpty {
                Text(detail)
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textDim)
            }
        }
    }

    private func barColor(for percent: Int) -> Color {
        if percent >= 80 { return Theme.red }
        if percent >= 50 { return Theme.yellow }
        return Theme.green
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1_000) }
        return "\(count)"
    }

    private func refreshUsage() {
        guard !isLoading else { return }
        isLoading = true
        ClaudeUsageFetcher.fetchAsync { data in
            claudeUsage = data
            isLoading = false
            lastRefresh = Date()
        }
    }
}
