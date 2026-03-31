import XCTest
@testable import DofficeKit

final class StreamBlockTests: XCTestCase {

    func testBlockTypeEquality() {
        XCTAssertEqual(StreamBlock.BlockType.text, StreamBlock.BlockType.text)
        XCTAssertEqual(StreamBlock.BlockType.thought, StreamBlock.BlockType.thought)
        XCTAssertNotEqual(StreamBlock.BlockType.text, StreamBlock.BlockType.thought)
    }

    func testBlockTypeToolUseEquality() {
        let a = StreamBlock.BlockType.toolUse(name: "Bash", input: "ls")
        let b = StreamBlock.BlockType.toolUse(name: "Bash", input: "ls")
        let c = StreamBlock.BlockType.toolUse(name: "Read", input: "file.txt")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testBlockInitWithContent() {
        let block = StreamBlock(type: .text, content: "Hello")
        XCTAssertEqual(block.content, "Hello")
        XCTAssertFalse(block.isComplete)
        XCTAssertFalse(block.isError)
        XCTAssertNil(block.exitCode)
    }

    func testBlockAppend() {
        var block = StreamBlock(type: .text, content: "Hello")
        block.append(" World")
        XCTAssertEqual(block.content, "Hello World")
    }

    func testBlockInitDefaultContent() {
        let block = StreamBlock(type: .thought)
        XCTAssertEqual(block.content, "")
    }

    func testBlockHasUniqueId() {
        let a = StreamBlock(type: .text)
        let b = StreamBlock(type: .text)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testSessionStartBlockType() {
        let block = StreamBlock(type: .sessionStart(model: "Sonnet", sessionId: "abc123"), content: "Started")
        if case .sessionStart(let model, let sid) = block.blockType {
            XCTAssertEqual(model, "Sonnet")
            XCTAssertEqual(sid, "abc123")
        } else {
            XCTFail("Expected sessionStart block type")
        }
    }

    func testCompletionBlockType() {
        let block = StreamBlock(type: .completion(cost: 0.05, duration: 120))
        if case .completion(let cost, let duration) = block.blockType {
            XCTAssertEqual(cost, 0.05)
            XCTAssertEqual(duration, 120)
        } else {
            XCTFail("Expected completion block type")
        }
    }
}
