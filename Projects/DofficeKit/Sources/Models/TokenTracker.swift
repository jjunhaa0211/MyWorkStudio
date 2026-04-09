import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Token Tracker (일간/주간 토큰 추적)
// ═══════════════════════════════════════════════════════

public class TokenTracker: ObservableObject {
    public static let shared = TokenTracker()
    public static let recommendedDailyLimit = 500_000
    public static let recommendedWeeklyLimit = 2_500_000
    private let saveKey = "DofficeTokenHistory"
    private let automationDailyReserve = 100_000
    private let automationWeeklyReserve = 300_000
    private let globalDailyReserve = 12_000
    private let globalWeeklyReserve = 40_000
    private let emergencyDailyReserve = 6_000
    private let emergencyWeeklyReserve = 20_000
    private let persistenceQueue = DispatchQueue(label: "doffice.token-tracker", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    public struct DayRecord: Codable {
        public var date: String // "yyyy-MM-dd"
        public var inputTokens: Int
        public var outputTokens: Int
        public var cost: Double
        public var totalTokens: Int { inputTokens + outputTokens }
    }

    @Published public var history: [DayRecord] = []

    private var cachedWeekTokens: Int = 0
    private var cachedWeekCost: Double = 0
    private var cachedBillingTokens: Int = 0
    private var cachedBillingCost: Double = 0
    private var cacheTimestamp: Date = .distantPast

    // 사용자 설정 한도
    @AppStorage("dailyTokenLimit") public var dailyTokenLimit: Int = TokenTracker.recommendedDailyLimit
    @AppStorage("weeklyTokenLimit") public var weeklyTokenLimit: Int = TokenTracker.recommendedWeeklyLimit

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init() { load() }

    private var todayKey: String { dateFormatter.string(from: Date()) }

    // MARK: - Record

    public func recordTokens(input: Int, output: Int) {
        guard input > 0 || output > 0 else { return }
        cacheTimestamp = .distantPast
        let key = todayKey
        if let idx = history.firstIndex(where: { $0.date == key }) {
            history[idx].inputTokens += input
            history[idx].outputTokens += output
        } else {
            history.append(DayRecord(date: key, inputTokens: input, outputTokens: output, cost: 0))
        }
        scheduleSave()
        #if DEBUG
        print("[TokenTracker] +\(input)in +\(output)out → today: \(todayTokens), week: \(weekTokens)")
        #endif
    }

    public func recordCost(_ cost: Double) {
        guard cost > 0 else { return }
        cacheTimestamp = .distantPast
        let key = todayKey
        if let idx = history.firstIndex(where: { $0.date == key }) {
            history[idx].cost += cost
        } else {
            history.append(DayRecord(date: key, inputTokens: 0, outputTokens: 0, cost: cost))
        }
        scheduleSave()
        #if DEBUG
        print("[TokenTracker] cost +$\(String(format: "%.4f", cost)) → today: $\(String(format: "%.4f", todayCost))")
        #endif
    }

    // MARK: - Queries

    public var todayRecord: DayRecord {
        history.first(where: { $0.date == todayKey }) ?? DayRecord(date: todayKey, inputTokens: 0, outputTokens: 0, cost: 0)
    }

    public var todayTokens: Int { todayRecord.totalTokens }
    public var todayCost: Double { todayRecord.cost }

    public var weekTokens: Int {
        refreshCacheIfNeeded()
        return cachedWeekTokens
    }

    public var weekCost: Double {
        refreshCacheIfNeeded()
        return cachedWeekCost
    }

    // ── 결제 기간 (Billing Period) 사용량 ──

    /// 결제일 기준 이번 달 시작일
    public var billingPeriodStart: Date {
        let billingDay = max(1, AppSettings.shared.billingDay)
        let cal = Calendar.current
        let now = Date()
        let todayDay = cal.component(.day, from: now)
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)

        if billingDay <= 0 {
            // 미설정이면 이번 달 1일부터
            return cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? now
        }
        if todayDay >= billingDay {
            // 이번 달 결제일 이후
            return cal.date(from: DateComponents(year: year, month: month, day: billingDay)) ?? now
        } else {
            // 아직 결제일 전 → 지난달 결제일부터
            guard let lastMonth = cal.date(byAdding: .month, value: -1, to: now) else { return now }
            let lmYear = cal.component(.year, from: lastMonth)
            let lmMonth = cal.component(.month, from: lastMonth)
            guard let dayRange = cal.range(of: .day, in: .month, for: lastMonth) else { return now }
            let maxDay = dayRange.upperBound - 1
            return cal.date(from: DateComponents(year: lmYear, month: lmMonth, day: min(billingDay, maxDay))) ?? now
        }
    }

    public var billingPeriodTokens: Int {
        refreshCacheIfNeeded()
        return cachedBillingTokens
    }

    public var billingPeriodCost: Double {
        refreshCacheIfNeeded()
        return cachedBillingCost
    }

    private func refreshCacheIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(cacheTimestamp) > 30 else { return }
        cacheTimestamp = now

        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let weekRecords = history.filter { dateFormatter.date(from: $0.date).map { $0 >= weekAgo } ?? false }
        cachedWeekTokens = weekRecords.reduce(0) { $0 + $1.totalTokens }
        cachedWeekCost = weekRecords.reduce(0) { $0 + $1.cost }

        let bStart = billingPeriodStart
        let billingRecords = history.filter { dateFormatter.date(from: $0.date).map { $0 >= bStart } ?? false }
        cachedBillingTokens = billingRecords.reduce(0) { $0 + $1.totalTokens }
        cachedBillingCost = billingRecords.reduce(0) { $0 + $1.cost }
    }

    public var billingPeriodDays: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: billingPeriodStart, to: Date()).day ?? 0
    }

    public var billingPeriodLabel: String {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        let start = df.string(from: billingPeriodStart)
        let cal = Calendar.current
        let nextBilling = cal.date(byAdding: .month, value: 1, to: billingPeriodStart)
            ?? cal.date(byAdding: .day, value: 30, to: billingPeriodStart)
            ?? Date()
        let end = df.string(from: cal.date(byAdding: .day, value: -1, to: nextBilling) ?? nextBilling)
        return "\(start) ~ \(end)"
    }

    public var totalAllTimeTokens: Int {
        history.reduce(0) { $0 + $1.totalTokens }
    }

    public var totalAllTimeCost: Double {
        history.reduce(0) { $0 + $1.cost }
    }

    private var safeDailyLimit: Int { max(1, dailyTokenLimit) }
    private var safeWeeklyLimit: Int { max(1, weeklyTokenLimit) }

    private func cappedReserve(_ configured: Int, limit: Int, maxRatio: Double) -> Int {
        let ratioCap = max(1, Int(Double(max(1, limit)) * maxRatio))
        return min(configured, ratioCap)
    }

    private var effectiveGlobalDailyReserve: Int {
        cappedReserve(globalDailyReserve, limit: safeDailyLimit, maxRatio: 0.05)
    }

    private var effectiveGlobalWeeklyReserve: Int {
        cappedReserve(globalWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.05)
    }

    private var effectiveAutomationDailyReserve: Int {
        cappedReserve(automationDailyReserve, limit: safeDailyLimit, maxRatio: 0.18)
    }

    private var effectiveAutomationWeeklyReserve: Int {
        cappedReserve(automationWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.18)
    }

    private var effectiveEmergencyDailyReserve: Int {
        cappedReserve(emergencyDailyReserve, limit: safeDailyLimit, maxRatio: 0.03)
    }

    private var effectiveEmergencyWeeklyReserve: Int {
        cappedReserve(emergencyWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.03)
    }

    public var dailyRemaining: Int { max(0, safeDailyLimit - todayTokens) }
    public var weeklyRemaining: Int { max(0, safeWeeklyLimit - weekTokens) }

    public var dailyUsagePercent: Double { Double(todayTokens) / Double(safeDailyLimit) }
    public var weeklyUsagePercent: Double { Double(weekTokens) / Double(safeWeeklyLimit) }

    private func protectionUsageSummary() -> String {
        String(format: NSLocalizedString("token.protection.summary", comment: ""), formatTokens(todayTokens), formatTokens(safeDailyLimit), formatTokens(weekTokens), formatTokens(safeWeeklyLimit))
    }

    public func startBlockReason(isAutomation: Bool) -> String? {
        guard AppSettings.shared.tokenProtectionEnabled else { return nil }
        if dailyRemaining <= effectiveGlobalDailyReserve ||
            weeklyRemaining <= effectiveGlobalWeeklyReserve ||
            dailyUsagePercent >= 0.985 ||
            weeklyUsagePercent >= 0.985 {
            return String(format: NSLocalizedString("token.protection.global.block", comment: ""), protectionUsageSummary())
        }

        if isAutomation &&
            (dailyRemaining <= effectiveAutomationDailyReserve ||
             weeklyRemaining <= effectiveAutomationWeeklyReserve ||
             dailyUsagePercent >= 0.82 ||
             weeklyUsagePercent >= 0.82) {
            return String(format: NSLocalizedString("token.protection.sub.block", comment: ""), protectionUsageSummary())
        }

        return nil
    }

    public func runningStopReason(isAutomation: Bool, currentTabTokens: Int, tokenLimit: Int) -> String? {
        guard AppSettings.shared.tokenProtectionEnabled else {
            // 보호 꺼져 있어도 세션 한도는 적용
            if tokenLimit > 0 && currentTabTokens >= tokenLimit {
                return NSLocalizedString("token.protection.session.limit", comment: "")
            }
            return nil
        }
        if tokenLimit > 0 && currentTabTokens >= tokenLimit {
            return NSLocalizedString("token.protection.session.limit", comment: "")
        }

        if dailyRemaining <= effectiveEmergencyDailyReserve ||
            weeklyRemaining <= effectiveEmergencyWeeklyReserve {
            return String(format: NSLocalizedString("token.protection.global.stop", comment: ""), protectionUsageSummary())
        }

        if isAutomation &&
            (dailyRemaining <= effectiveGlobalDailyReserve ||
             weeklyRemaining <= effectiveGlobalWeeklyReserve ||
             dailyUsagePercent >= 0.94 ||
             weeklyUsagePercent >= 0.94) {
            return String(format: NSLocalizedString("token.protection.sub.stop", comment: ""), protectionUsageSummary())
        }

        // 비용 제한 체크
        let settings = AppSettings.shared
        if settings.dailyCostLimit > 0 && todayCost >= settings.dailyCostLimit {
            return String(format: NSLocalizedString("token.protection.daily.cost", comment: ""), String(format: "%.2f", settings.dailyCostLimit), String(format: "%.2f", todayCost))
        }

        return nil
    }

    public func costWarningNeeded(tabCost: Double) -> String? {
        let settings = AppSettings.shared
        guard settings.costWarningAt80 else { return nil }
        if settings.perSessionCostLimit > 0 && tabCost >= settings.perSessionCostLimit * 0.8 {
            return String(format: NSLocalizedString("token.protection.session.cost.warn", comment: ""), String(format: "%.2f", tabCost), String(format: "%.2f", settings.perSessionCostLimit))
        }
        if settings.dailyCostLimit > 0 && todayCost >= settings.dailyCostLimit * 0.8 {
            return String(format: NSLocalizedString("token.protection.daily.cost.warn", comment: ""), String(format: "%.2f", todayCost), String(format: "%.2f", settings.dailyCostLimit))
        }
        return nil
    }

    // MARK: - Persistence

    /// 30일 이상 된 기록을 런타임에서도 주기적으로 제거
    private func pruneHistoryIfNeeded() {
        guard history.count > 35 else { return } // 30일 + 여유
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        history = history.filter { dateFormatter.date(from: $0.date).map { $0 >= cutoff } ?? false }
    }

    private func scheduleSave(delay: TimeInterval = 0.75) {
        pruneHistoryIfNeeded()
        saveWorkItem?.cancel()
        let snapshot = history
        let key = saveKey
        let workItem = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) {
                PersistenceService.shared.set(data, forKey: key)
            }
        }
        saveWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func load() {
        guard let data = PersistenceService.shared.data(forKey: saveKey),
              let loaded = try? JSONDecoder().decode([DayRecord].self, from: data) else { return }
        // 최근 30일만 유지
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        history = loaded.filter { dateFormatter.date(from: $0.date).map { $0 >= cutoff } ?? false }
    }

    public func clearOldEntries() {
        let key = todayKey
        history = history.filter { $0.date == key }
        scheduleSave(delay: 0)
    }

    public func clearAllEntries() {
        history.removeAll()
        saveWorkItem?.cancel()
        PersistenceService.shared.removeObject(forKey: saveKey)
    }

    public func applyRecommendedMinimumLimits() {
        if dailyTokenLimit < Self.recommendedDailyLimit {
            dailyTokenLimit = Self.recommendedDailyLimit
        }
        if weeklyTokenLimit < Self.recommendedWeeklyLimit {
            weeklyTokenLimit = Self.recommendedWeeklyLimit
        }
    }

    /// Returns records for the last 7 days (oldest first), filling missing days with zero records.
    public var last7DaysRecords: [DayRecord] {
        let cal = Calendar.current
        let now = Date()
        var result: [DayRecord] = []
        for offset in (0..<7).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = dateFormatter.string(from: day)
            if let record = history.first(where: { $0.date == key }) {
                result.append(record)
            } else {
                result.append(DayRecord(date: key, inputTokens: 0, outputTokens: 0, cost: 0))
            }
        }
        return result
    }

    /// Short weekday label for a date string
    public func weekdayLabel(for dateString: String) -> String {
        guard let date = dateFormatter.date(from: dateString) else { return "?" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f.string(from: date)
    }

    /// Average daily tokens over last 7 days
    public var averageDailyTokens: Int {
        let records = last7DaysRecords
        let total = records.reduce(0) { $0 + $1.totalTokens }
        return total / max(1, records.count)
    }

    /// Average daily cost over last 7 days
    public var averageDailyCost: Double {
        let records = last7DaysRecords
        let total = records.reduce(0.0) { $0 + $1.cost }
        return total / Double(max(1, records.count))
    }

    public func formatTokens(_ c: Int) -> String {
        c.tokenFormatted
    }
}
