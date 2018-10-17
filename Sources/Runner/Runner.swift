// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Created by Sam Deane, 08/06/2018.
// All code (c) 2018 - present day, Elegant Chaos Limited.
// For licensing terms, see http://elegantchaos.com/license/liberal/.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

public class Runner {
    var environment: [String:String]
    let executable: URL
    var cwd: URL?

    public struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    public init(for executable: URL, cwd: URL? = nil, environment: [String:String] = ProcessInfo.processInfo.environment) {
        self.executable = executable
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

    public func sync(arguments: [String] = []) throws -> Result {
        let pipe = Pipe()
        let handle = pipe.fileHandleForReading
        let errPipe = Pipe()
        let errHandle = errPipe.fileHandleForReading

        let process = Process()

        if #available(macOS 10.13, *) {
            if let cwd = cwd {
                process.currentDirectoryURL = cwd
            }
            process.executableURL = executable
        }

        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errPipe
        process.environment = environment
        process.launch()
        let data = handle.readDataToEndOfFile()
        let errData = errHandle.readDataToEndOfFile()
        process.waitUntilExit()
        let stdout = String(data:data, encoding:String.Encoding.utf8) ?? ""
        let stderr = String(data:errData, encoding:String.Encoding.utf8) ?? ""
        return Result(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

}
