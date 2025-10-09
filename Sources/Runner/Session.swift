// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ChaosByteStreams
import Foundation

extension Runner {

  public struct Session: Sendable {
    /// Captured output stream from the process.
    public let stdout: Output

    /// Capture error stream from the process.
    public let stderr: Output

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
      _ e: @autoclosure @Sendable @escaping () async -> Swift.Error?
    ) async throws {
      let s = await waitUntilExit()
      if s != .succeeded {
        debug("failed")

        guard var errorToThrow = await e() else {
          debug("no error to throw")
          return
        }


        let runnerError = errorToThrow as? Runner.Error
        let runnerDescription = await runnerError?.description(for: self)

        #if DEBUG
          // in debug, we always wrap the error to add the state, stdout and stderr
          // to the description
          let wrappedDescription = """
            \(runnerDescription ?? errorToThrow.localizedDescription)

            State was \(state).

            Output was:
            \(await stdout.string)

            Error was:
            \(await stderr.string)
            """

          errorToThrow = Runner.WrappedError(error: errorToThrow, description: wrappedDescription)

        #else
          // in release, we only wrap if it's a Runner.Error that has provided a session-specific description
          if let runnerDescription {
            errorToThrow = Runner.WrappedError(error: errorToThrow, description: runnerDescription)
          }
        #endif

        debug("throwing \(errorToThrow)")
        throw errorToThrow
      }
    }
  }
}
