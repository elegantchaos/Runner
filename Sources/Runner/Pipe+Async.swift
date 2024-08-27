import Foundation

extension Pipe {
  public struct AsyncBytes: AsyncSequence, Sendable {
    public typealias Element = UInt8

    /// Pipe we're reading from.
    let pipe: Pipe?

    /// Optional file handle to copy read bytes to.
    let forwardHandle: FileHandle?

    /// Make an iterator that reads data from the pipe's file handle
    /// and outputs it as a byte sequence.
    public func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
      let fh = forwardHandle
      return AsyncStream { continuation in
        // if we have no pipe, return an empty sequence
        guard let pipe else {
          continuation.finish()
          return
        }

        pipe.fileHandleForReading.readabilityHandler = { @Sendable handle in
          let data = handle.availableData

          guard !data.isEmpty else {
            continuation.finish()
            return
          }

          fh?.write(data)
          for byte in data {
            continuation.yield(byte)
          }
        }

        continuation.onTermination = { _ in
          pipe.fileHandleForReading.readabilityHandler = nil
        }
      }.makeAsyncIterator()
    }
  }

  /// Return an empty sequence
  public static var noBytes: AsyncBytes { AsyncBytes(pipe: nil, forwardHandle: nil) }

  /// Return byte sequence
  public var bytes: AsyncBytes { AsyncBytes(pipe: self, forwardHandle: nil) }

  public func bytesForwardingTo(_ forwardHandle: FileHandle) -> AsyncBytes {
    AsyncBytes(pipe: self, forwardHandle: forwardHandle)
  }
}
