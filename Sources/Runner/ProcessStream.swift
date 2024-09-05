import Foundation

public actor DataBuffer {
  var data = Data()
  var continuations: [AsyncStream<UInt8>.Continuation] = []

  /// Append data to the buffer.
  /// We'll notify all continuations that new data is available.
  func append(_ bytes: Data) {
    assert(!bytes.isEmpty)
    data.append(bytes)
    for continuation in continuations {
      for byte in bytes { continuation.yield(byte) }
    }
  }

  /// Finish the buffer.
  /// This means that no more data will be added to the buffer.
  /// We'll notify all continuations that the buffer is done.
  func finish() {
    for continuation in continuations { continuation.finish() }
    continuations.removeAll()
  }

  /// Add a continuation to the buffer.
  /// We immediately yield all current data in the buffer to the continuation.
  /// When new data is available, we'll yield it to the continuation.
  func registerContinuation(_ continuation: AsyncStream<UInt8>.Continuation) {
    continuations.append(continuation)
    if !data.isEmpty { for byte in data { continuation.yield(byte) } }
  }

  func removeContinuation(_ continuation: AsyncStream<UInt8>.Continuation) {}

  /// Return a byte sequence that reads from this buffer.
  func makeBytes() -> AsyncBytes { AsyncBytes(buffer: self) }

  /// A byte sequence that is empty.
  static var noBytes: AsyncBytes { AsyncBytes(buffer: nil) }

  /// A byte sequence that reads from a buffer.
  public struct AsyncBytes: AsyncSequence, Sendable {
    public typealias Element = UInt8

    /// Buffer we're reading from.
    let buffer: DataBuffer?

    /// Make an iterator that reads data from the pipe's file handle
    /// and outputs it as a byte sequence.
    public func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
      return AsyncStream { continuation in
        guard let buffer else {
          continuation.finish()
          return
        }
        Task { await buffer.registerContinuation(continuation) }
        continuation.onTermination = { termination in
          Task { await buffer.removeContinuation(continuation) }
        }
      }.makeAsyncIterator()
    }
  }
}

extension Runner {
  /// Helper for managing the output of a process.
  public struct ProcessStream: Sendable {

    /// The mode for handling the stream.
    public enum Mode {
      /// Forward the output to stdout/stderr.
      case forward
      /// Capture the output.
      case capture
      /// Capture the output and forward it to stdout/stderr.
      case both
      /// Discard the output.
      case discard
    }

    /// A custom pipe to capture output, if we're in capture mode.
    let pipe: Pipe?

    /// The file to capture output, if we're not capturing.
    let handle: FileHandle

    let buffer: DataBuffer?

    /// Return a byte stream for the given mode.
    /// If the mode is .forward, we use the standard handle for the process.
    /// If the mode is .capture, we make a new pipe and use that.
    /// If the mode is .both, we make a new pipe and set it up to forward to the standard handle.
    /// If the mode is .discard, we use /dev/null.
    init(mode: Mode, standardHandle: FileHandle) {
      switch mode { case .forward:
        pipe = nil
        handle = standardHandle
        buffer = nil

        case .capture:
          pipe = Pipe()
          handle = pipe!.fileHandleForReading
          let buffer = DataBuffer()
          self.buffer = buffer
          handle.readabilityHandler = { handle in
            let data = handle.availableData
            Task {
              if data.isEmpty {
                await buffer.finish()
              }
              else {
                await buffer.append(data)
              }
            }
          }

        case .both:
          pipe = Pipe()
          handle = pipe!.fileHandleForReading
          let buffer = DataBuffer()
          self.buffer = buffer
          handle.readabilityHandler = { handle in
            let data = handle.availableData
            try? standardHandle.write(contentsOf: data)
            Task {
              if data.isEmpty {
                await buffer.finish()
              }
              else {
                await buffer.append(data)
              }
            }
          }

        case .discard:
          pipe = nil
          handle = FileHandle.nullDevice
          buffer = nil
      }
    }
  }
}

extension Pipe {
  static var noBytes2: FileHandle.AsyncBytes { FileHandle.nullDevice.bytes }
}
