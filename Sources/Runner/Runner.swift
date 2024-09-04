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

  public struct RunningProcess: Sendable {
    public let outInfo: PipeInfo
    public let errInfo: PipeInfo
    public var stdout: Pipe.AsyncBytes { outInfo.bytes }
    public var stderr: Pipe.AsyncBytes { errInfo.bytes }
    public let state: RunState.Sequence

    /// Check the state of the process and throw an error if it failed.
    public func throwIfFailed(_ e: () async -> Error) async throws {
      print("checking state")
      var s: RunState?
      for await state in self.state {
        s = state
        break
      }

      print("got state")
      if s != .succeeded {
        print("failed")
        throw await e()
      }
    }
  }

  /**
     Invoke a command and some optional arguments asynchronously.
     Returns the running process.
     */

  public func run(
    _ arguments: [String] = [], stdoutMode: Mode = .capture, stderrMode: Mode = .capture
  ) throws -> RunningProcess {

    let process = Process()
    if let cwd = cwd {
      process.currentDirectoryURL = cwd
    }
    process.executableURL = executable
    process.arguments = arguments
    process.environment = environment

    let stdout = PipeInfo(mode: stdoutMode, equivalent: FileHandle.standardOutput)
    process.standardOutput = stdout.pipe ?? stdout.handle
    let stderr = PipeInfo(mode: stderrMode, equivalent: FileHandle.standardError)
    process.standardError = stderr.pipe ?? stderr.handle

    let state = RunState.Sequence(process: process) {
      stdout.cleanup()
      stderr.cleanup()

      let s: RunState
      switch process.terminationReason {
      case .exit:
        s = process.terminationStatus == 0 ? .succeeded : .failed(process.terminationStatus)
      case .uncaughtSignal:
        s = .uncaughtSignal
      default:
        s = .unknown
      }

      return s
    }

    let result = RunningProcess(outInfo: stdout, errInfo: stderr, state: state)

    try process.run()

    return result
  }

  public struct PipeInfo: Sendable {
    let pipe: Pipe?
    let handle: FileHandle?
    let bytes: Pipe.AsyncBytes

    /// Return a byte stream for the given mode.
    /// If the mode is .forward, the process pipe is set to the forwardingHandle.
    /// If the mode is .capture, the process pipe is set to a new pipe.
    /// If the mode is .both, the process pipe is set to a new pipe, and the byte stream
    /// is set up to also forward to the forwardingHandle.
    init(
      mode: Mode, equivalent forwardHandle: FileHandle
    )

    {
      switch mode {
      case .forward:
        pipe = nil
        handle = forwardHandle
        bytes = Pipe.noBytes

      case .capture:
        pipe = Pipe()
        handle = pipe!.fileHandleForReading
        bytes = pipe!.bytes

      case .both:
        pipe = Pipe()
        handle = pipe!.fileHandleForReading
        bytes = pipe!.bytesForwardingTo(forwardHandle)

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

    internal func cleanup() {
      if let handle, !Self.standardHandles.contains(handle) {
        handle.closeFile()
        print("cleaned up \(handle)")
      }
    }

  }

}
