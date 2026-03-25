import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Office Window View (듀얼 모니터용 별도 창)
// ═══════════════════════════════════════════════════════

struct OfficeWindowView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // 미니 타이틀 바
            HStack(spacing: 8) {
                Color.clear.frame(width: 58, height: 1)
                Text("⛏").font(Theme.scaled(12))
                Text(settings.appDisplayName)
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text("OFFICE")
                    .font(Theme.mono(8, weight: .heavy))
                    .foregroundColor(Theme.textDim).tracking(2)
                Spacer()

                // 활성 세션 수
                HStack(spacing: 4) {
                    Circle().fill(Theme.green).frame(width: 5, height: 5)
                    Text("\(manager.userVisibleTabs.filter { !$0.isCompleted }.count) active")
                        .font(Theme.mono(9, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }

                // 레벨
                let level = AchievementManager.shared.currentLevel
                Text("\(level.badge) Lv.\(level.level)")
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundColor(Theme.yellow)
                    .padding(.trailing, 8)
            }
            .frame(height: 32)
            .padding(.horizontal, 8)
            .background(Theme.bgCard)

            Rectangle().fill(Theme.border).frame(height: 1)

            // 오피스 씬 (전체 영역)
            OfficeSceneView()
        }
        .background(Theme.bg)
        .frame(minWidth: 600, minHeight: 400)
    }
}
