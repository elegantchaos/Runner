import XCTest
import XCTestExtensions

@testable import Runner

final class RunnerTests: XCTestCase {
    func testSyncZeroStatus() {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try! runner.sync()
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
    }

    func testSyncNonZeroStatus() {
        let url = testURL(named: "non-zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try! runner.sync()
        XCTAssertEqual(result.status, 123)
        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
    }

    func testLongRunning() {
        let url = testURL(named: "long-running", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try! runner.sync()
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "hello\ngoodbye")
    }
}
