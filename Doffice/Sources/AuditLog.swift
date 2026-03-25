import Foundation
import SwiftUI

enum AuditEventType: String, Codable, CaseIterable {
    case bashCommand = "Bash"
    case fileRead = "Read"
    case fileWrite = "Write"
    case fileEdit = "Edit"
    case permissionApproval = "권한승인"
    case permissionDenial = "권한거부"
    case sessionStart = "세션시작"
    case sessionEnd = "세션종료"
    case costWarning = "비용경고"
    case dangerousCommand = "위험명령"
    case sensitiveFileAccess = "민감파일"
    case sleepWorkStart = "슬립워크시작"
    case sleepWorkEnd = "슬립워크종료"

    var icon: String {
        switch self {
        case .bashCommand: return "terminal"
        case .fileRead: return "doc.text"
        case .fileWrite: return "doc.text.fill"
        case .fileEdit: return "pencil"
        case .permissionApproval: return "checkmark.shield"
        case .permissionDenial: return "xmark.shield"
        case .sessionStart: return "play.circle"
        case .sessionEnd: return "stop.circle"
        case .costWarning: return "exclamationmark.triangle"
        case .dangerousCommand: return "exclamationmark.octagon"
        case .sensitiveFileAccess: return "lock.shield"
        case .sleepWorkStart: return "moon"
        case .sleepWorkEnd: return "sun.max"
        }
    }

    var color: Color {
        switch self {
        case .bashCommand: return Theme.accent
        case .fileRead: return Theme.cyan
        case .fileWrite, .fileEdit: return Theme.green
        case .permissionApproval: return Theme.green
        case .permissionDenial: return Theme.orange
        case .sessionStart: return Theme.accent
        case .sessionEnd: return Theme.textDim
        case .costWarning: return Theme.yellow
        case .dangerousCommand: return Theme.red
        case .sensitiveFileAccess: return Theme.orange
        case .sleepWorkStart: return Theme.purple
        case .sleepWorkEnd: return Theme.purple
        }
    }
}

struct AuditEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let tabId: String
    let projectName: String
    let eventType: AuditEventType
    let detail: String
    let isDangerous: Bool

    init(tabId: String, projectName: String, eventType: AuditEventType, detail: String, isDangerous: Bool = false) {
        self.id = UUID()
        self.timestamp = Date()
        self.tabId = tabId
        self.projectName = projectName
        self.eventType = eventType
        self.detail = detail
        self.isDangerous = isDangerous
    }
}

class AuditLog: ObservableObject {
    static let shared = AuditLog()
    private let maxEntries = 5000
    private let saveKey = "WorkManAuditLog"
    private let persistenceQueue = DispatchQueue(label: "workman.audit-log", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    @Published var entries: [AuditEntry] = []
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "auditLogEnabled") }
    }

    private init() {
        self.enabled = UserDefaults.standard.object(forKey: "auditLogEnabled") as? Bool ?? true
        load()
    }

    func log(_ type: AuditEventType, tabId: String, projectName: String, detail: String, isDangerous: Bool = false) {
        guard enabled else { return }
        let entry = AuditEntry(tabId: tabId, projectName: projectName, eventType: type, detail: detail, isDangerous: isDangerous)
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)
            if self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.prefix(self.maxEntries))
            }
            self.scheduleSave()
        }
    }

    func clear() {
        entries.removeAll()
        scheduleSave()
    }

    func exportJSON() -> Data? {
        try? JSONEncoder().encode(entries)
    }

    func filteredEntries(types: Set<AuditEventType>? = nil, dangerousOnly: Bool = false) -> [AuditEntry] {
        entries.filter { entry in
            if dangerousOnly && !entry.isDangerous { return false }
            if let types = types, !types.contains(entry.eventType) { return false }
            return true
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = entries
        let key = saveKey
        let workItem = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        saveWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let loaded = try? JSONDecoder().decode([AuditEntry].self, from: data) else { return }
        entries = loaded
    }
}
