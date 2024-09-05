import Foundation

extension Pipe {
  /// Async sequence of bytes read from the pipe's file handle.
  public struct DispatchAsyncBytes: AsyncSequence, Sendable {
    public typealias Element = UInt8

    /// Pipe we're reading from.
    let readingHandle: FileHandle?

    /// Optional file handle to copy read bytes to.
    let forwardHandle: FileHandle?

    /// Make an iterator that reads data from the pipe's file handle
    /// and outputs it as a byte sequence.
    public func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
      let fh = forwardHandle
      return AsyncStream { continuation in
        // if we have no pipe, return an empty sequence
        guard let readingHandle else {
          continuation.finish()
          return
        }

        readingHandle.readabilityHandler = { @Sendable handle in
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
          readingHandle.readabilityHandler = nil
        }
      }.makeAsyncIterator()
    }
  }

  /// Return an empty sequence
  public static var dispatchNoBytes: DispatchAsyncBytes {
    DispatchAsyncBytes(readingHandle: nil, forwardHandle: nil)
  }

  /// Return byte sequence
  public var dispatchBytes: DispatchAsyncBytes {
    DispatchAsyncBytes(readingHandle: fileHandleForReading, forwardHandle: nil)
  }

  public func dispatchBytesForwardingTo(_ forwardHandle: FileHandle) -> DispatchAsyncBytes {
    DispatchAsyncBytes(readingHandle: fileHandleForReading, forwardHandle: forwardHandle)
  }
}
