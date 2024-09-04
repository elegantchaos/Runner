// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Errors conforming to this protocol can provide a description of themselves
/// which has access to the session in which they occurred, and so can
/// include stdout/stderr output, etc.
public protocol RunnerError: Error {
  func description(for session: Runner.Session) async -> String
}

/// A wrapped runner error that includes an expanded description,
/// along with the original error.
public struct WrappedRunnerError: Error, CustomStringConvertible, Sendable {
  public let error: Error
  public let description: String
}
