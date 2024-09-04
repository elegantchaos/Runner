// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

public enum RunState: Comparable {
  case succeeded
  case failed(Int32)
  case uncaughtSignal
  case unknown

  /// A one-item sequence reporting the final state of a process.
  public struct Sequence: AsyncSequence, Sendable {
    /// The process we're reporting on.
    let process: Process

    public func makeAsyncIterator() -> AsyncStream<RunState>.Iterator {
      AsyncStream { continuation in
        process.terminationHandler = { process in
          Runner.debug("process terminated")
          let finalState: RunState
          switch process.terminationReason {
            case .exit:
              finalState =
                process.terminationStatus == 0 ? .succeeded : .failed(process.terminationStatus)
            case .uncaughtSignal:
              finalState = .uncaughtSignal
            default:
              finalState = .unknown
          }

          continuation.yield(finalState)
          continuation.finish()
        }

        continuation.onTermination = { termination in
          Runner.debug("continuation terminated \(termination)")
        }
      }.makeAsyncIterator()
    }
  }
}
