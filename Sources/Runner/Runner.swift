// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Created by Sam Deane, 26/08/2024.
// All code (c) 2024 - present day, Elegant Chaos Limited.
// For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ChaosByteStreams
import Foundation

open class Runner {
  /// The environment to run the command in.
  var environment: [String: String]

  /// The URL of the executable to run.
  let executable: URL

  /// The current working directory to run the command in.
  public var cwd: URL?

  /// Log a message if internal logging is enabled.
  static internal func debug(_ message: String) {
    #if RUNNER_LOGGING
      print(message)
    #endif
  }

  /// The mode for handling output from the process.
  public enum Mode {
    /// Forward the output to stdout/stderr.
    case forward
    /// Capture the output.
    case capture
    /// Capture the output and forward it to stdout/stderr.
    case both
    /// Discard the output.
    case discard
  }

  /// Initialise with an explicit URL to the executable.
  public init(
    for executable: URL, cwd: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    self.executable = executable
    self.environment = environment
    self.cwd = cwd
  }

  /// Initialise with a command name.
  /// The command will be searched for using $PATH.
  public init(
    command: String, cwd: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    self.executable = URL(inSystemPathWithName: command, fallback: "/usr/bin/\(command)")
    self.environment = environment
    self.cwd = cwd
  }

  /// Invoke a command and some optional arguments asynchronously.
  /// Returns the running process.
  public func run(
    _ arguments: [String] = [], stdoutMode: Mode = .capture, stderrMode: Mode = .capture
  ) throws -> Session {

    let process = Process()
    if let cwd = cwd {
      process.currentDirectoryURL = cwd
    }
    process.executableURL = executable
    process.arguments = arguments
    process.environment = environment

    let stdout = ProcessStream(mode: stdoutMode, standardHandle: FileHandle.standardOutput)
    process.standardOutput = stdout.pipe ?? stdout.handle
    let stderr = ProcessStream(mode: stderrMode, standardHandle: FileHandle.standardError)
    process.standardError = stderr.pipe ?? stderr.handle

    let state = RunState.Sequence(process: process)

    let session = Session(outInfo: stdout, errInfo: stderr, state: state)

    try process.run()

    return session
  }

  /// Invoke a command and some optional arguments.
  /// Control is transferred to the launched process, and this function doesn't return.
  public func exec(arguments: [String] = []) -> Never {
    let process = Process()
    if let cwd = cwd {
      process.currentDirectoryURL = cwd
    }

    process.executableURL = executable
    process.arguments = arguments
    process.environment = environment

    do {
      try process.run()
    } catch {
      fatalError("Failed to launch \(executable).\n\n\(error)")
    }

    process.waitUntilExit()
    exit(process.terminationStatus)
  }
}
