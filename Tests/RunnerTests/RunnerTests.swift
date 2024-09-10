import Foundation
import Testing

@testable import Runner

/// Test wait for termination.
@Test func testWait() async throws {
  let runner = Runner(
    for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!
  )
  let session = runner.run()

  let state = await session.waitUntilExit()
  #expect(state == .succeeded)
}

/// Test with a task that has a zero status.
@Test func testZeroStatus() async throws {
  let runner = Runner(
    for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!
  )
  let session = runner.run()

  for try await l in await session.stdout.lines { #expect(l == "stdout") }

  for try await l in await session.stderr.lines { #expect(l == "stderr") }

  for await state: RunState in session.state { #expect(state == .succeeded) }
}

/// Test with a task that has a non-zero status.
@Test func testNonZeroStatus() async throws {
  let runner = Runner(
    for: Bundle.module.url(forResource: "non-zero-status", withExtension: "sh")!
  )
  let session = runner.run()

  for try await l in await session.stdout.lines { #expect(l == "stdout") }

  for try await l in await session.stderr.lines { #expect(l == "stderr") }

  for await state in session.state { #expect(state == .failed(123)) }
}

/// Test with a task that outputs more than one line
/// and takes a while to complete.
@Test func testLongRunningStatus() async throws {
  let runner = Runner(
    for: Bundle.module.url(forResource: "long-running", withExtension: "sh")!
  )
  let session = runner.run()

  var expected = ["hello", "goodbye"]
  for try await l in await session.stdout.lines {
    #expect(l == expected.removeFirst())
  }
  #expect(expected.isEmpty)

  for await state in session.state { #expect(state == .succeeded) }
}

/// Test tee mode where we both capture
/// the process output and write it to stdout/stderr.
@Test func testBothMode() async throws {
  let runner = Runner(
    for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!
  )
  let session = runner.run(stdoutMode: .both, stderrMode: .both)

  for try await l in await session.stdout.lines { #expect(l == "stdout") }

  for try await l in await session.stderr.lines { #expect(l == "stderr") }

  for await state in session.state { #expect(state == .succeeded) }
}

/// Test pass-through mode where we don't capture
/// the process output, but forward it to stdout/stderr.
@Test func testPassthroughMode() async throws {
  let runner = Runner(
    for: Bundle.module.url(forResource: "zero-status", withExtension: "sh")!
  )
  let session = runner.run(stdoutMode: .forward, stderrMode: .forward)

  for try await _ in await session.stdout {
    #expect(Bool(false), "shouldn't be any content")
  }

  for try await _ in await session.stderr {
    #expect(Bool(false), "shouldn't be any content")
  }

  for try await state in session.state { #expect(state == .succeeded) }
}

/// Test passing arguments.
@Test func testArgs() async throws {
  let runner = Runner(
    for: Bundle.module.url(forResource: "args", withExtension: "sh")!
  )
  let session = runner.run(["arg1", "arg2"])

  for try await line in await session.stdout.lines {
    #expect(line == "args arg1 arg2")
  }
}

/// Regression test for xcodebuild which triggered a deadlock in an earlier implementation.
@Test func testXcodeBuild() async throws {

  enum ArchiveError: RunnerError {
    case archiveFailed

    func description(for session: Runner.Session) async -> String {
      async let stderr = String(session.stderr)
      switch self { case .archiveFailed:
        return "Archiving failed.\n\n\(await stderr)"
      }
    }
  }

  let runner = Runner(command: "xcodebuild")
  let session = runner.run([], stdoutMode: .capture, stderrMode: .capture)

  do {
    try await session.throwIfFailed(ArchiveError.archiveFailed)
  }
  catch let e as WrappedRunnerError {
    #expect((e.error as? ArchiveError) == .archiveFailed)
    #expect(e.description.contains("Runner does not contain an Xcode project."))
    let errorOutput = await session.errInfo.buffer?.string
    #expect(errorOutput?.contains("Runner does not contain an Xcode project.") == true)
  }
  catch {
    throw error
  }

  let output = await String(session.stdout)
  #expect(output.contains("Command line invocation:"))
}

#if TEST_REGRESSION
  @Test func testRegression() async throws {
    let xcode = Runner(command: "xcodebuild")
    xcode.cwd = URL(fileURLWithPath: "/Users/sam/Developer/Projects/Stack")
    let args = [
      "-workspace", "Stack.xcworkspace", "-scheme", "Stack", "archive",
      "-archivePath",
      "/Users/sam/Developer/Projects/Stack/.build/macOS/archive.xcarchive",
      "-allowProvisioningUpdates",
      "INFOPLIST_PREFIX_HEADER=/Users/sam/Developer/Projects/Stack/.build/macOS/VersionInfo.h",
      "INFOPLIST_PREPROCESS=YES", "CURRENT_PROJECT_VERSION=25",
    ]

    let session = xcode.run(args, stdoutMode: .both, stderrMode: .both)
    try await session.throwIfFailed(ArchiveError.archiveFailed)
  }
#endif
