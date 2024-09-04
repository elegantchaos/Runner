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
    let onTermination: @Sendable () -> RunState

    public func makeAsyncIterator() -> AsyncStream<RunState>.Iterator {
      AsyncStream { continuation in
        process.terminationHandler = { process in
          print("process terminated")
          let finalState = self.onTermination()
          continuation.yield(finalState)
          continuation.finish()
        }

        continuation.onTermination = { termination in
          print("continuation terminated \(termination)")
        }
      }.makeAsyncIterator()
    }
  }
}
