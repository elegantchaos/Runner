// The Swift Programming Language
// https://docs.swift.org/swift-book

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Created by Sam Deane, 08/06/2018.
// All code (c) 2018 - present day, Elegant Chaos Limited.
// For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

open class Runner {

  let queue: DispatchQueue
  var environment: [String: String]
  let executable: URL
  public var cwd: URL?

  public enum Mode {
    case passthrough
    case capture
    case tee
  }

  public struct Result: CustomStringConvertible {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public var description: String {
      let stat = status == 0 ? "OK" : "Failed \(status)"
      let err = (stderr.isEmpty && !stdout.isEmpty) ? "" : "\n\n\(stderr)"
      return "\(stat)\n\(stdout)\(err)"
    }
  }

  /**
      Initialise with an explicit URL to the executable.
    */

  public init(
    for executable: URL, cwd: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    self.executable = executable
    self.environment = environment
    self.cwd = cwd
    self.queue = DispatchQueue(label: "runner.\(executable.lastPathComponent)")
  }

  /**
      Initialise with a command name.
      The command will be searched for using $PATH.
    */

  public init(
    command: String, cwd: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    self.executable = Runner.find(command: command, default: "/usr/bin/\(command)")
    self.environment = environment
    self.cwd = cwd
    self.queue = DispatchQueue(label: "runner.\(command)")
  }

  /**
     Invoke a command and some optional arguments.
     Control is transferred to the launched process, and this function doesn't return.
     */

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
    let process: Process
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
      for: &process.standardOutput, mode: stdoutMode, tee: FileHandle.standardOutput)
    let stderr = byteStream(
      for: &process.standardError, mode: stderrMode, tee: FileHandle.standardError)

    try process.run()
    return RunningProcess(stdout: stdout, stderr: stderr, process: process)
  }

  private func byteStream(for processPipe: inout Any?, mode: Mode, tee: FileHandle) -> Pipe
    .AsyncBytes?
  {
    switch mode {
    case .passthrough:
      return nil
    case .capture:

      let pipe = Pipe()
      processPipe = pipe
      return pipe.bytes
    case .tee:
      let pipe = Pipe()
      processPipe = pipe
      return pipe.bytesWithTee(tee)
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
