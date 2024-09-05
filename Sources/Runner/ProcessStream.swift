import Foundation

extension Runner {
  /// Helper for managing the output of a process.
  public struct ProcessStream: Sendable {
    public typealias ByteStream = Pipe.DispatchAsyncBytes

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

    /// Byte stream of the captured output.
    /// If we're not capturing, this will be a no-op stream that's empty
    /// so that client code has a consistent interface to work with.
    let bytes: ByteStream

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
          bytes = Pipe.dispatchNoBytes

        case .capture:
          pipe = Pipe()
          handle = pipe!.fileHandleForReading
          bytes = pipe!.dispatchBytes

        case .both:
          pipe = Pipe()
          handle = pipe!.fileHandleForReading
          bytes = pipe!.dispatchBytesForwardingTo(standardHandle)

        case .discard:
          pipe = nil
          handle = FileHandle.nullDevice
          bytes = Pipe.dispatchNoBytes
      }
    }
  }
}

extension Pipe {
  static var noBytes2: FileHandle.AsyncBytes {
    FileHandle.nullDevice.bytes
  }
}
