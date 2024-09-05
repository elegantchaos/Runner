// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Errors conforming to this protocol can provide a description of themselves.
/// The function that returns the description has access to the session in which
/// the error occurred, and so can use captured output and the termination status
/// to provide a more detailed error message.
public protocol RunnerError: Error, Sendable {
  func description(for session: Runner.Session) async -> String
}

/// A wrapped runner error that includes an expanded description,
/// along with the original error.
public struct WrappedRunnerError: Error, CustomStringConvertible, Sendable {
  public let error: Error
  public let description: String
}
