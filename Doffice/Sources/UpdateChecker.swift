import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Auto Update Checker (Homebrew 기반)
// ═══════════════════════════════════════════════════════

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestVersion: String = ""
    @Published var currentVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var downloadURL: String = ""
    @Published var hasUpdate: Bool = false
    @Published var isChecking: Bool = false
    @Published var isUpdating: Bool = false
    @Published var updateError: String?
    @Published var updateSuccess: Bool = false

    // GitHub repo 정보
    private let owner = "jjunhaa0211"
    private let repo = "MyWorkStudio"

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - 버전 확인

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        updateError = nil

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false

                if let error = error {
                    self.updateError = "네트워크 오류: \(error.localizedDescription)"
                    // 네트워크 실패 시 brew로 폴백
                    self.checkViaBrew()
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    // GitHub API 실패 시 brew로 폴백
                    self.checkViaBrew()
                    return
                }

                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                self.latestVersion = version
                self.releaseNotes = json["body"] as? String ?? ""

                // 다운로드 URL 추출
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           (name.hasSuffix(".dmg") || name.hasSuffix(".zip") || name.hasSuffix(".tar.gz")),
                           let url = asset["browser_download_url"] as? String {
                            self.downloadURL = url
                            break
                        }
                    }
                }

                self.hasUpdate = self.isNewer(self.latestVersion, than: self.currentVersion)

                if self.hasUpdate {
                    print("[도피스] 업데이트 발견: \(self.currentVersion) → \(self.latestVersion)")
                } else {
                    print("[도피스] 최신 버전 사용 중: \(self.currentVersion)")
                }
            }
        }.resume()
    }

    // brew info로 최신 버전 확인 (폴백)
    private func checkViaBrew() {
        DispatchQueue.global(qos: .utility).async {
            let result = Self.shell("brew info --json=v2 workman 2>/dev/null || brew info --json=v2 my-work-studio 2>/dev/null")
            DispatchQueue.main.async {
                guard let output = result, !output.isEmpty,
                      let data = output.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let casks = json["casks"] as? [[String: Any]],
                      let cask = casks.first,
                      let version = cask["version"] as? String else {
                    self.updateError = "Homebrew에서 버전 정보를 가져올 수 없습니다."
                    print("[도피스] brew info 실패: \(result ?? "출력 없음")")
                    return
                }
                self.latestVersion = version
                self.hasUpdate = self.isNewer(version, than: self.currentVersion)
            }
        }
    }

    // MARK: - 업데이트 실행

    func performUpdate() {
        guard !isUpdating else { return }
        isUpdating = true
        updateError = nil
        updateSuccess = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 1. brew update
            _ = Self.shell("brew update 2>/dev/null")

            // 2. brew upgrade
            let result = Self.shell("brew upgrade --cask workman 2>&1 || brew upgrade --cask my-work-studio 2>&1")

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isUpdating = false

                if let output = result, (output.contains("upgraded") || output.contains("already installed")) {
                    self.updateSuccess = true
                    self.hasUpdate = false
                    print("[도피스] 업데이트 완료")
                } else if let output = result, output.contains("No available") || output.contains("not found") {
                    // brew에 없으면 직접 다운로드 안내
                    self.updateError = "Homebrew에서 패키지를 찾을 수 없습니다. GitHub에서 직접 다운로드해주세요."
                } else {
                    self.updateError = "업데이트 실패: \(result ?? "알 수 없는 오류")"
                }
            }
        }
    }

    func openReleasePage() {
        if let url = URL(string: "https://github.com/\(owner)/\(repo)/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Helpers

    private func isNewer(_ latest: String, than current: String) -> Bool {
        let lParts = latest.split(separator: ".").compactMap { Int($0) }
        let cParts = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(lParts.count, cParts.count) {
            let l = i < lParts.count ? lParts[i] : 0
            let c = i < cParts.count ? cParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }

    private static func shell(_ command: String) -> String? {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-f", "-c", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = TerminalTab.buildFullPATH()
        proc.environment = env
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Update Available View
// ═══════════════════════════════════════════════════════

struct UpdateSheet: View {
    @ObservedObject var updater = UpdateChecker.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: Theme.iconSize(32))).foregroundColor(Theme.green)
                Text("업데이트 가능")
                    .font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
            }

            // Version info
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("현재").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    Text("v\(updater.currentVersion)")
                        .font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.textSecondary)
                }
                Image(systemName: "arrow.right").font(.system(size: Theme.iconSize(14))).foregroundColor(Theme.green)
                VStack(spacing: 4) {
                    Text("최신").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    Text("v\(updater.latestVersion)")
                        .font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.green)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.green.opacity(0.2), lineWidth: 1)))

            // Release notes
            if !updater.releaseNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("변경 사항").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                    ScrollView {
                        Text(updater.releaseNotes)
                            .font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 120)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgTerminal)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 0.5)))
            }

            // Status messages
            if updater.isUpdating {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("업데이트 중... (brew upgrade)").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                }
            }
            if let error = updater.updateError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.red)
                    Text(error).font(Theme.mono(9)).foregroundColor(Theme.red).lineLimit(3)
                }
            }
            if updater.updateSuccess {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.green)
                    Text("업데이트 완료! 앱을 재시작해주세요.").font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.green)
                }

                Button(action: { restartApp() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.system(size: Theme.iconSize(10)))
                        Text("지금 재시작").font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(Theme.textOnAccent).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green))
                }.buttonStyle(.plain)
            }

            // Action buttons
            if !updater.updateSuccess {
                HStack(spacing: 10) {
                    Button(action: { dismiss() }) {
                        Text("나중에").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 1)))
                    }.buttonStyle(.plain).keyboardShortcut(.escape)

                    Button(action: { updater.openReleasePage() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "safari").font(.system(size: Theme.iconSize(9)))
                            Text("GitHub").font(Theme.mono(10))
                        }
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.3), lineWidth: 1)))
                    }.buttonStyle(.plain)

                    Button(action: { updater.performUpdate() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: Theme.iconSize(10)))
                            Text("brew로 업데이트").font(Theme.mono(10, weight: .bold))
                        }
                        .foregroundColor(Theme.textOnAccent).padding(.horizontal, 16).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green))
                    }.buttonStyle(.plain).keyboardShortcut(.return)
                    .disabled(updater.isUpdating)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Theme.bgCard)
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", path]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }
}
