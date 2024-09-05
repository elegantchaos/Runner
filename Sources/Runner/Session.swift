// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ChaosByteStreams
import Foundation

extension Runner {

  public struct Session: Sendable {
    /// Internal info about the output from the process.
    internal let outInfo: ProcessStream

    /// Internal info about the error output from the process.
    internal let errInfo: ProcessStream

    /// Byte stream of the captured output.
    public var stdout: DataBuffer.AsyncBytes {
      get async { await outInfo.buffer?.makeBytes() ?? DataBuffer.noBytes }
    }

    /// Byte stream of the captured error output.
    public var stderr: DataBuffer.AsyncBytes {
      get async { await errInfo.buffer?.makeBytes() ?? DataBuffer.noBytes }
    }
    /// One-shot stream of the state of the process.
    /// This will only ever yield one value, and then complete.
    /// You can await this value if you want to wait for the process to finish.
    public let state: AsyncStream<RunState>

    /// Check the state of the process and perform an action if it failed.
    nonisolated public func ifFailed(
      _ e: @Sendable @escaping () async -> Void
    ) async throws {
      debug("checking state")
      var s: RunState?
      for await state in self.state {
        s = state
        break
      }

      debug("got state")
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
      debug("checking state")
      var s: RunState?
      for await state in self.state {
        s = state
        break
      }
      debug("state is \(String(describing: s))")

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
