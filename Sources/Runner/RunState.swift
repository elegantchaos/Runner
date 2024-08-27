import Foundation

public enum RunState: Comparable {
  case succeeded
  case failed(Int32)
  case uncaughtSignal
  case unknown

  /// A one-item sequence reporting the final state of a process.
  public struct Sequence: AsyncSequence {
    /// The process we're reporting on.
    let process: Process

    public func makeAsyncIterator() -> AsyncStream<RunState>.Iterator {
      AsyncStream { continuation in
        process.terminationHandler = { process in
          let s: RunState
          switch process.terminationReason {
          case .exit:
            s = process.terminationStatus == 0 ? .succeeded : .failed(process.terminationStatus)
          case .uncaughtSignal:
            s = .uncaughtSignal
          default:
            s = .unknown
          }
          continuation.yield(s)
          continuation.finish()
        }

        continuation.onTermination = { _ in
        }
      }.makeAsyncIterator()
    }
  }
}
