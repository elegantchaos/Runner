// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Representation of the state of the process.
public enum RunState: Comparable, Sendable {
  case succeeded
  case failed(Int32)
  case uncaughtSignal
  case startup(String)
  case unknown

  public struct Sequence: AsyncSequence, Sendable {
    /// The runner we're reporting on.
    let process: Process

    public func makeAsyncIterator() -> AsyncStream<RunState>.Iterator {
      return makeStream().makeAsyncIterator()
    }

    public func makeStream() -> AsyncStream<RunState> {
      Runner.debug("makeIterator")
      return AsyncStream { continuation in
        Runner.debug("registering callback")
        process.terminationHandler = { _ in
          Runner.debug("terminated")
          cleanup(stream: process.standardOutput, name: "stdout")
          cleanup(stream: process.standardError, name: "stderr")
          continuation.yield(process.finalState)
          continuation.finish()
        }

        do { try process.run() }
        catch {
          continuation.yield(.startup(String(describing: error)))  // TODO: better to send the error here, but we then need to make RunState Comparable
          continuation.finish()
        }

        continuation.onTermination = { termination in
          Runner.debug("continuation terminated \(termination)")
        }

      }
    }

    func cleanup(stream: Any?, name: String) {  // TODO: this is probably unnecessary; remove it
      let handle =
        (stream as? Pipe)?.fileHandleForReading ?? (stream as? FileHandle)
      if let handle {
        Runner.debug("syncing \(name)")
        try? handle.synchronize()
      }
    }

  }

}

extension Process {
  /// Return the final state of the process.
  var finalState: RunState {
    assert(!isRunning)

    switch terminationReason { case .exit:
      return terminationStatus == 0 ? .succeeded : .failed(terminationStatus)
      case .uncaughtSignal: return .uncaughtSignal
      default: return .unknown
    }
  }
}
