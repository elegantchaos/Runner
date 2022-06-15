// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 14/06/22.
//  All code (c) 2022 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

public enum OutputChannel {
    case stdout
    case stderr
}

public protocol OutputHandler {
    init(for process: Process, channel: OutputChannel)
}

@available(macOS 12.0, *)
open class Runner2<OutHandler: OutputHandler, ErrHandler: OutputHandler> {
    
    public struct ProcessWithHandlers<OutHandler: OutputHandler, ErrHandler: OutputHandler> {
        let process: Process
        let stdout: OutHandler
        let stderr: ErrHandler
        
        init(for process: Process) {
            self.process = process
            self.stdout = OutHandler(for: process, channel: .stdout)
            self.stderr = ErrHandler(for: process, channel: .stderr)
        }
    }
    
    public typealias BundledProcess = ProcessWithHandlers<OutHandler, ErrHandler>
    
    var environment: [String:String]
    let executable: URL
    public var cwd: URL?

    public enum Mode {
        case passthrough
        case capture
        case tee
        case callback(_ block: PipeInfo.Callback)
    }
    
    /**
      Initialise with an explicit URL to the executable.
    */

    public init(for executable: URL, cwd: URL? = nil, environment: [String:String] = ProcessInfo.processInfo.environment) {
        self.executable = executable
        self.environment = environment
        self.cwd = cwd
    }

    /**
      Initialise with a command name.
      The command will be searched for using $PATH.
    */

    public init(command: String, cwd: URL? = nil, environment: [String:String] = ProcessInfo.processInfo.environment) {
        self.executable = Runner.find(command: command, default: "/usr/bin/\(command)")
        self.environment = environment
        self.cwd = cwd
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



    /**
     Invoke a command and some optional arguments asynchronously.
     Waits for the process to exit and returns the captured output plus the exit status.
     */

    public func makeProcess(arguments: [String] = []) throws -> BundledProcess {
        
        let process = Process()
        if let cwd = cwd {
            process.currentDirectoryURL = cwd
        }
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        return BundledProcess(for: process)
    }

    /**
     Invoke a command and some optional arguments synchronously.
     Waits (syncronously) for the process to exit and returns the captured output plus the exit status.
     */

    public func run(arguments: [String] = []) throws -> BundledProcess {
        let result = try makeProcess(arguments: arguments)
        try result.process.run()
        result.process.waitUntilExit()
        return result
    }

    /**
     Invoke a command and some optional arguments asynchronously.
     Waits for the process to exit and returns the captured output plus the exit status.
     */

    public func async(arguments: [String] = []) throws -> BundledProcess {
        let result = try makeProcess(arguments: arguments)
        try result.process.run()
        return result
    }

    /**
     Invoke a command and some optional arguments asynchronously.
     Waits for the process to exit and returns the captured output plus the exit status.
     */

    public func run(arguments: [String] = []) async throws -> BundledProcess {
        let result = try async(arguments: arguments)
        let r = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<BundledProcess,Error>) -> Void in
            result.process.terminationHandler = { process in
                continuation.resume(returning: result)
            }

            do {
                try result.process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return r
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
