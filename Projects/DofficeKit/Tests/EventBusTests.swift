import XCTest
import Combine
@testable import DofficeKit

final class EventBusTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Subscribe & Post

    func testPostAndReceive() {
        let bus = EventBus.shared
        let expectation = expectation(description: "receive event")

        bus.subscribe { event in
            if case .refresh = event {
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        bus.post(.refresh)
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Filtered Subscribe

    func testFilteredSubscribe() {
        let bus = EventBus.shared
        let expectation = expectation(description: "receive closeTab")

        bus.on({ event -> String? in
            if case .closeTab(let tabId) = event { return tabId }
            return nil
        }) { tabId in
            XCTAssertEqual(tabId, "tab-123")
            expectation.fulfill()
        }.store(in: &cancellables)

        // Post unrelated event first — should not trigger
        bus.post(.refresh)
        bus.post(.closeTab(tabId: "tab-123"))
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Cancellation

    func testCancellation() {
        let bus = EventBus.shared
        var received = false

        let sub = bus.subscribe { _ in received = true }
        sub.cancel()

        bus.post(.refresh)

        // Small delay to ensure async path completes
        let expectation = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(received)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Multiple Subscribers

    func testMultipleSubscribers() {
        let bus = EventBus.shared
        var count = 0
        let expectation = expectation(description: "both receive")
        expectation.expectedFulfillmentCount = 2

        bus.subscribe { event in
            if case .nextTab = event { count += 1; expectation.fulfill() }
        }.store(in: &cancellables)

        bus.subscribe { event in
            if case .nextTab = event { count += 1; expectation.fulfill() }
        }.store(in: &cancellables)

        bus.post(.nextTab)
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(count, 2)
    }
}
