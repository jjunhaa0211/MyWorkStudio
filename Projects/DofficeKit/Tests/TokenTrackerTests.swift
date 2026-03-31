import XCTest
@testable import DofficeKit

final class TokenTrackerTests: XCTestCase {

    func testInitialState() {
        // TokenTracker.shared loads from UserDefaults; verify basic API
        let tracker = TokenTracker.shared
        XCTAssertGreaterThanOrEqual(tracker.todayTokens, 0)
        XCTAssertGreaterThanOrEqual(tracker.weekTokens, 0)
    }

    func testFormatTokensSmall() {
        let tracker = TokenTracker.shared
        XCTAssertEqual(tracker.formatTokens(500), "500")
        XCTAssertEqual(tracker.formatTokens(0), "0")
    }

    func testFormatTokensThousands() {
        let tracker = TokenTracker.shared
        XCTAssertEqual(tracker.formatTokens(1500), "1.5k")
        XCTAssertEqual(tracker.formatTokens(10000), "10.0k")
    }

    func testFormatTokensMillions() {
        let tracker = TokenTracker.shared
        XCTAssertEqual(tracker.formatTokens(1_500_000), "1.5M")
        XCTAssertEqual(tracker.formatTokens(2_000_000), "2.0M")
    }

    func testDailyLimitDefaults() {
        XCTAssertEqual(TokenTracker.recommendedDailyLimit, 500_000)
        XCTAssertEqual(TokenTracker.recommendedWeeklyLimit, 2_500_000)
    }

    func testUsagePercentComputation() {
        let tracker = TokenTracker.shared
        // Usage percent should be between 0 and some reasonable value
        XCTAssertGreaterThanOrEqual(tracker.dailyUsagePercent, 0)
        XCTAssertGreaterThanOrEqual(tracker.weeklyUsagePercent, 0)
    }

    func testLast7DaysRecordsCount() {
        let tracker = TokenTracker.shared
        let records = tracker.last7DaysRecords
        XCTAssertEqual(records.count, 7, "Should always return exactly 7 records")
    }

    func testBillingPeriodDaysNonNegative() {
        let tracker = TokenTracker.shared
        XCTAssertGreaterThanOrEqual(tracker.billingPeriodDays, 0)
    }

    func testBillingPeriodLabelNotEmpty() {
        let tracker = TokenTracker.shared
        XCTAssertFalse(tracker.billingPeriodLabel.isEmpty)
    }
}
