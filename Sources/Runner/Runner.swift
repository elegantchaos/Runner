// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Created by Sam Deane, 08/06/2018.
// All code (c) 2018 - present day, Elegant Chaos Limited.
// For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Simplifies the process of executing subprocesses and capturing
/// their output.
///
/// To initialise a Runner, you pass it a command to execute, and
/// optionally a working directory and some environment variables.
///
/// You can then invoke the command (multiple times if you need).
/// For each invocation you pass some arguments, and also the mode
/// to use for capturing output (stdout and stderr) from the process.
///
/// Invocation can be done synchronously or asynchronously.
open class Runner {
    let queue: DispatchQueue
    var environment: [String: String]
    let executable: URL
    public var cwd: URL?

    public enum Mode {
        case passthrough
        case capture
        case tee
        case callback(_ block: PipeInfo.Callback)
    }

    public struct Result {
        public let status: Int32
        public let stdout: String
        public let stderr: String
    }

    /**
       Initialise with an explicit URL to the executable.
     */

    public init(for executable: URL, cwd: URL? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.executable = executable
        self.environment = environment
        self.cwd = cwd
        self.queue = DispatchQueue(label: "runner.\(executable.lastPathComponent)")
    }

    /**
       Initialise with a command name.
       The command will be searched for using $PATH.
     */

    public init(command: String, cwd: URL? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) {
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

    /**
     Invoke a command and some optional arguments synchronously.
     Waits (syncronously) for the process to exit and returns the captured output plus the exit status.
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

    /**
     Invoke a command and some optional arguments asynchronously.
     Waits for the process to exit and returns the captured output plus the exit status.
     */

    @available(macOS 10.15, *)
    public func run(arguments: [String] = [], stdoutMode: Mode = .capture, stderrMode: Mode = .capture) async throws -> Result {
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
        return await withCheckedContinuation { continuation in
            process.waitUntilExit()
            let result = Result(status: process.terminationStatus, stdout: stdout?.finish() ?? "", stderr: stderr?.finish() ?? "")
            continuation.resume(returning: result)
        }
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
            case let .callback(block):
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
