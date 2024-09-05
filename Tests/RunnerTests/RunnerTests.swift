import Foundation
import Testing

@testable import Runner

/// Test with a task that has a zero status.
@Test func testZeroStatus() async throws {
  let runner = Runner(for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!)
  let result = runner.run()

  #expect(result.stdout != nil)
  #expect(result.stderr != nil)

  for try await l in result.stdout.lines {
    #expect(l == "stdout")
  }

  for try await l in result.stderr.lines {
    #expect(l == "stderr")
  }

  for await state in result.state {
    #expect(state == .succeeded)
  }

}

/// Test with a task that has a non-zero status.
@Test func testNonZeroStatus() async throws {
  let runner = Runner(for: Bundle.module.url(forResource: "non-zero-status", withExtension: "sh")!)
  let result = runner.run()

  #expect(result.stdout != nil)
  #expect(result.stderr != nil)

  for try await l in result.stdout.lines {
    #expect(l == "stdout")
  }

  for try await l in result.stderr.lines {
    #expect(l == "stderr")
  }

  for await state in result.state {
    #expect(state == .failed(123))
  }
}

/// Test with a task that outputs more than one line
/// and takes a while to complete.
@Test func testLongRunningStatus() async throws {
  let runner = Runner(for: Bundle.module.url(forResource: "long-running", withExtension: "sh")!)
  let result = runner.run()

  #expect(result.stdout != nil)
  #expect(result.stderr != nil)

  var expected = ["hello", "goodbye"]
  for try await l in result.stdout.lines {
    #expect(l == expected.removeFirst())
  }
  #expect(expected.isEmpty)

  for await state in result.state {
    #expect(state == .succeeded)
  }
}

/// Test tee mode where we both capture
/// the process output and write it to stdout/stderr.
@Test func testBothMode() async throws {
  let runner = Runner(for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!)
  let result = runner.run(stdoutMode: .both, stderrMode: .both)

  #expect(result.stdout != nil)
  #expect(result.stderr != nil)

  for try await l in result.stdout.lines {
    #expect(l == "stdout")
  }

  for try await l in result.stderr.lines {
    #expect(l == "stderr")
  }

  for await state in result.state {
    #expect(state == .succeeded)
  }
}

/// Test pass-through mode where we don't capture
/// the process output, but forward it to stdout/stderr.
@Test func testPassthroughMode() async throws {
  let runner = Runner(for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!)
  let result = runner.run(stdoutMode: .forward, stderrMode: .forward)

  for try await _ in result.stdout {
    #expect(Bool(false), "shouldn't be any content")
  }

  for try await _ in result.stderr {
    #expect(Bool(false), "shouldn't be any content")
  }

  for try await state in result.state {
    #expect(state == .succeeded)
  }
}

/// Test passing arguments.
@Test func testArgs() async throws {
  let runner = Runner(for: Bundle.module.url(forResource: "args", withExtension: "sh")!)
  let result = runner.run(["arg1", "arg2"])

  for try await line in result.stdout.lines {
    #expect(line == "args arg1 arg2")
  }

}

enum TestErrors: Swift.Error {

  case badParameters(String)
}

/// Regression test for xcodebuild which triggered a deadlock in an earlier implementation.
@Test func testXcodeBuild() async throws {
  let runner = Runner(command: "xcodebuild")
  let result = runner.run([], stdoutMode: .both, stderrMode: .both)

  do {
    try await result.throwIfFailed(TestErrors.badParameters(await String(result.stderr)))
  } catch TestErrors.badParameters(let message) {
    #expect(message.contains("Runner does not contain an Xcode project."))
  } catch {
    #expect(error is TestErrors)
  }

  let output = await String(result.stdout)
  #expect(output.contains("Command line invocation:"))
}

@Test func testRegression() async throws {
  let xcode = Runner(command: "xcodebuild")
  xcode.cwd = URL(fileURLWithPath: "/Users/sam/Developer/Projects/Stack")
  let args = [
    "-workspace", "Stack.xcworkspace", "-scheme", "Stack", "archive", "-archivePath",
    "/Users/sam/Developer/Projects/Stack/.build/macOS/archive.xcarchive",
    "-allowProvisioningUpdates",
    "INFOPLIST_PREFIX_HEADER=/Users/sam/Developer/Projects/Stack/.build/macOS/VersionInfo.h",
    "INFOPLIST_PREPROCESS=YES", "CURRENT_PROJECT_VERSION=25",
  ]

  let result = xcode.run(args, stdoutMode: .both, stderrMode: .both)
  // print(await String(result.stdout))
  // print(await String(result.stderr))
  try await result.throwIfFailed(ArchiveError.archiveFailed)
}

enum ArchiveError: RunnerError {
  case archiveFailed

  func description(for session: Runner.Session) async -> String {
    async let stderr = String(session.stderr)
    switch self {
      case .archiveFailed: return "Archiving failed.\n\n\(await stderr)"
    }
  }
}
