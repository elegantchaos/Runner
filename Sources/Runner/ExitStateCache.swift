// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  All code (c) 2026 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Reads a session's one-shot state stream once, and remembers the result,
/// so that the final state can be awaited any number of times.
actor ExitStateCache {
  /// The task reading the state stream, once the first caller has started it.
  private var task: Task<RunState, Never>?

  /// Returns the final state, reading it from the stream on first use.
  func value(from stream: AsyncStream<RunState>) async -> RunState {
    if let task { return await task.value }

    let task = Task {
      for await state in stream { return state }
      fatalError("somehow process didn't yield a state")
    }
    self.task = task
    return await task.value
  }
}
