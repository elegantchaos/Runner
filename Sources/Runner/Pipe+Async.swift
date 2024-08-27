import Foundation

extension Pipe {
  struct AsyncBytes: AsyncSequence {
    typealias Element = UInt8

    /// Pipe we're reading from.
    let pipe: Pipe?

    /// Optional file handle to copy read bytes to.
    let forwardHandle: FileHandle?

    func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
      AsyncStream { continuation in
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

          forwardHandle?.write(data)
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
  static var noBytes: AsyncBytes { AsyncBytes(pipe: nil, forwardHandle: nil) }

  /// Return byte sequence
  var bytes: AsyncBytes { AsyncBytes(pipe: self, forwardHandle: nil) }

  func bytesForwardingTo(_ forwardHandle: FileHandle) -> AsyncBytes {
    AsyncBytes(pipe: self, forwardHandle: forwardHandle)
  }
}
