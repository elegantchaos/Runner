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

    public enum Mode {
        case passthrough
        case capture
        case tee
    }
    
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
     Invoke a command and some optional arguments synchronously.
     Waits for the process to exit and returns the captured output plus the exit status.
     */

    public func sync(arguments: [String] = [], stdoutMode: Mode = .capture, stderrMode: Mode = .capture) throws -> Result {
        class PipeInfo {
            let pipe: Pipe
            var handle: FileHandle?
            var tee: FileHandle?
            var text: String = ""
            
            init(tee teeHandle: FileHandle? = nil) {
                pipe = Pipe()
                tee = teeHandle
                handle = pipe.fileHandleForReading
                handle?.readabilityHandler = { handle in
                    let data = handle.availableData
                    teeHandle?.write(data)
                    if let string = String(data: data, encoding: .utf8) {
                        if string.count > 0 {
                            self.text.append(string)
                        }
                    }
                }
            }
            
            func finish() -> String {
                if let handle = handle {
                    handle.readabilityHandler = nil
                    let data = handle.readDataToEndOfFile()
                    tee?.write(data)
                    if let string = String(data: data, encoding: .utf8) {
                        if string.count > 0 {
                            self.text.append(string)
                        }
                    }
                }
                
                return text
            }
        }

        var stdout: PipeInfo?
        var stderr: PipeInfo?
        
        let process = Process()
        if let cwd = cwd {
            process.currentDirectoryURL = cwd
        }
        process.executableURL = executable
        process.arguments = arguments
        
        switch stdoutMode {
            case .passthrough: break
            case .capture:
                let outInfo = PipeInfo()
                process.standardOutput = outInfo.pipe
                stdout = outInfo
            case .tee:
                let outInfo = PipeInfo(tee: FileHandle.standardOutput)
                process.standardOutput = outInfo.pipe
                stdout = outInfo
        }
        
        switch stderrMode {
            case .passthrough: break
            case .capture:
                let errInfo = PipeInfo()
                process.standardError = errInfo.pipe
                stderr = errInfo
            case .tee:
                let errInfo = PipeInfo(tee: FileHandle.standardError)
                process.standardError = errInfo.pipe
                stderr = errInfo
        }
        
        process.environment = environment
        try process.run()
        process.waitUntilExit()

        
        return Result(status: process.terminationStatus, stdout: stdout?.finish() ?? "", stderr: stderr?.finish() ?? "")
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
