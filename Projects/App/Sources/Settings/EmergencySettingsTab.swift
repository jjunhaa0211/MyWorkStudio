import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SettingsView {

    var emergencyTab: some View {
        VStack(spacing: Theme.sp4) {
            emergencyHero

            // 1. 전체 긴급 정지
            settingsSection(
                title: NSLocalizedString("emergency.stop.all.title", comment: ""),
                subtitle: NSLocalizedString("emergency.stop.all.subtitle", comment: "")
            ) {
                emergencyStopAllSection
            }

            // 2. 세션 복구
            settingsSection(
                title: NSLocalizedString("emergency.recovery.title", comment: ""),
                subtitle: NSLocalizedString("emergency.recovery.subtitle", comment: "")
            ) {
                recoverySection
            }

            // 3. 진단
            settingsSection(
                title: NSLocalizedString("emergency.diagnostics.title", comment: ""),
                subtitle: NSLocalizedString("emergency.diagnostics.subtitle", comment: "")
            ) {
                diagnosticsSection
            }

            // 4. 앱 초기화
            settingsSection(
                title: NSLocalizedString("emergency.reset.title", comment: ""),
                subtitle: NSLocalizedString("emergency.reset.subtitle", comment: "")
            ) {
                resetSection
            }
        }
    }

    // MARK: - Hero

    private var emergencyHero: some View {
        HStack(spacing: 14) {
            Image(systemName: "light.beacon.max.fill")
                .font(.system(size: Theme.iconSize(22), weight: .bold))
                .foregroundColor(Theme.red)
                .padding(12)
                .background(Circle().fill(Theme.red.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("emergency.title", comment: ""))
                    .font(Theme.mono(14, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                Text(NSLocalizedString("emergency.description", comment: ""))
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .fill(
                    LinearGradient(
                        colors: [Theme.red.opacity(0.08), Theme.bgCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.red.opacity(0.2), lineWidth: 1))
    }

    // MARK: - 1. 전체 긴급 정지

    private var emergencyStopAllSection: some View {
        let manager = SessionManager.shared
        let runningTabs = manager.tabs.filter { $0.isProcessing || $0.isRunning }
        let runningCount = runningTabs.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(runningCount > 0 ? Theme.red : Theme.green)
                    .frame(width: 8, height: 8)
                Text(
                    runningCount > 0
                    ? String(format: NSLocalizedString("emergency.sessions.running", comment: ""), runningCount)
                    : NSLocalizedString("emergency.sessions.idle", comment: "")
                )
                .font(Theme.mono(10, weight: .medium))
                .foregroundColor(runningCount > 0 ? Theme.red : Theme.green)
            }

            // 도피스 세션 정지
            Button(action: {
                for tab in manager.tabs {
                    if tab.isProcessing || tab.isRunning {
                        tab.forceStop()
                    }
                }
                SessionStore.shared.save(tabs: manager.tabs, immediately: true)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: Theme.iconSize(14), weight: .bold))
                    Text(NSLocalizedString("emergency.stop.all.button", comment: ""))
                        .font(Theme.mono(11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.red))
            }
            .buttonStyle(.plain)
            .disabled(runningCount == 0)
            .opacity(runningCount == 0 ? 0.5 : 1.0)

            // 시스템 전체 AI CLI 프로세스 종료
            Button(action: {
                // 도피스 세션 먼저 정리
                for tab in manager.tabs {
                    if tab.isProcessing || tab.isRunning {
                        tab.forceStop()
                    }
                }
                SessionStore.shared.save(tabs: manager.tabs, immediately: true)
                // 시스템 전체 프로세스 kill
                vm.systemKillResult = killAllAIProcesses()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: Theme.iconSize(14), weight: .bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("emergency.kill.system", comment: ""))
                            .font(Theme.mono(11, weight: .bold))
                        Text(NSLocalizedString("emergency.kill.system.detail", comment: ""))
                            .font(Theme.mono(8))
                            .opacity(0.7)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.red.opacity(0.85)))
            }
            .buttonStyle(.plain)

            if let result = vm.systemKillResult {
                Text(result)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.08)))
            }

            // 개별 세션 목록
            if !runningTabs.isEmpty {
                VStack(spacing: 4) {
                    ForEach(runningTabs, id: \.id) { tab in
                        HStack(spacing: 8) {
                            Circle().fill(tab.workerColor).frame(width: 6, height: 6)
                            Text(tab.workerName)
                                .font(Theme.mono(9, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Text(tab.projectName)
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textDim)
                                .lineLimit(1)
                            Spacer()
                            Button(action: { tab.forceStop() }) {
                                Text(NSLocalizedString("emergency.stop", comment: ""))
                                    .font(Theme.mono(8, weight: .bold))
                                    .foregroundColor(Theme.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.red.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
            }
        }
    }

    // MARK: - 2. 세션 복구

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 세션 강제 저장
            emergencyActionRow(
                icon: "arrow.down.doc.fill",
                tint: Theme.green,
                title: NSLocalizedString("emergency.force.save", comment: ""),
                detail: NSLocalizedString("emergency.force.save.detail", comment: "")
            ) {
                SessionStore.shared.save(tabs: SessionManager.shared.tabs, immediately: true)
            }

            // 세션 새로고침
            emergencyActionRow(
                icon: "arrow.clockwise.circle.fill",
                tint: Theme.accent,
                title: NSLocalizedString("emergency.refresh.sessions", comment: ""),
                detail: NSLocalizedString("emergency.refresh.sessions.detail", comment: "")
            ) {
                SessionManager.shared.refresh()
            }

            // Stuck 상태 세션 리셋
            emergencyActionRow(
                icon: "arrow.uturn.backward.circle.fill",
                tint: Theme.orange,
                title: NSLocalizedString("emergency.reset.stuck", comment: ""),
                detail: NSLocalizedString("emergency.reset.stuck.detail", comment: "")
            ) {
                let staleThreshold: TimeInterval = 30
                for tab in SessionManager.shared.tabs {
                    let isStale = Date().timeIntervalSince(tab.lastActivityTime) > staleThreshold
                    if tab.isProcessing && isStale {
                        tab.isProcessing = false
                        tab.claudeActivity = .idle
                        for i in tab.workflowStages.indices where tab.workflowStages[i].state == .running {
                            tab.workflowStages[i].state = .failed
                        }
                        tab.officeSeatLockReason = nil
                        tab.appendBlock(.status(message: NSLocalizedString("emergency.stuck.resolved", comment: "")))
                    }
                }
            }
        }
    }

    // MARK: - 3. 진단

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 진단 리포트
            emergencyActionRow(
                icon: "doc.text.magnifyingglass",
                tint: Theme.purple,
                title: NSLocalizedString("emergency.diagnostic.report", comment: ""),
                detail: NSLocalizedString("emergency.diagnostic.report.detail", comment: "")
            ) {
                DiagnosticReport.shared.exportInteractively()
            }

            // 로그 폴더 열기
            emergencyActionRow(
                icon: "folder.fill",
                tint: Theme.cyan,
                title: NSLocalizedString("emergency.open.logs", comment: ""),
                detail: NSLocalizedString("emergency.open.logs.detail", comment: "")
            ) {
                let logDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("Logs").appendingPathComponent("Doffice")
                if let dir = logDir, FileManager.default.fileExists(atPath: dir.path) {
                    NSWorkspace.shared.open(dir)
                }
            }

            // 메모리 사용량
            HStack(spacing: 8) {
                Image(systemName: "memorychip")
                    .font(.system(size: Theme.iconSize(10)))
                    .foregroundColor(Theme.yellow)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("emergency.memory.usage", comment: ""))
                        .font(Theme.mono(10, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Text(currentMemoryUsage)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("\(SessionManager.shared.tabs.count) \(NSLocalizedString("emergency.tabs", comment: ""))")
                    .font(Theme.mono(9, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: - 4. 앱 초기화

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 자동화 워크플로우 전체 중지
            emergencyActionRow(
                icon: "gearshape.2.fill",
                tint: Theme.orange,
                title: NSLocalizedString("emergency.stop.automation", comment: ""),
                detail: NSLocalizedString("emergency.stop.automation.detail", comment: "")
            ) {
                let manager = SessionManager.shared
                for tab in manager.tabs where tab.automationSourceTabId != nil {
                    if tab.isProcessing || tab.isRunning {
                        tab.forceStop()
                    }
                }
                for tab in manager.tabs {
                    for i in tab.workflowStages.indices where tab.workflowStages[i].state == .running {
                        tab.workflowStages[i].state = .failed
                    }
                    tab.officeSeatLockReason = nil
                }
            }

            // 앱 재시작
            emergencyActionRow(
                icon: "power.circle.fill",
                tint: Theme.red,
                title: NSLocalizedString("emergency.restart.app", comment: ""),
                detail: NSLocalizedString("emergency.restart.app.detail", comment: "")
            ) {
                SessionStore.shared.save(tabs: SessionManager.shared.tabs, immediately: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let url = Bundle.main.bundleURL
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-n", url.path]
                    try? task.run()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func emergencyActionRow(
        icon: String,
        tint: Color,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(10)))
                    .foregroundColor(tint)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.mono(10, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Text(detail)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textDim.opacity(0.5))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var currentMemoryUsage: String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return NSLocalizedString("emergency.memory.unknown", comment: "")
        }
        let mb = Double(info.resident_size) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }

    /// 시스템 전체에서 claude, codex, gemini CLI 프로세스를 찾아 종료
    private func killAllAIProcesses() -> String {
        let cliNames = ["claude", "codex", "gemini"]
        let myPid = ProcessInfo.processInfo.processIdentifier
        var killed: [String] = []

        for name in cliNames {
            let pipe = Pipe()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            proc.arguments = ["-f", name]
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let pids = output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }

                for pid in pids where pid != myPid && pid > 1 {
                    kill(pid, SIGTERM)
                    killed.append("\(name)(\(pid))")
                }

                // 1초 후 아직 살아있으면 SIGKILL
                if !pids.isEmpty {
                    let survivorPids = pids.filter { $0 != myPid && $0 > 1 }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                        for pid in survivorPids {
                            kill(pid, SIGKILL)
                        }
                    }
                }
            } catch {
                CrashLogger.shared.warning("Failed to pgrep \(name): \(error.localizedDescription)")
            }
        }

        if killed.isEmpty {
            return NSLocalizedString("emergency.kill.none", comment: "")
        }
        return String(format: NSLocalizedString("emergency.kill.result", comment: ""), killed.joined(separator: ", "))
    }
}
