// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Created by Sam Deane, 26/08/2024.
// All code (c) 2024 - present day, Elegant Chaos Limited.
// For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ChaosByteStreams
import Foundation

open class Runner {

  var environment: [String: String]
  let executable: URL
  public var cwd: URL?

  static internal func debug(_ message: String) {
    #if RUNNER_LOGGING
      print(message)
    #endif
  }

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

  public struct Session: Sendable {
    /// Internal info about the output from the process.
    internal let outInfo: ProcessStream

    /// Internal info about the error output from the process.
    internal let errInfo: ProcessStream

    /// Byte stream of the captured output.
    public var stdout: Pipe.AsyncBytes { outInfo.bytes }

    /// Byte stream of the captured error output.
    public var stderr: Pipe.AsyncBytes { errInfo.bytes }

    /// One-shot stream of the state of the process.
    /// This will only ever yield one value, and then complete.
    /// You can await this value if you want to wait for the process to finish.
    public let state: RunState.Sequence

    /// Check the state of the process and perform an action if it failed.
    nonisolated public func ifFailed(_ e: @Sendable @escaping () async -> Void) async throws {
      debug("checking state")
      var s: RunState?
      for await state in self.state {
        s = state
        break
      }

      debug("got state")
      if s != .succeeded {
        debug("failed")
        Task.detached {
          await e()
        }
      }
    }

    /// Check the state of the process and throw an error if it failed.
    public func throwIfFailed(_ e: @autoclosure @Sendable @escaping () async -> Error) async throws
    {
      debug("checking state")
      var s: RunState?
      for await state in self.state {
        s = state
        break
      }

      debug("got state")
      if s != .succeeded {
        debug("failed")
        let error = await e()
        debug("throwing \(error)")
        throw error
      }
    }
  }

  /**
     Invoke a command and some optional arguments asynchronously.
     Returns the running process.
     */

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

  public struct ProcessStream: Sendable {
    /// A custom pipe to capture output, if we're in capture mode.
    let pipe: Pipe?

    /// The file to capture output, if we're not capturing.
    let handle: FileHandle?

    /// Byte stream of the captured output.
    /// If we're not capturing, this will be a no-op stream that's empty
    /// so that client code has a consistent interface to work with.
    let bytes: Pipe.AsyncBytes

    /// Return a byte stream for the given mode.
    /// If the mode is .forward, we use the standard handle for the process.
    /// If the mode is .capture, we make a new pipe and use that.
    /// If the mode is .both, we make a new pipe and set it up to forward to the standard handle.
    /// If the mode is .discard, we use /dev/null.
    init(mode: Mode, standardHandle: FileHandle) {
      switch mode {
      case .forward:
        pipe = nil
        handle = standardHandle
        bytes = Pipe.noBytes

      case .capture:
        pipe = Pipe()
        handle = pipe!.fileHandleForReading
        bytes = pipe!.bytes

      case .both:
        pipe = Pipe()
        handle = pipe!.fileHandleForReading
        bytes = pipe!.bytesForwardingTo(standardHandle)

      case .discard:
        pipe = nil
        handle = FileHandle.nullDevice
        bytes = Pipe.noBytes
      }
    }

    static let standardHandles = [
      FileHandle.standardInput, FileHandle.standardOutput, FileHandle.standardError,
      FileHandle.nullDevice,
    ]
  }

}
