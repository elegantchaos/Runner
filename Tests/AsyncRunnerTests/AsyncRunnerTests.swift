import Foundation
import Testing

@testable import AsyncRunner

@Test func testSyncZeroStatus() async throws {
  // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  let runner = Runner(for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!)
  let result = try! runner.run()

  #expect(result.stdout != nil)
  #expect(result.stderr != nil)

  for await l in result.stdout!.lines {
    #expect(l == "stdout")
  }

  for await l in result.stderr!.lines {
    #expect(l == "stderr")
  }

  #expect(result.process.terminationStatus == 0)
  #expect(result.process.terminationReason == .exit)
}

/*
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

    func testTeeMode() {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try! runner.sync(stdoutMode: .tee, stderrMode: .tee)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
    }

    func testPassthroughMode() {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try! runner.sync(stdoutMode: .passthrough, stderrMode: .passthrough)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "")
        XCTAssertEqual(result.stderr, "")
    }

    func testCallbackMode() {
        var stdout = ""
        var stderr = ""
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try! runner.sync(stdoutMode: .callback({ stdout.append($0) }), stderrMode: .callback({ stderr.append($0) }))
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(stdout, "stdout")
        XCTAssertEqual(stderr, "stderr")
        XCTAssertEqual(result.stdout, "")
        XCTAssertEqual(result.stderr, "")
    }

*/
