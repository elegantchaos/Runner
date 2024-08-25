// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Created by Sam Deane, 08/06/2018.
// All code (c) 2018 - present day, Elegant Chaos Limited.
// For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

open class Runner {
    public typealias PipeCallback = (String) -> Void
    
    let queue: DispatchQueue
    var environment: [String:String]
    let executable: URL
    public var cwd: URL?

    public enum Mode {
        case passthrough
        case capture
        case tee
        case callback(_ block: PipeCallback)
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

    public init(for executable: URL, cwd: URL? = nil, environment: [String:String] = ProcessInfo.processInfo.environment) {
        self.executable = executable
        self.environment = environment
        self.cwd = cwd
        self.queue = DispatchQueue(label: "runner.\(executable.lastPathComponent)")
    }

    /**
      Initialise with a command name.
      The command will be searched for using $PATH.
    */

    public init(command: String, cwd: URL? = nil, environment: [String:String] = ProcessInfo.processInfo.environment) {
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


    public class PipeInfo {
        class Buffer {
            var text: String = ""
        }
        
        let pipe: Pipe
        let queue: DispatchQueue
        var callback: PipeCallback
        var handle: FileHandle?
        var tee: FileHandle?
        var buffer: Buffer
        
        init(tee teeHandle: FileHandle? = nil, queue: DispatchQueue, callback: PipeCallback? = nil) {
            let buffer = Buffer()
            
            self.pipe = Pipe()
            self.queue = queue
            self.tee = teeHandle
            self.handle = pipe.fileHandleForReading
            self.buffer = buffer
            self.callback = callback ?? { buffer.text.append($0) }

            handle?.readabilityHandler = { handle in
                let data = handle.availableData
                queue.async {
                    self.write(data: data)
                }
            }
        }
        
        func finish() -> String {
            if let handle = handle {
                queue.async {
                    let data = handle.readDataToEndOfFile()
                    handle.readabilityHandler = nil
                    self.write(data: data)
                }
            }

            var final = ""
            queue.sync {
                final = buffer.text
            }
            
            return final
        }
        
        func write(data: Data) {
            tee?.write(data)
            if let string = String(data: data, encoding: .utf8) {
                if string.count > 0 {
                    self.callback(string)
                }
            }
        }
    }

    /**
     Invoke a command and some optional arguments synchronously.
     Waits for the process to exit and returns the captured output plus the exit status.
     */

    public func sync(arguments: [String] = [], stdoutMode: Mode = .capture, stderrMode: Mode = .capture) throws -> Result {
        let process = Process()
        if let cwd = cwd {
            process.currentDirectoryURL = cwd
        }
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment

        let stdout = info(for: stdoutMode, pipe: &process.standardOutput)
        let stderr = info(for: stderrMode, pipe: &process.standardError)
        
        try process.run()
        process.waitUntilExit()
        
        return Result(status: process.terminationStatus, stdout: stdout?.finish() ?? "", stderr: stderr?.finish() ?? "")
    }

    public struct RunningProcess {
        let stdout: PipeInfo?
        let stderr: PipeInfo?
        let process: Process
    }

    /**
     Invoke a command and some optional arguments asynchronously.
     Waits for the process to exit and returns the captured output plus the exit status.
     */

    public func async(arguments: [String] = [], stdoutMode: Mode = .capture, stderrMode: Mode = .capture) throws -> RunningProcess {
        
        let process = Process()
        if let cwd = cwd {
            process.currentDirectoryURL = cwd
        }
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment

        let stdout = info(for: stdoutMode, pipe: &process.standardOutput)
        let stderr = info(for: stderrMode, pipe: &process.standardError)
        
        try process.run()
        return RunningProcess(stdout: stdout, stderr: stderr, process: process)
    }

    func info(for mode: Mode, pipe: inout Any?) -> PipeInfo? {
        switch mode {
            case .passthrough:
                return nil
            case .capture:
                let outInfo = PipeInfo(queue: queue)
                pipe = outInfo.pipe
                return outInfo
            case .tee:
                let outInfo = PipeInfo(tee: FileHandle.standardOutput, queue: queue)
                pipe = outInfo.pipe
                return outInfo
            case .callback(let block):
                let outInfo = PipeInfo(queue: queue, callback: block)
                pipe = outInfo.pipe
                return outInfo

        }
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
