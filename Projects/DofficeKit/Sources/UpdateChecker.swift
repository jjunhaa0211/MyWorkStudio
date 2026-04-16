import SwiftUI
import Foundation
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Auto Update Checker (GitHub Release 직접 다운로드)
// ═══════════════════════════════════════════════════════

public class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    // 상태
    public enum UpdateState: Equatable {
        case idle
        case checking
        case noUpdate
        case available
        case downloading(progress: Double)
        case extracting
        case readyToInstall
        case installing
        case failed(message: String)
    }

    @Published public var state: UpdateState = .idle
    @Published public var latestVersion: String = ""
    @Published public var currentVersion: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var downloadURL: String = ""

    /// 바이너리 버전 불일치로 건너뛴 태그 (같은 태그를 반복 다운로드하지 않기 위함)
    private static let skippedTagKey = "doffice.skippedTagVersion"
    /// 사용자가 의도적으로 건너뛴 버전
    private static let userSkippedVersionKey = "doffice.userSkippedVersion"

    /// 업데이트 준비 완료 시 호출되는 콜백 (UI 레이어에서 시트 자동 표시용)
    public var onReadyToInstall: (() -> Void)?
    /// 앱 종료 시 자동 설치를 위한 콜백
    public var onInstallOnQuit: (() -> Void)?

    public var hasUpdate: Bool {
        switch state {
        case .available, .downloading, .extracting, .readyToInstall, .failed:
            return !latestVersion.isEmpty && isNewer(latestVersion, than: currentVersion)
        default:
            return false
        }
    }

    public var isChecking: Bool { state == .checking }

    /// 다운로드 진행률 (타이틀바 표시용)
    public var downloadProgress: Double? {
        if case .downloading(let progress) = state { return progress }
        return nil
    }

    // GitHub repo 정보
    private let owner = "jjunhaa0211"
    private let repo = "Doffice"

    private var downloadTask: URLSessionDownloadTask?
    private var downloadDelegate: DownloadDelegate?
    private var downloadSession: URLSession?
    private var downloadedAppURL: URL?

    // 재시도 관련
    private var retryCount = 0
    private var retryTimer: Timer?

    // 주기적 재체크 타이머
    private var recheckTimer: Timer?

    // Sleep/wake 옵저버 참조 (deinit에서 제거용)
    private var sleepWakeObserver: NSObjectProtocol?

    // Rate limit 해제 시점
    private var rateLimitResetDate: Date?

    // 사용자가 현재 세션에서 "나중에"를 눌렀는지
    private var userDismissedThisSession = false

    // 상수 (DofficeKit은 App 모듈의 AppConstants에 접근 불가 → 자체 정의)
    private static let recheckInterval: TimeInterval = 4 * 60 * 60   // 4시간
    private static let retryBaseDelay: TimeInterval = 5.0
    private static let downloadTimeout: TimeInterval = 300            // 5분
    private static let maxRetries: Int = 3

    public init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        setupPeriodicRecheck()
        setupSleepWakeObserver()
    }

    deinit {
        recheckTimer?.invalidate()
        retryTimer?.invalidate()
        if let sleepWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepWakeObserver)
        }
    }

    // MARK: - 주기적 재체크 & 슬립 복귀 감지

    private func setupPeriodicRecheck() {
        recheckTimer = Timer.scheduledTimer(withTimeInterval: Self.recheckInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkForUpdatesIfIdle()
            }
        }
    }

    private func setupSleepWakeObserver() {
        sleepWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 슬립 해제 후 10초 대기 (네트워크 안정화) 후 재체크
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self?.checkForUpdatesIfIdle()
            }
        }
    }

    /// idle/noUpdate/failed 상태에서만 체크 (다운로드/설치 중에는 방해하지 않음)
    private func checkForUpdatesIfIdle() {
        switch state {
        case .idle, .noUpdate, .failed: checkForUpdates()
        default: break
        }
    }

    // MARK: - 사용자 "이 버전 건너뛰기"

    public func skipThisVersion() {
        guard !latestVersion.isEmpty else { return }
        PersistenceService.shared.set(latestVersion, forKey: Self.userSkippedVersionKey)
        PersistenceService.shared.synchronize()
        cancelDownload()
        state = .noUpdate
        print("[도피스] 사용자가 v\(latestVersion) 건너뛰기 선택")
    }

    /// 사용자가 현재 세션에서 "나중에" 버튼을 눌렀을 때 호출
    public func dismissForThisSession() {
        userDismissedThisSession = true
    }

    // MARK: - 앱 종료 시 자동 설치

    /// 앱 종료 전 호출 — readyToInstall 상태면 자동으로 설치 진행
    public func installOnQuitIfReady() {
        guard state == .readyToInstall, downloadedAppURL != nil else { return }
        installAndRestart()
    }

    // MARK: - 버전 확인

    public func checkForUpdates() {
        // idle, noUpdate, available, failed 상태에서만 체크 허용
        switch state {
        case .idle, .noUpdate, .available, .failed: break
        default: return
        }

        // Rate limit 중이면 스킵
        if let resetDate = rateLimitResetDate, Date() < resetDate {
            print("[도피스] Rate limit 대기 중 (해제: \(resetDate))")
            state = .noUpdate
            return
        }

        state = .checking
        retryCount = 0

        performCheckRequest()
    }

    private func performCheckRequest() {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            state = .idle
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }

                // Rate limit 체크 (403 또는 429)
                if let httpResponse = response as? HTTPURLResponse,
                   (httpResponse.statusCode == 403 || httpResponse.statusCode == 429) {
                    self.handleRateLimit(response: httpResponse)
                    return
                }

                if let error {
                    self.handleCheckError(error.localizedDescription)
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.handleCheckError(NSLocalizedString("update.parse.error", comment: ""))
                    return
                }

                // draft/prerelease 체크
                let isDraft = json["draft"] as? Bool ?? false
                let isPrerelease = json["prerelease"] as? Bool ?? false
                if isDraft || isPrerelease {
                    self.state = .noUpdate
                    return
                }

                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                self.latestVersion = version
                self.releaseNotes = json["body"] as? String ?? ""

                // .zip 다운로드 URL 추출 (macOS용)
                self.downloadURL = ""
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           name.hasSuffix(".zip"),
                           let url = asset["browser_download_url"] as? String {
                            self.downloadURL = url
                            break
                        }
                    }
                    // .zip 없으면 .dmg
                    if self.downloadURL.isEmpty {
                        for asset in assets {
                            if let name = asset["name"] as? String,
                               name.hasSuffix(".dmg"),
                               let url = asset["browser_download_url"] as? String {
                                self.downloadURL = url
                                break
                            }
                        }
                    }
                }

                // 사용자가 건너뛴 버전인지 확인
                let userSkipped = PersistenceService.shared.string(forKey: Self.userSkippedVersionKey) ?? ""
                if version == userSkipped {
                    self.state = .noUpdate
                    print("[도피스] 사용자가 건너뛴 버전: v\(version)")
                    return
                }

                // 바이너리 버전 불일치로 이미 건너뛴 태그인지 확인
                let skippedTag = PersistenceService.shared.string(forKey: Self.skippedTagKey) ?? ""
                if version == skippedTag {
                    self.state = .noUpdate
                    print("[도피스] 이미 확인된 태그(바이너리 버전 불일치): v\(version)")
                } else if self.isNewer(version, than: self.currentVersion) {
                    self.state = .available
                    print("[도피스] 업데이트 발견: v\(self.currentVersion) → v\(version)")
                    // 백그라운드 자동 다운로드 시작
                    self.retryCount = 0
                    self.performUpdate()
                } else {
                    self.state = .noUpdate
                    print("[도피스] 최신 버전 사용 중: v\(self.currentVersion)")
                }
            }
        }.resume()
    }

    // MARK: - Rate Limit 처리

    private func handleRateLimit(response: HTTPURLResponse) {
        if let resetTimestamp = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let timestamp = TimeInterval(resetTimestamp) {
            rateLimitResetDate = Date(timeIntervalSince1970: timestamp)
            print("[도피스] GitHub API rate limit — 해제 시점: \(rateLimitResetDate!)")
        } else {
            // 헤더 없으면 1시간 후 재시도
            rateLimitResetDate = Date().addingTimeInterval(3600)
        }
        // 사용자에게 에러를 보여주지 않고 조용히 처리
        state = .noUpdate
    }

    // MARK: - 에러 처리 & 재시도

    private func handleCheckError(_ message: String) {
        retryCount += 1
        if retryCount <= Self.maxRetries {
            let delay = Self.retryBaseDelay * pow(3.0, Double(retryCount - 1))  // 5s → 15s → 45s
            print("[도피스] 업데이트 확인 실패 (\(retryCount)/\(Self.maxRetries)), \(delay)초 후 재시도: \(message)")
            state = .checking  // 재시도 중에는 checking 상태 유지
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.performCheckRequest()
                }
            }
        } else {
            print("[도피스] 업데이트 확인 최종 실패: \(message)")
            state = .failed(message: friendlyErrorMessage(message))
            retryCount = 0
        }
    }

    private func handleDownloadError(_ message: String) {
        retryCount += 1
        if retryCount <= Self.maxRetries {
            let delay = Self.retryBaseDelay * pow(3.0, Double(retryCount - 1))
            print("[도피스] 다운로드 실패 (\(retryCount)/\(Self.maxRetries)), \(delay)초 후 재시도: \(message)")
            state = .downloading(progress: 0)  // 재시도 중에는 downloading 상태 유지
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.performUpdate()
                }
            }
        } else {
            print("[도피스] 다운로드 최종 실패: \(message)")
            state = .failed(message: friendlyErrorMessage(message))
            retryCount = 0
        }
    }

    /// 기술적 에러 메시지를 사용자 친화적 메시지로 변환
    private func friendlyErrorMessage(_ technical: String) -> String {
        let lowered = technical.lowercased()
        if lowered.contains("timed out") || lowered.contains("timeout") {
            return NSLocalizedString("update.error.timeout", comment: "서버 응답 시간 초과")
        }
        if lowered.contains("not connected") || lowered.contains("network") || lowered.contains("internet") {
            return NSLocalizedString("update.error.network", comment: "인터넷 연결 확인")
        }
        if lowered.contains("no space") || lowered.contains("disk") {
            return NSLocalizedString("update.error.disk", comment: "디스크 공간 부족")
        }
        // 기본: 원본 메시지 사용하되 간결하게
        return technical
    }

    // MARK: - 다운로드 & 설치

    public func performUpdate() {
        guard !downloadURL.isEmpty, let url = URL(string: downloadURL) else {
            state = .failed(message: NSLocalizedString("update.no.download.url", comment: ""))
            return
        }

        state = .downloading(progress: 0)
        downloadedAppURL = nil

        let delegate = DownloadDelegate { [weak self] progress in
            DispatchQueue.main.async {
                self?.state = .downloading(progress: progress)
            }
        } onComplete: { [weak self] tempURL, error in
            DispatchQueue.main.async {
                self?.handleDownloadComplete(tempURL: tempURL, error: error)
            }
        }
        self.downloadDelegate = delegate

        // 이전 세션이 있으면 정리 (URLSession은 delegate를 강하게 참조하므로 반드시 invalidate)
        downloadSession?.invalidateAndCancel()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = Self.downloadTimeout  // 5분 타임아웃
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        downloadSession = session
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
        print("[도피스] 다운로드 시작: \(downloadURL)")
    }

    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadDelegate = nil
        downloadSession?.invalidateAndCancel()
        downloadSession = nil
        retryTimer?.invalidate()
        retryCount = 0
        state = .available
    }

    private func handleDownloadComplete(tempURL: URL?, error: Error?) {
        if let error {
            // 사용자 취소는 재시도하지 않음
            if (error as NSError).code == NSURLErrorCancelled { return }
            handleDownloadError(error.localizedDescription)
            return
        }
        guard let tempURL else {
            handleDownloadError(NSLocalizedString("update.file.not.found", comment: ""))
            return
        }

        // 다운로드 성공 — 재시도 카운터 초기화
        retryCount = 0
        state = .extracting
        print("[도피스] 다운로드 완료, 압축 해제 중...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.extractAndPrepare(zipURL: tempURL)
            // 다운로드 zip 정리
            try? FileManager.default.removeItem(at: tempURL)
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let appURL):
                    // 다운로드된 앱의 실제 버전 확인 (태그와 바이너리 버전 불일치 방지)
                    let downloadedPlist = appURL.appendingPathComponent("Contents/Info.plist")
                    if let plistData = NSDictionary(contentsOf: downloadedPlist),
                       let downloadedVersion = plistData["CFBundleShortVersionString"] as? String,
                       !self.isNewer(downloadedVersion, than: self.currentVersion) {
                        print("[도피스] 다운로드된 앱 버전(\(downloadedVersion))이 현재(\(self.currentVersion))와 동일 — 이 태그 건너뜀")
                        // 이 태그만 건너뛰도록 기록 (다음 새 릴리스는 정상 처리)
                        PersistenceService.shared.set(self.latestVersion, forKey: Self.skippedTagKey)
                        PersistenceService.shared.synchronize()
                        self.state = .noUpdate
                        try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent())
                        return
                    }
                    self.downloadedAppURL = appURL
                    self.state = .readyToInstall
                    print("[도피스] 설치 준비 완료: \(appURL.path)")

                    // 콜백으로 UI에 알림 (사용자가 이번 세션에서 dismiss하지 않은 경우만)
                    if !self.userDismissedThisSession {
                        self.onReadyToInstall?()
                    }

                case .failure(let error):
                    self.handleDownloadError(error.localizedDescription)
                case .none:
                    self.state = .failed(message: NSLocalizedString("update.unknown.error", comment: ""))
                }
            }
        }
    }

    private func extractAndPrepare(zipURL: URL) -> Result<URL, Error> {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("doffice-update-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // unzip 실행
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            proc.arguments = ["-o", "-q", zipURL.path, "-d", tempDir.path]
            try proc.run()
            proc.waitUntilExit()

            guard proc.terminationStatus == 0 else {
                return .failure(NSError(domain: "UpdateChecker", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "unzip 종료 코드: \(proc.terminationStatus)"
                ]))
            }

            // .app 번들 찾기
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            if let app = contents.first(where: { $0.pathExtension == "app" }) {
                return .success(app)
            }

            // 하위 디렉토리에서 찾기
            for dir in contents where dir.hasDirectoryPath {
                let subContents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                if let app = subContents.first(where: { $0.pathExtension == "app" }) {
                    return .success(app)
                }
            }

            // .app을 찾지 못했으면 임시 디렉토리 정리
            try? FileManager.default.removeItem(at: tempDir)
            return .failure(NSError(domain: "UpdateChecker", code: 2, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("update.no.app.found", comment: "")
            ]))
        } catch {
            // 실패 시 임시 디렉토리 정리
            try? FileManager.default.removeItem(at: tempDir)
            return .failure(error)
        }
    }

    // MARK: - 설치 (현재 앱 교체 후 재시작)

    public func installAndRestart() {
        guard let newAppURL = downloadedAppURL else {
            state = .failed(message: NSLocalizedString("update.install.not.found", comment: ""))
            return
        }

        // 번들 구조 검증
        let macOSDir = newAppURL.appendingPathComponent("Contents/MacOS")
        let infoPlist = newAppURL.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: macOSDir.path),
              FileManager.default.fileExists(atPath: infoPlist.path) else {
            state = .failed(message: NSLocalizedString("update.bundle.corrupted", comment: "다운로드된 앱 번들이 손상되었습니다."))
            return
        }

        // 디스크 공간 확인 (앱 번들 크기의 2배 필요)
        if let appSize = directorySize(url: newAppURL),
           let freeSpace = try? FileManager.default.attributesOfFileSystem(forPath: Bundle.main.bundlePath)[.systemFreeSize] as? Int64,
           freeSpace < appSize * 2 {
            state = .failed(message: NSLocalizedString("update.error.disk", comment: ""))
            return
        }

        // 코드서명 검증 (실패해도 경고만 — ad-hoc 빌드 허용)
        let codesignProc = Process()
        codesignProc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        codesignProc.arguments = ["--verify", "--deep", "--strict", newAppURL.path]
        codesignProc.standardOutput = nil
        codesignProc.standardError = nil
        if let _ = try? codesignProc.run() {
            codesignProc.waitUntilExit()
            if codesignProc.terminationStatus != 0 {
                CrashLogger.shared.warning("Update: codesign verification failed for \(newAppURL.lastPathComponent) (status=\(codesignProc.terminationStatus)) — proceeding anyway")
            }
        }

        state = .installing

        // 실제 설치 시 건너뛴 태그 기록 초기화
        PersistenceService.shared.removeObject(forKey: Self.skippedTagKey)
        PersistenceService.shared.removeObject(forKey: Self.userSkippedVersionKey)
        PersistenceService.shared.synchronize()

        let currentAppURL = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier
        let logFile = FileManager.default.temporaryDirectory.appendingPathComponent("doffice-updater.log").path
        let updateTempDir = newAppURL.deletingLastPathComponent().path

        // 설치 스크립트: PID 대기 → 백업 → ditto 복사 → 검증 → 실행 → 정리
        let script = """
        #!/bin/zsh
        set -euo pipefail
        exec > "\(logFile)" 2>&1
        echo "[updater] 시작: $(date)"
        echo "[updater] PID \(pid) 종료 대기..."

        # PID 기반 종료 대기 (최대 30초)
        for i in {1..60}; do
            kill -0 \(pid) 2>/dev/null || break
            sleep 0.5
        done
        sleep 1

        CURRENT="\(currentAppURL.path)"
        NEW="\(newAppURL.path)"
        BACKUP="${CURRENT}.backup"

        echo "[updater] 백업 생성: $BACKUP"
        rm -rf "$BACKUP"
        if ! mv "$CURRENT" "$BACKUP"; then
            echo "[updater] 백업 실패 — 복원 불필요"
            open -n "$CURRENT" || "${CURRENT}/Contents/MacOS/Doffice" &
            exit 1
        fi

        echo "[updater] ditto 복사: $NEW → $CURRENT"
        if ! /usr/bin/ditto "$NEW" "$CURRENT"; then
            echo "[updater] 복사 실패 — 백업에서 복원"
            rm -rf "$CURRENT"
            mv "$BACKUP" "$CURRENT"
            open -n "$CURRENT" || "${CURRENT}/Contents/MacOS/Doffice" &
            exit 1
        fi

        # quarantine 제거
        /usr/bin/xattr -cr "$CURRENT" 2>/dev/null || true

        # 복사된 앱 번들 검증
        if [ ! -d "${CURRENT}/Contents/MacOS" ]; then
            echo "[updater] 앱 번들 검증 실패 — 백업에서 복원"
            rm -rf "$CURRENT"
            mv "$BACKUP" "$CURRENT"
            open -n "$CURRENT" || "${CURRENT}/Contents/MacOS/Doffice" &
            exit 1
        fi

        # LaunchServices에 새 앱 등록 (캐시 갱신)
        /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$CURRENT" 2>/dev/null || true

        echo "[updater] 새 앱 실행"
        # open -n 대신 바이너리 직접 실행 (LaunchServices가 다른 앱을 열 수 있으므로)
        BINARY="${CURRENT}/Contents/MacOS/Doffice"
        if [ -x "$BINARY" ]; then
            "$BINARY" &
        else
            open -n "$CURRENT"
        fi

        # 정리 (백업 + 임시 다운로드)
        sleep 3
        rm -rf "$BACKUP"
        rm -rf "\(updateTempDir)"
        echo "[updater] 완료: $(date)"
        """

        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("doffice-updater.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = [scriptURL.path]
            proc.standardOutput = nil
            proc.standardError = nil
            try proc.run()

            // 스크립트가 실행된 것을 확인 후 정상 종료 (세션 저장 등 shutdown 시퀀스 실행)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            state = .failed(message: String(format: NSLocalizedString("update.install.script.failed", comment: ""), error.localizedDescription))
        }
    }

    public func openReleasePage() {
        if let url = URL(string: "https://github.com/\(owner)/\(repo)/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    public func resetState() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadDelegate = nil
        downloadSession?.invalidateAndCancel()
        downloadSession = nil
        downloadedAppURL = nil
        retryTimer?.invalidate()
        retryCount = 0
        state = .idle
    }

    // MARK: - Helpers

    private func directorySize(url: URL) -> Int64? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return nil }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else { continue }
            totalSize += Int64(size)
        }
        return totalSize
    }

    // MARK: - Version Comparison

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
}

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    public let onProgress: (Double) -> Void
    public let onComplete: (URL?, Error?) -> Void

    public init(onProgress: @escaping (Double) -> Void, onComplete: @escaping (URL?, Error?) -> Void) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 임시 위치에서 안전한 곳으로 복사 (콜백 리턴 후 삭제되므로)
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("doffice-download-\(UUID().uuidString).zip")
        do {
            try FileManager.default.copyItem(at: location, to: dest)
            session.finishTasksAndInvalidate()
            onComplete(dest, nil)
        } catch {
            session.finishTasksAndInvalidate()
            onComplete(nil, error)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, (error as NSError).code != NSURLErrorCancelled {
            session.finishTasksAndInvalidate()
            onComplete(nil, error)
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Update Sheet UI
// ═══════════════════════════════════════════════════════

public struct UpdateSheet: View {
    @ObservedObject var updater = UpdateChecker.shared
    @Environment(\.dismiss) var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            headerView
            versionCompareView
            releaseNotesView
            stateView
            actionButtons
        }
        .padding(24)
        .frame(width: 440)
        .background(Theme.bgCard)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(stateColor.opacity(0.1)).frame(width: 56, height: 56)
                Image(systemName: stateIcon)
                    .font(.system(size: Theme.iconSize(26)))
                    .foregroundColor(stateColor)
            }
            Text(stateTitle)
                .font(Theme.mono(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
        }
    }

    private var stateColor: Color {
        switch updater.state {
        case .available, .noUpdate, .idle, .checking: return Theme.green
        case .downloading, .extracting: return Theme.accent
        case .readyToInstall: return Theme.green
        case .installing: return Theme.purple
        case .failed: return Theme.red
        }
    }

    private var stateIcon: String {
        switch updater.state {
        case .idle, .checking: return "arrow.down.app.fill"
        case .noUpdate: return "checkmark.circle.fill"
        case .available: return "arrow.down.app.fill"
        case .downloading: return "arrow.down.circle"
        case .extracting: return "doc.zipper"
        case .readyToInstall: return "checkmark.seal.fill"
        case .installing: return "gear.badge.checkmark"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var stateTitle: String {
        switch updater.state {
        case .idle, .checking: return NSLocalizedString("update.state.checking", comment: "")
        case .noUpdate: return NSLocalizedString("update.state.latest", comment: "")
        case .available: return NSLocalizedString("update.state.available", comment: "")
        case .downloading: return NSLocalizedString("update.state.downloading", comment: "")
        case .extracting: return NSLocalizedString("update.state.extracting", comment: "")
        case .readyToInstall: return NSLocalizedString("update.state.ready", comment: "")
        case .installing: return NSLocalizedString("update.state.installing", comment: "")
        case .failed: return NSLocalizedString("update.state.failed", comment: "")
        }
    }

    // MARK: - Version Compare

    private var versionCompareView: some View {
        Group {
            if updater.state == .noUpdate {
                // 최신 버전일 때는 현재 버전만 표시
                VStack(spacing: 4) {
                    Text(NSLocalizedString("update.label.current", comment: "")).font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    Text("v\(updater.currentVersion)")
                        .font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.green)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.green.opacity(0.2), lineWidth: 1))
            } else {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("update.label.current", comment: "")).font(Theme.mono(9)).foregroundColor(Theme.textDim)
                        Text("v\(updater.currentVersion)")
                            .font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.textSecondary)
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: Theme.iconSize(14)))
                        .foregroundColor(Theme.green)
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("update.label.latest", comment: "")).font(Theme.mono(9)).foregroundColor(Theme.textDim)
                        Text("v\(updater.latestVersion.isEmpty ? "..." : updater.latestVersion)")
                            .font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.green)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.green.opacity(0.2), lineWidth: 1))
            }
        }
    }

    // MARK: - Release Notes

    @ViewBuilder
    private var releaseNotesView: some View {
        if !updater.releaseNotes.isEmpty && updater.state != .noUpdate {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("update.release.notes", comment: "")).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                ScrollView {
                    Text(updater.releaseNotes)
                        .font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 120)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5))
        }
    }

    // MARK: - State View

    @ViewBuilder
    private var stateView: some View {
        switch updater.state {
        case .checking:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text(NSLocalizedString("update.checking.msg", comment: ""))
                    .font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
            }

        case .downloading(let progress):
            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .tint(Theme.accent)
                HStack {
                    Text(NSLocalizedString("update.downloading.msg", comment: ""))
                        .font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(Theme.mono(10, weight: .bold)).foregroundStyle(Theme.accentBackground)
                }
            }

        case .extracting:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text(NSLocalizedString("update.extracting.msg", comment: ""))
                    .font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
            }

        case .readyToInstall:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.green)
                Text(NSLocalizedString("update.ready.msg", comment: ""))
                    .font(Theme.mono(9)).foregroundColor(Theme.green)
            }

        case .installing:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text(NSLocalizedString("update.installing.msg", comment: ""))
                    .font(Theme.mono(10)).foregroundColor(Theme.purple)
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.red)
                    Text(message).font(Theme.mono(9)).foregroundColor(Theme.red)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch updater.state {
        case .available:
            HStack(spacing: 10) {
                Button(action: {
                    updater.dismissForThisSession()
                    dismiss()
                }) {
                    Text(NSLocalizedString("update.later", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                }.buttonStyle(.plain).keyboardShortcut(.escape)

                Button(action: { updater.skipThisVersion(); dismiss() }) {
                    Text(NSLocalizedString("update.skip.version", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                }.buttonStyle(.plain)

                Button(action: { updater.performUpdate() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: Theme.iconSize(10)))
                        Text(NSLocalizedString("update.now", comment: "")).font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green))
                }.buttonStyle(.plain).keyboardShortcut(.return)
            }

        case .downloading:
            Button(action: { updater.cancelDownload() }) {
                Text(NSLocalizedString("update.cancel", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
            }.buttonStyle(.plain)

        case .readyToInstall:
            HStack(spacing: 10) {
                Button(action: {
                    updater.dismissForThisSession()
                    dismiss()
                }) {
                    Text(NSLocalizedString("update.apply.on.quit", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                }.buttonStyle(.plain)

                Button(action: { updater.installAndRestart() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.system(size: Theme.iconSize(10)))
                        Text(NSLocalizedString("update.restart.now", comment: "")).font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green))
                }.buttonStyle(.plain).keyboardShortcut(.return)
            }

        case .failed:
            HStack(spacing: 10) {
                Button(action: { dismiss() }) {
                    Text(NSLocalizedString("update.close", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                }.buttonStyle(.plain).keyboardShortcut(.escape)

                Button(action: { updater.openReleasePage() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "safari").font(.system(size: Theme.iconSize(9)))
                        Text(NSLocalizedString("update.manual.download", comment: "")).font(Theme.mono(10))
                    }
                    .foregroundStyle(Theme.accentBackground)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
                }.buttonStyle(.plain)

                Button(action: { updater.checkForUpdates() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: Theme.iconSize(10)))
                        Text(NSLocalizedString("update.retry", comment: "")).font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentBackground))
                }.buttonStyle(.plain).keyboardShortcut(.return)
            }

        case .installing:
            Button(action: { dismiss() }) {
                Text(NSLocalizedString("update.close", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
            }.buttonStyle(.plain).keyboardShortcut(.escape)

        case .noUpdate:
            Button(action: { dismiss() }) {
                Text(NSLocalizedString("update.ok", comment: "")).font(Theme.mono(10, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentBackground))
            }.buttonStyle(.plain).keyboardShortcut(.return)

        default:
            EmptyView()
        }
    }
}
