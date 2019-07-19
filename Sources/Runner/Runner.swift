// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Created by Sam Deane, 08/06/2018.
// All code (c) 2018 - present day, Elegant Chaos Limited.
// For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

open class Runner {
    var environment: [String:String]
    let executable: URL
    public var cwd: URL?

    public struct Result {
        public let status: Int32
        public let stdout: String
        public let stderr: String
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

    public func exec(arguments: [String] = []) {
        let process = Process()
        if #available(macOS 10.13, *) {
            if let cwd = cwd {
                process.currentDirectoryURL = cwd
            }

            process.executableURL = executable
        }
        process.arguments = arguments
        process.environment = environment
        process.launch()
        process.waitUntilExit()
        exit(process.terminationStatus)
    }


    /**
     Invoke a command and some optional arguments synchronously.
     Waits for the process to exit and returns the captured output plus the exit status.
     */

    public func sync(arguments: [String] = [], passthrough: Bool = false) throws -> Result {

        let process = Process()

        if #available(macOS 10.13, *) {
            if let cwd = cwd {
                process.currentDirectoryURL = cwd
            }
            process.executableURL = executable
        }

        process.arguments = arguments
        
        if passthrough {
            process.standardInput = FileHandle.standardInput
        } else {
            process.standardOutput = Pipe()
            process.standardOutput = Pipe()
        }
        
        process.environment = environment
        process.launch()
        process.waitUntilExit()

        var stdout: String = ""
        var stderr: String = ""
        
        if !passthrough {
            stdout = captureString(from: process.standardOutput)
            stderr = captureString(from: process.standardError)
        }
        
        return Result(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    
    /// Extract text from an output pipe
    /// - Parameter source: the pipe
    func captureString(from pipe: Any?) -> String {
        if let pipe = pipe as? Pipe {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return ""
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
