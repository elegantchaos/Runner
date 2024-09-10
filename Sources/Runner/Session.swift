// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ChaosByteStreams
import Foundation

extension Runner {

  public struct Session: Sendable {
    /// Captured output stream from the process.
    internal let stdout: ProcessStream

    /// Capture error stream from the process.
    internal let stderr: ProcessStream

    /// One-shot stream of the state of the process.
    /// This will only ever yield one value, and then complete.
    /// You can await this value if you want to wait for the process to finish.
    public let state: AsyncStream<RunState>

    /// Wait for the process to finish and return the final state.
    public func waitUntilExit() async -> RunState {
      for await state in self.state {
        debug("termination state was \(state)")
        return state
      }
      fatalError("somehow process didn't yield a state")
    }

    /// Check the state of the process and perform an action if it failed.
    nonisolated public func ifFailed(
      _ e: @Sendable @escaping () async -> Void
    ) async throws {
      let s = await waitUntilExit()
      if s != .succeeded {
        debug("failed")
        Task.detached { await e() }
      }
    }

    /// Check the state of the process and throw an error if it failed.
    /// Creation of the error is deferred until the state is known, to
    /// avoid doing extra work.
    ///
    /// The error is allowed to be nil, in which case no error is thrown.
    /// This is useful if you want to throw an error only in certain circumstances.
    public func throwIfFailed(
      _ e: @autoclosure @Sendable @escaping () async -> Error?
    ) async throws {
      let s = await waitUntilExit()
      if s != .succeeded {
        debug("failed")
        var error = await e()
        if let e = error as? RunnerError {
          let d = await e.description(for: self)
          error = WrappedRunnerError(error: e, description: d)
        }

        if let error {
          debug("throwing \(error)")
          throw error
        }
      }
    }
  }
}
