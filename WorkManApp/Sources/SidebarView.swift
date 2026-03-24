import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @AppStorage("viewMode") private var appViewModeRaw: Int = 1
    @State private var draggingTabId: String?
    @State private var showHistory: Bool = false

    private var isTerminalOnlyMode: Bool {
        appViewModeRaw == 2
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "circle.grid.2x2.fill").font(Theme.monoTiny).foregroundColor(Theme.textDim)
                Text("SESSIONS").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(2)
                Spacer()
                Button(action: { showHistory.toggle() }) {
                    Image(systemName: "clock.arrow.circlepath").font(Theme.monoTiny)
                        .foregroundColor(showHistory ? Theme.accent : Theme.textDim)
                }.buttonStyle(.plain).help("세션 히스토리")
                Text("\(manager.userVisibleTabCount)")
                    .font(Theme.monoSmall).foregroundColor(Theme.textDim)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Theme.bgSurface).cornerRadius(3)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            if showHistory { SessionHistoryView() }

            // "전체" 버튼
            if manager.selectedGroupPath != nil {
                Button(action: { manager.selectedGroupPath = nil; manager.focusSingleTab = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(Theme.mono(8, weight: .bold))
                        Text("전체 보기").font(Theme.mono(9, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                }.buttonStyle(.plain)
            }

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(manager.projectGroups) { group in
                        if group.tabs.count == 1 {
                            SessionCard(tab: group.tabs[0])
                        } else {
                            // 그룹 헤더 - 클릭하면 오른쪽에 이 그룹만 표시
                            SessionGroupCard(group: group)
                        }
                    }
                }.padding(.horizontal, 8).padding(.vertical, 4)
            }

            Spacer(minLength: 0)
            if !(isTerminalOnlyMode && settings.terminalSidebarLightweight) {
                gamePanel
            }
            tokenUsagePanel
            if manager.totalTokensUsed > 0 { tokenPanel }
            if isTerminalOnlyMode && settings.terminalSidebarLightweight {
                lightweightManagementButtons
            } else {
                managementButtons
            }
            addButton
        }
        .background(Theme.bgCard)
    }

    @ObservedObject private var tracker = TokenTracker.shared

    private var tokenUsagePanel: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Theme.border).frame(height: 1)
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill").font(Theme.monoTiny).foregroundColor(Theme.cyan)
                        Text("USAGE").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(2)
                    }
                    Spacer()
                }

                // Today
                VStack(spacing: 4) {
                    HStack {
                        Text("오늘").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(tracker.formatTokens(tracker.todayTokens))
                            .font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                        Text("/").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        Text(tracker.formatTokens(tracker.dailyTokenLimit))
                            .font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.bg).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(dailyBarColor)
                                .frame(width: max(0, geo.size.width * min(1, tracker.dailyUsagePercent)), height: 4)
                        }
                    }.frame(height: 4)
                    HStack {
                        Text("남은 양").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                        Spacer()
                        Text(tracker.formatTokens(tracker.dailyRemaining))
                            .font(Theme.mono(8, weight: .semibold))
                            .foregroundColor(tracker.dailyUsagePercent > 0.8 ? Theme.red : Theme.green)
                    }
                    if tracker.todayCost > 0 {
                        HStack {
                            Text("비용").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(String(format: "$%.4f", tracker.todayCost))
                                .font(Theme.mono(8)).foregroundColor(Theme.yellow)
                        }
                    }
                }

                Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 1)

                // Week
                VStack(spacing: 4) {
                    HStack {
                        Text("이번 주").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(tracker.formatTokens(tracker.weekTokens))
                            .font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                        Text("/").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        Text(tracker.formatTokens(tracker.weeklyTokenLimit))
                            .font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.bg).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(weeklyBarColor)
                                .frame(width: max(0, geo.size.width * min(1, tracker.weeklyUsagePercent)), height: 4)
                        }
                    }.frame(height: 4)
                    HStack {
                        Text("남은 양").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                        Spacer()
                        Text(tracker.formatTokens(tracker.weeklyRemaining))
                            .font(Theme.mono(8, weight: .semibold))
                            .foregroundColor(tracker.weeklyUsagePercent > 0.8 ? Theme.red : Theme.green)
                    }
                    if tracker.weekCost > 0 {
                        HStack {
                            Text("비용").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(String(format: "$%.4f", tracker.weekCost))
                                .font(Theme.mono(8)).foregroundColor(Theme.yellow)
                        }
                    }
                }

                // 현재 세션 상세
                if manager.totalTokensUsed > 0 {
                    Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 1)
                    HStack {
                        Text("현재 세션").font(Theme.mono(8, weight: .medium)).foregroundColor(Theme.textDim)
                        Spacer()
                        let totalIn = manager.userVisibleTabs.reduce(0) { $0 + $1.inputTokensUsed }
                        let totalOut = manager.userVisibleTabs.reduce(0) { $0 + $1.outputTokensUsed }
                        if totalIn > 0 || totalOut > 0 {
                            HStack(spacing: 4) {
                                Text("In").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                                Text(formatTokens(totalIn)).font(Theme.mono(8, weight: .semibold)).foregroundColor(Theme.accent)
                                Text("Out").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                                Text(formatTokens(totalOut)).font(Theme.mono(8, weight: .semibold)).foregroundColor(Theme.green)
                            }
                        } else {
                            Text(formatTokens(manager.totalTokensUsed)).font(Theme.mono(8, weight: .semibold)).foregroundColor(Theme.textPrimary)
                        }
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    private var dailyBarColor: Color {
        if tracker.dailyUsagePercent > 0.9 { return Theme.red }
        if tracker.dailyUsagePercent > 0.7 { return Theme.yellow }
        return Theme.green
    }

    private var weeklyBarColor: Color {
        if tracker.weeklyUsagePercent > 0.9 { return Theme.red }
        if tracker.weeklyUsagePercent > 0.7 { return Theme.yellow }
        return Theme.cyan
    }

    private var tokenPanel: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Theme.border).frame(height: 1)
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(Theme.monoTiny).foregroundColor(Theme.yellow)
                        Text("TOKENS").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(2)
                    }
                    Spacer()
                    Text(formatTokens(manager.totalTokensUsed))
                        .font(Theme.mono(12, weight: .semibold)).foregroundColor(Theme.textPrimary)
                }
                ForEach(manager.userVisibleTabs.sorted(by: { $0.tokensUsed > $1.tokensUsed })) { tab in
                    if tab.tokensUsed > 0 {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 12)
                            Text(tab.workerName).font(Theme.monoTiny).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(formatTokens(tab.tokensUsed)).font(Theme.monoTiny).foregroundColor(Theme.textDim)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Theme.bg)
                                    RoundedRectangle(cornerRadius: 2).fill(tab.workerColor.opacity(0.5))
                                        .frame(width: max(2, geo.size.width * CGFloat(tab.tokensUsed) / CGFloat(max(1, tab.tokenLimit))))
                                }
                            }.frame(width: 36, height: 3)
                        }
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    private var gamePanel: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Theme.border).frame(height: 1)
            VStack(spacing: 8) {
                XPBarView(xp: AchievementManager.shared.totalXP)
                AchievementsView()
            }.padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    private var addButton: some View {
        Button(action: { manager.showNewTabSheet = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").font(Theme.monoNormal)
                Text("New Session").font(Theme.mono(11, weight: .medium))
            }
            .foregroundColor(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.15), lineWidth: 1)))
        }
        .buttonStyle(.plain).padding(.horizontal, 10).padding(.vertical, 8)
    }

    @State private var showCharacterSheet = false
    @State private var showAchievementSheet = false
    @State private var showAccessorySheet = false
    @State private var showReportSheet = false

    private var managementButtons: some View {
        VStack(spacing: 6) {
            Button(action: { showCharacterSheet = true }) {
                HStack(spacing: 8) {
                    Text("👥").font(Theme.scaled(14))
                    Text("캐릭터 관리").font(Theme.mono(11, weight: .medium))
                    Spacer()
                    Text("\(CharacterRegistry.shared.hiredCharacters.count)/\(CharacterRegistry.shared.allCharacters.count)")
                        .font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.accent)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.accent.opacity(0.1)).cornerRadius(4)
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.vertical, 9).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
            }.buttonStyle(.plain)

            Button(action: { showAccessorySheet = true }) {
                HStack(spacing: 8) {
                    Text("🛋️").font(Theme.scaled(14))
                    Text("악세서리").font(Theme.mono(11, weight: .medium))
                    Spacer()
                    Text("\(breakRoomFurnitureOnCount)/20")
                        .font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.purple)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.purple.opacity(0.1)).cornerRadius(4)
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.vertical, 9).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
            }.buttonStyle(.plain)

            Button(action: { showReportSheet = true }) {
                HStack(spacing: 8) {
                    Text("📝").font(Theme.scaled(14))
                    Text("보고서").font(Theme.mono(11, weight: .medium))
                    Spacer()
                    Text("\(manager.availableReportCount)")
                        .font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.cyan)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.cyan.opacity(0.1)).cornerRadius(4)
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.vertical, 9).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
            }.buttonStyle(.plain)

            Button(action: { showAchievementSheet = true }) {
                HStack(spacing: 8) {
                    Text("🏆").font(Theme.scaled(14))
                    Text("도전과제").font(Theme.mono(11, weight: .medium))
                    Spacer()
                    Text("\(AchievementManager.shared.unlockedCount)/\(AchievementManager.shared.achievements.count)")
                        .font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.yellow)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.yellow.opacity(0.1)).cornerRadius(4)
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.vertical, 9).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.bottom, 6)
        .sheet(isPresented: $showCharacterSheet) {
            CharacterCollectionView()
                .frame(minWidth: 940, idealWidth: 1040, minHeight: 760, idealHeight: 840)
        }
        .sheet(isPresented: $showAccessorySheet) { AccessoryView().frame(minWidth: 480, minHeight: 560) }
        .sheet(isPresented: $showReportSheet) { ReportCenterView().frame(minWidth: 760, minHeight: 620) }
        .sheet(isPresented: $showAchievementSheet) { AchievementCollectionView().frame(minWidth: 880, idealWidth: 960, minHeight: 680, idealHeight: 740) }
    }

    private var lightweightManagementButtons: some View {
        VStack(spacing: 6) {
            lightweightButton(title: "캐릭터 관리", emoji: "👥") { showCharacterSheet = true }
            lightweightButton(title: "악세서리", emoji: "🛋️") { showAccessorySheet = true }
            lightweightButton(title: "보고서", emoji: "📝") { showReportSheet = true }
            lightweightButton(title: "도전과제", emoji: "🏆") { showAchievementSheet = true }
        }
        .padding(.horizontal, 10).padding(.bottom, 6)
        .sheet(isPresented: $showCharacterSheet) {
            CharacterCollectionView()
                .frame(minWidth: 940, idealWidth: 1040, minHeight: 760, idealHeight: 840)
        }
        .sheet(isPresented: $showAccessorySheet) { AccessoryView().frame(minWidth: 480, minHeight: 560) }
        .sheet(isPresented: $showReportSheet) { ReportCenterView().frame(minWidth: 760, minHeight: 620) }
        .sheet(isPresented: $showAchievementSheet) { AchievementCollectionView().frame(minWidth: 880, idealWidth: 960, minHeight: 680, idealHeight: 740) }
    }

    private func lightweightButton(title: String, emoji: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji).font(Theme.scaled(14))
                Text(title).font(Theme.mono(11, weight: .medium))
                Spacer()
                Text("열기")
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(Theme.textDim)
            }
            .foregroundColor(Theme.textSecondary)
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.2), lineWidth: 0.5)))
        }
        .buttonStyle(.plain)
    }

    private var breakRoomFurnitureOnCount: Int {
        let s = AppSettings.shared
        return [s.breakRoomShowSofa, s.breakRoomShowCoffeeMachine, s.breakRoomShowPlant, s.breakRoomShowSideTable,
                s.breakRoomShowPicture, s.breakRoomShowNeonSign, s.breakRoomShowRug,
                s.breakRoomShowBookshelf, s.breakRoomShowAquarium, s.breakRoomShowArcade, s.breakRoomShowWhiteboard,
                s.breakRoomShowLamp, s.breakRoomShowCat, s.breakRoomShowTV, s.breakRoomShowFan,
                s.breakRoomShowCalendar, s.breakRoomShowPoster, s.breakRoomShowTrashcan, s.breakRoomShowCushion].filter { $0 }.count
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000.0) }
        return "\(count)"
    }
}

struct ReportCenterView: View {
    @EnvironmentObject var manager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReportPath: String?
    @State private var reportText: String = ""

    private var reports: [SessionManager.ReportReference] {
        manager.availableReports()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REPORTS")
                        .font(Theme.mono(14, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                    Text("QA 통과 후 생성된 Markdown 보고서를 앱 안에서 바로 확인합니다.")
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.iconSize(16), weight: .bold))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
            .padding(18)

            Rectangle().fill(Theme.border.opacity(0.6)).frame(height: 1)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("목록")
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.textDim)
                        Spacer()
                        Text("\(reports.count)")
                            .font(Theme.mono(8, weight: .bold))
                            .foregroundColor(Theme.cyan)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    ScrollView {
                        VStack(spacing: 6) {
                            if reports.isEmpty {
                                Text("생성된 보고서가 아직 없습니다.")
                                    .font(Theme.mono(10))
                                    .foregroundColor(Theme.textDim)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                            } else {
                                ForEach(reports) { report in
                                    reportRow(report)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                }
                .frame(width: 260)

                Rectangle().fill(Theme.border.opacity(0.6)).frame(width: 1)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(selectedReportTitle)
                            .font(Theme.mono(10, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        if let selectedReportPath {
                            Button("Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: selectedReportPath)])
                            }
                            .buttonStyle(.plain)
                            .font(Theme.mono(8, weight: .bold))
                            .foregroundColor(Theme.cyan)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.bgCard.opacity(0.95))

                    Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 1)

                    ScrollView {
                        if reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("왼쪽에서 보고서를 선택하면 내용이 여기에 표시됩니다.")
                                .font(Theme.mono(10))
                                .foregroundColor(Theme.textDim)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(18)
                        } else {
                            MarkdownTextView(text: reportText, compact: false)
                                .padding(18)
                        }
                    }
                    .background(Theme.bg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.bgCard)
        .onAppear {
            if selectedReportPath == nil, let first = reports.first {
                loadReport(first.path)
            }
        }
        .onChange(of: reports.map(\.path)) { _, paths in
            if let selectedReportPath, paths.contains(selectedReportPath) {
                loadReport(selectedReportPath)
            } else if let first = reports.first {
                loadReport(first.path)
            } else {
                selectedReportPath = nil
                reportText = ""
            }
        }
    }

    private var selectedReportTitle: String {
        guard let selectedReportPath else { return "Report Preview" }
        return (selectedReportPath as NSString).lastPathComponent
    }

    private func reportRow(_ report: SessionManager.ReportReference) -> some View {
        let isSelected = selectedReportPath == report.path
        return Button(action: { loadReport(report.path) }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(isSelected ? Theme.cyan : Theme.textDim.opacity(0.5)).frame(width: 6, height: 6)
                    Text(report.projectName)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }

                Text((report.path as NSString).lastPathComponent)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)

                Text(report.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.mono(7, weight: .medium))
                    .foregroundColor(Theme.cyan.opacity(0.8))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.bgSelected : Theme.bgSurface.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Theme.cyan.opacity(0.35) : Theme.border.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func loadReport(_ path: String) {
        selectedReportPath = path
        reportText = (try? String(contentsOfFile: path, encoding: .utf8)) ?? "보고서를 불러오지 못했습니다."
    }
}

// MARK: - Session Group Card

struct SessionGroupCard: View {
    let group: SessionManager.ProjectGroup
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var isExpanded = false
    private var isGroupActive: Bool { group.hasActiveTab }

    private var isGroupSelected: Bool { manager.selectedGroupPath == group.id }

    var body: some View {
        VStack(spacing: 0) {
            // 그룹 헤더: 클릭 → 오른쪽 패널에 이 그룹만 표시 + 펼침
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    // 이미 선택된 그룹이면 펼침 토글, 아니면 선택 + 펼침
                    if isGroupSelected && !manager.focusSingleTab {
                        isExpanded.toggle()
                    } else {
                        manager.selectedGroupPath = group.id
                        manager.focusSingleTab = false  // 그룹 전체 보기
                        isExpanded = true
                        if let first = group.tabs.first { manager.selectTab(first.id) }
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.textDim).frame(width: 10)
                    Circle().fill(groupColor).frame(width: 7, height: 7)
                        .shadow(color: groupColor.opacity(0.5), radius: isGroupSelected ? 3 : 0)
                    Text(group.projectName).font(Theme.mono(11, weight: isGroupSelected ? .bold : .semibold))
                        .foregroundColor(isGroupSelected ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                    Spacer()
                    HStack(spacing: 2) { ForEach(group.tabs) { t in Circle().fill(t.workerColor).frame(width: 5, height: 5) } }
                    Text("\(group.tabs.count)").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.accent)
                        .padding(.horizontal, 5).padding(.vertical, 1).background(Theme.accent.opacity(0.1)).cornerRadius(3)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(isGroupSelected ? Theme.bgSelected : Theme.bgSurface.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(isGroupSelected ? Theme.accent.opacity(0.4) : .clear, lineWidth: isGroupSelected ? 1.5 : 0)))
            }.buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) { ForEach(group.tabs) { tab in WorkerMiniCard(tab: tab) } }
                    .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 4)
            }
        }
    }

    private var groupColor: Color {
        var allCompleted = true
        var anyProcessing = false
        var anyRunning = false
        for tab in group.tabs {
            if !tab.isCompleted { allCompleted = false }
            if tab.isProcessing { anyProcessing = true }
            if tab.isRunning { anyRunning = true }
        }
        if allCompleted { return Theme.green }
        if anyProcessing { return Theme.yellow }
        return anyRunning ? Theme.green.opacity(0.5) : Theme.textDim
    }
}

struct WorkerMiniCard: View {
    @ObservedObject var tab: TerminalTab
    @EnvironmentObject var manager: SessionManager
    private var isSelected: Bool { manager.activeTabId == tab.id }
    var body: some View {
        Button(action: { manager.focusSingleTab = true; manager.selectTab(tab.id) }) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 14)
                Text(tab.workerName).font(Theme.mono(10, weight: .medium)).foregroundColor(tab.workerColor)
                if tab.isProcessing { Text(tab.claudeActivity.rawValue).font(Theme.mono(8)).foregroundColor(Theme.yellow) }
                else if tab.isCompleted { Image(systemName: "checkmark.circle.fill").font(Theme.mono(8)).foregroundColor(Theme.green) }
                Spacer()
                if tab.tokensUsed > 0 { Text(tab.tokensUsed >= 1000 ? String(format: "%.1fk", Double(tab.tokensUsed)/1000) : "\(tab.tokensUsed)")
                    .font(Theme.monoTiny).foregroundColor(Theme.textDim) }
                if isSelected { Button(action: { manager.removeTab(tab.id) }) {
                    Image(systemName: "xmark").font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.textDim).padding(2) }.buttonStyle(.plain) }
            }.padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Theme.bgSelected : .clear)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Theme.accent.opacity(0.2) : .clear, lineWidth: 1)))
        }.buttonStyle(.plain)
    }
}

// MARK: - Session Card

struct SessionCard: View {
    @ObservedObject var tab: TerminalTab
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var isEditingName = false
    @State private var editName = ""

    private var isSelected: Bool { manager.activeTabId == tab.id }

    private var statusColor: Color {
        if tab.isCompleted { return Theme.green }
        switch tab.claudeActivity {
        case .thinking: return Theme.purple
        case .writing: return Theme.green
        case .reading: return Theme.accent
        case .searching: return Theme.cyan
        case .running: return Theme.yellow
        case .error: return Theme.red
        case .done: return Theme.green
        case .idle: return tab.isRunning ? Theme.green.opacity(0.5) : Theme.textDim
        }
    }

    var body: some View {
        Button(action: { manager.selectedGroupPath = nil; manager.focusSingleTab = true; manager.selectTab(tab.id) }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                        .shadow(color: statusColor.opacity(0.5), radius: tab.isRunning ? 3 : 0)
                    Text(tab.projectName)
                        .font(Theme.mono(11, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                    Spacer()
                    if let idx = manager.userVisibleTabs.firstIndex(where: { $0.id == tab.id }), idx < 9 {
                        Text("Cmd+\(idx + 1)").font(Theme.mono(7, weight: .medium))
                            .foregroundColor(Theme.textDim).opacity(isSelected ? 0.7 : 0.3)
                    }
                    if isSelected {
                        Button(action: { manager.removeTab(tab.id) }) {
                            Image(systemName: "xmark").font(Theme.mono(7, weight: .bold))
                                .foregroundColor(Theme.textDim).padding(2)
                        }.buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 10)
                        if isEditingName {
                            TextField("이름", text: $editName).textFieldStyle(.plain)
                                .font(Theme.mono(10, weight: .bold)).foregroundColor(tab.workerColor).frame(width: 60)
                                .onSubmit {
                                    if !editName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        tab.workerName = editName.trimmingCharacters(in: .whitespaces)
                                    }
                                    isEditingName = false
                                }
                        } else {
                            Text(tab.workerName).font(Theme.monoSmall).foregroundColor(tab.workerColor)
                                .onTapGesture(count: 2) { editName = tab.workerName; isEditingName = true }
                        }
                    }
                    if tab.sessionCount > 1 {
                        Text("x\(tab.sessionCount)").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.cyan)
                    }
                    if tab.isCompleted {
                        Label("완료", systemImage: "checkmark.circle.fill")
                            .font(Theme.mono(8, weight: .semibold)).foregroundColor(Theme.green)
                    } else if tab.claudeActivity != .idle {
                        Text(tab.claudeActivity.rawValue)
                            .font(Theme.mono(8)).foregroundColor(activityColor(tab.claudeActivity))
                    }
                    Spacer()
                    if tab.tokensUsed > 0 {
                        Text(formatTokens(tab.tokensUsed)).font(Theme.monoTiny).foregroundColor(Theme.textDim)
                    }
                }

                if tab.gitInfo.isGitRepo {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch").font(Theme.mono(8)).foregroundColor(Theme.cyan.opacity(0.6))
                        Text(tab.gitInfo.branch).font(Theme.monoTiny).foregroundColor(Theme.cyan.opacity(0.7)).lineLimit(1)
                        if tab.gitInfo.changedFiles > 0 {
                            Text("+\(tab.gitInfo.changedFiles)").font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.yellow.opacity(0.8))
                        }
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Theme.bgSelected : Theme.bgSurface.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Theme.accent.opacity(0.3) : .clear, lineWidth: 1)))
        }.buttonStyle(.plain)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000.0) }
        return "\(count)"
    }

    private func activityColor(_ activity: ClaudeActivity) -> Color {
        switch activity {
        case .thinking: return Theme.purple
        case .reading: return Theme.accent
        case .writing: return Theme.green
        case .searching: return Theme.cyan
        case .running: return Theme.yellow
        case .done: return Theme.green
        case .error: return Theme.red
        case .idle: return Theme.textDim
        }
    }
}

// MARK: - Drag & Drop

struct TabDropDelegate: DropDelegate {
    let tabId: String
    let manager: SessionManager
    @Binding var draggingTabId: String?

    func performDrop(info: DropInfo) -> Bool { draggingTabId = nil; return true }
    func dropEntered(info: DropInfo) {
        guard let dragging = draggingTabId, dragging != tabId,
              let fromIndex = manager.tabs.firstIndex(where: { $0.id == dragging }),
              let toIndex = manager.tabs.firstIndex(where: { $0.id == tabId }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            manager.tabs.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}

// MARK: - Session History

struct SessionHistoryView: View {
    @State private var history: [SavedSession] = []
    @State private var lastSaved: Date?
    @EnvironmentObject var manager: SessionManager

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.border).frame(height: 1)
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Text("HISTORY").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(2)
                    }
                    Spacer()
                    if let saved = lastSaved {
                        Text(timeAgo(saved)).font(Theme.monoTiny).foregroundColor(Theme.textDim)
                    }
                }
                if history.isEmpty {
                    Text("이전 기록 없음").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                } else {
                    ForEach(history.prefix(5), id: \.projectPath) { session in
                        HStack(spacing: 6) {
                            Circle().fill(session.isCompleted ? Theme.green : Theme.textDim).frame(width: 5, height: 5)
                            Text(session.projectName).font(Theme.monoSmall).foregroundColor(Theme.textSecondary).lineLimit(1)
                            Spacer()
                            if session.tokensUsed > 0 {
                                Text(formatTokens(session.tokensUsed)).font(Theme.monoTiny).foregroundColor(Theme.textDim)
                            }
                            if !manager.userVisibleTabs.contains(where: { $0.projectPath == session.projectPath }) {
                                Button(action: {
                                    if manager.manualLaunchCapacity > 0 {
                                        manager.addTab(projectName: session.projectName, projectPath: session.projectPath, branch: session.branch, manualLaunch: true)
                                    } else {
                                        manager.notifyManualLaunchCapacity()
                                    }
                                }) {
                                    Image(systemName: "arrow.counterclockwise").font(Theme.monoTiny).foregroundColor(Theme.accent)
                                }.buttonStyle(.plain).help("세션 재시작")
                            }
                        }
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 8)
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .onAppear(perform: reloadHistory)
        .onReceive(NotificationCenter.default.publisher(for: .workmanSessionStoreDidChange)) { _ in
            reloadHistory()
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000.0) }
        return "\(count)"
    }
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "방금" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        return "\(Int(interval / 86400))일 전"
    }

    private func reloadHistory() {
        history = SessionStore.shared.load()
        lastSaved = SessionStore.shared.loadLastSaved()
    }
}
