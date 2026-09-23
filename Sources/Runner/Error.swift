// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Errors conforming to this protocol can provide an async method which
/// builds a description of themselves. The function has access to the session in which
/// the error occurred, and so can use captured output, and the termination status
/// (via `session.waitUntilExit()`), to provide a more detailed error message.
///
/// Conformance is optional. When `Session.throwIfFailed` is given any other error,
/// it appends the captured stderr to the error's localized description.
extension Runner {
  public protocol Error: Swift.Error, Sendable {
    func description(for session: Runner.Session) async -> String
  }

  /// A wrapped error that includes an expanded description,
  /// along with the original error.
  public struct WrappedError: Swift.Error, LocalizedError, Sendable {
    public let error: Swift.Error
    public let description: String

    public var errorDescription: String? { description }
  }
}
