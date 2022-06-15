import XCTest
import XCTestExtensions

@testable import Runner

final class RunnerTests: XCTestCase {
    func testSyncZeroStatus() throws {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try runner.sync()
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
    }

    func testSyncNonZeroStatus() throws {
        let url = testURL(named: "non-zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try runner.sync()
        XCTAssertEqual(result.status, 123)
        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
    }

    func testLongRunning() throws {
        let url = testURL(named: "long-running", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try runner.sync()
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "hello\ngoodbye")
    }

    func testCaptureMode() throws {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try runner.sync(stdoutMode: .capture, stderrMode: .capture)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
    }

    func testTeeMode() throws {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try runner.sync(stdoutMode: .tee, stderrMode: .tee)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
    }

    func testPassthroughMode() throws {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try runner.sync(stdoutMode: .passthrough, stderrMode: .passthrough)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "")
        XCTAssertEqual(result.stderr, "")
    }

    func testCallbackMode() throws {
        var stdout = ""
        var stderr = ""
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try runner.sync(stdoutMode: .callback({ stdout.append($0) }), stderrMode: .callback({ stderr.append($0) }))
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(stdout, "stdout")
        XCTAssertEqual(stderr, "stderr")
        XCTAssertEqual(result.stdout, "")
        XCTAssertEqual(result.stderr, "")
    }

    func testModernAsync() async throws {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let result = try await runner.run(stdoutMode: .capture, stderrMode: .capture)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, "stdout")
        XCTAssertEqual(result.stderr, "stderr")
    }
    
    enum TestFailure: Error {
        case noStdout
        case noStderr
    }
    
    @available(macOS 12.0, *)
    func testModernStreaming() async throws {
        let url = testURL(named: "zero-status", withExtension: "sh")
        let runner = Runner(for: url)
        let process = try runner.async(stdoutMode: .capture, stderrMode: .capture)
        
        
        var stdout = ""
        guard let lines = process.stdout?.lines else {
            throw TestFailure.noStdout
        }
        for try await line in lines {
            stdout += line
        }
        XCTAssertEqual(stdout, "stdout")

        var stderr = ""
        guard let stderrLines = process.stderr?.lines else {
            throw TestFailure.noStderr
        }
        for try await line in stderrLines {
            stderr += line
        }

        XCTAssertEqual(stderr, "stderr")

        process.process.waitUntilExit()
        XCTAssertEqual(process.process.terminationStatus, 0)
//        XCTAssertEqual(result.stderr, "stderr")

    }
}
