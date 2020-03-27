import XCTest
import XCTestExtensions

@testable import Runner

final class RunnerTests: XCTestCase {
    func testSync() {
        let runner = Runner(for: URL(fileURLWithPath: "/usr/bin/which"))
        let result = try! runner.sync(arguments: ["ls"])
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "/bin/ls\n")
    }
    
    func testLongRunning() {
        let url = testURL(named: "long-running", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try! runner.sync()
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "hello\ngoodbye")
    }
}
