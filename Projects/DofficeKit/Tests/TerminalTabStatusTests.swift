import XCTest
@testable import DofficeKit
import DesignSystem

final class TerminalTabStatusTests: XCTestCase {

    func testIdleStatus() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.isProcessing = false
        tab.isCompleted = false
        tab.isRunning = false
        tab.claudeActivity = .idle

        let status = tab.statusPresentation
        XCTAssertEqual(status.category, .idle)
    }

    func testActiveStatus() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.isProcessing = false
        tab.isCompleted = false
        tab.isRunning = true
        tab.claudeActivity = .idle

        let status = tab.statusPresentation
        XCTAssertEqual(status.category, .active)
    }

    func testCompletedStatus() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.isCompleted = true

        let status = tab.statusPresentation
        XCTAssertEqual(status.category, .completed)
    }

    func testErrorFromStartError() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.startError = "CLI not found"

        let status = tab.statusPresentation
        XCTAssertEqual(status.category, .attention)
    }

    func testErrorFromActivity() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.claudeActivity = .error

        let status = tab.statusPresentation
        XCTAssertEqual(status.category, .attention)
    }

    func testProcessingThinkingStatus() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.isProcessing = true
        tab.claudeActivity = .thinking

        let status = tab.statusPresentation
        XCTAssertEqual(status.category, .processing)
    }

    func testProcessingWritingStatus() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.isProcessing = true
        tab.claudeActivity = .writing

        let status = tab.statusPresentation
        XCTAssertEqual(status.category, .processing)
    }

    func testWorkerStateMapping() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.isCompleted = true
        XCTAssertEqual(tab.workerState, .success)

        tab.isCompleted = false
        tab.isProcessing = true
        tab.claudeActivity = .thinking
        XCTAssertEqual(tab.workerState, .thinking)

        tab.claudeActivity = .writing
        XCTAssertEqual(tab.workerState, .writing)

        tab.claudeActivity = .reading
        XCTAssertEqual(tab.workerState, .reading)
    }
}
