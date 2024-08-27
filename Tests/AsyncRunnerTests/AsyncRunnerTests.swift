import Foundation
import Testing

@testable import AsyncRunner

/// Test with a task that has a zero status.
@Test func testZeroStatus() async throws {
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

  for await state in result.state {
    #expect(state == .succeeded)
  }

}

/// Test with a task that has a non-zero status.
@Test func testNonZeroStatus() async throws {
  let runner = Runner(for: Bundle.module.url(forResource: "non-zero-status", withExtension: "sh")!)
  let result = try! runner.run()

  #expect(result.stdout != nil)
  #expect(result.stderr != nil)

  for await l in result.stdout!.lines {
    #expect(l == "stdout")
  }

  for await l in result.stderr!.lines {
    #expect(l == "stderr")
  }

  for await state in result.state {
    #expect(state == .failed(123))
  }
}

/// Test with a task that outputs more than one line
/// and takes a while to complete.
@Test func testLongRunningStatus() async throws {
  // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  let runner = Runner(for: Bundle.module.url(forResource: "long-running", withExtension: "sh")!)
  let result = try! runner.run()

  #expect(result.stdout != nil)
  #expect(result.stderr != nil)

  var expected = ["hello", "goodbye"]
  for await l in result.stdout!.lines {
    print(l)
    #expect(l == expected.removeFirst())
  }
  #expect(expected.isEmpty)

  for await state in result.state {
    #expect(state == .succeeded)
  }
}

/// Test tee mode where we both capture
/// the process output and write it to stdout/stderr.
@Test func testTeeMode() async throws {
  // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  let runner = Runner(for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!)
  let result = try! runner.run(stdoutMode: .both, stderrMode: .both)

  #expect(result.stdout != nil)
  #expect(result.stderr != nil)

  for await l in result.stdout!.lines {
    #expect(l == "stdout")
  }

  for await l in result.stderr!.lines {
    #expect(l == "stderr")
  }

  for await state in result.state {
    #expect(state == .succeeded)
  }
}

/// Test pass-through mode where we don't capture
/// the process output, but forward it to stdout/stderr.
@Test func testPassthroughMode() async throws {
  // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  let runner = Runner(for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!)
  let result = try! runner.run(stdoutMode: .forward, stderrMode: .forward)

  for await state in result.state {
    #expect(state == .succeeded)
  }

  #expect(result.stdout == nil)
  #expect(result.stderr == nil)
}
