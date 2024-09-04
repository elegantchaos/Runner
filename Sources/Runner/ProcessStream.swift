import Foundation

extension Runner {
  /// Helper for managing the output of a process.
  public struct ProcessStream: Sendable {
    /// A custom pipe to capture output, if we're in capture mode.
    let pipe: Pipe?

    /// The file to capture output, if we're not capturing.
    let handle: FileHandle?

    /// Byte stream of the captured output.
    /// If we're not capturing, this will be a no-op stream that's empty
    /// so that client code has a consistent interface to work with.
    let bytes: Pipe.AsyncBytes

    /// Return a byte stream for the given mode.
    /// If the mode is .forward, we use the standard handle for the process.
    /// If the mode is .capture, we make a new pipe and use that.
    /// If the mode is .both, we make a new pipe and set it up to forward to the standard handle.
    /// If the mode is .discard, we use /dev/null.
    init(mode: Mode, standardHandle: FileHandle) {
      switch mode {
        case .forward:
          pipe = nil
          handle = standardHandle
          bytes = Pipe.noBytes

        case .capture:
          pipe = Pipe()
          handle = pipe!.fileHandleForReading
          bytes = pipe!.bytes

        case .both:
          pipe = Pipe()
          handle = pipe!.fileHandleForReading
          bytes = pipe!.bytesForwardingTo(standardHandle)

        case .discard:
          pipe = nil
          handle = FileHandle.nullDevice
          bytes = Pipe.noBytes
      }
    }
  }
}
