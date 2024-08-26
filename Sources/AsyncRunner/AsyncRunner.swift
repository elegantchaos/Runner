// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Created by Sam Deane, 26/08/2024.
// All code (c) 2024 - present day, Elegant Chaos Limited.
// For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

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
    self.executable = Runner.find(command: command, default: "/usr/bin/\(command)")
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

  public struct RunningProcess {
    let stdout: Pipe.AsyncBytes?
    let stderr: Pipe.AsyncBytes?
    let process: Task<Process, Never>
  }

  /**
     Invoke a command and some optional arguments asynchronously.
     Returns the running process.
     */

  public func run(
    arguments: [String] = [], stdoutMode: Mode = .capture, stderrMode: Mode = .capture
  ) throws -> RunningProcess {

    let process = Process()
    if let cwd = cwd {
      process.currentDirectoryURL = cwd
    }
    process.executableURL = executable
    process.arguments = arguments
    process.environment = environment

    let stdout = byteStream(
      for: &process.standardOutput, mode: stdoutMode, forwardingTo: FileHandle.standardOutput)

    let stderr = byteStream(
      for: &process.standardError, mode: stderrMode, forwardingTo: FileHandle.standardError)

    let processTask = Task {
      await withCheckedContinuation({
        continuation in
        process.terminationHandler = { process in
          continuation.resume(returning: process)
        }
      })
    }

    try process.run()

    return RunningProcess(
      stdout: stdout, stderr: stderr, process: processTask)
  }

  /// Return a byte stream for the given mode.
  /// If the mode is .forward, the process pipe is set to the forwardingHandle.
  /// If the mode is .capture, the process pipe is set to a new pipe.
  /// If the mode is .both, the process pipe is set to a new pipe, and the byte stream
  /// is set up to also forward to the forwardingHandle.
  private func byteStream(
    for processPipe: inout Any?, mode: Mode, forwardingTo forwardHandle: FileHandle
  ) -> Pipe
    .AsyncBytes?
  {
    switch mode {
    case .forward:
      processPipe = forwardHandle
      return nil
    case .capture:

      let pipe = Pipe()
      processPipe = pipe
      return pipe.bytes
    case .both:
      let pipe = Pipe()
      processPipe = pipe
      return pipe.bytesForwardingTo(forwardHandle)
    }
  }

  /**
    Find a command, using the $PATH environment variable.
    Returns nil if the command couldn't be located.
    */

  public class func find(command: String) -> URL? {
    let fm = FileManager.default
    if let path = ProcessInfo.processInfo.environment["PATH"] {
      for item in path.split(separator: ":") {
        let url = URL(fileURLWithPath: String(item)).appendingPathComponent(command)
        if fm.fileExists(atPath: url.path) {
          return url
        }
      }
    }

    return nil
  }

  /**
   Find a command, using the $PATH environment variable.
   Falls back to the supplied default if the command couldn't be located.
   */

  public class func find(command: String, default fallbackPath: String) -> URL {
    if let url = find(command: command) {
      return url
    }

    return URL(fileURLWithPath: fallbackPath)
  }

}
