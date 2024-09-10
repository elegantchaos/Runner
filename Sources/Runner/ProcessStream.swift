import ChaosByteStreams
import Foundation

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
    init(mode: Mode, standardHandle: FileHandle, name: String) {
      switch mode { case .forward:
        pipe = nil
        handle = standardHandle
        buffer = nil

        case .capture:
          let (b, p, h) = Self.setupBuffer(name: name)
          self.pipe = p
          self.handle = h
          self.buffer = b

        case .both:
          let (b, p, h) = Self.setupBuffer(name: name, forwardingTo: standardHandle)
          self.pipe = p
          self.handle = h
          self.buffer = b

        case .discard:
          pipe = nil
          handle = FileHandle.nullDevice
          buffer = nil
      }
    }

    static func setupBuffer(
      name: String,
      forwardingTo forwardHandle: FileHandle? = nil
    ) -> (DataBuffer, Pipe, FileHandle) {
      let pipe = Pipe()
      let handle = pipe.fileHandleForReading
      let buffer = DataBuffer()
      handle.readabilityHandler = { handle in
        let data = handle.availableData
        try? forwardHandle?.write(contentsOf: data)
        if data.isEmpty {
          debug("\(name) closing")
          handle.readabilityHandler = nil
          Task.detached {
            await buffer.close()
            debug("\(name) closed - '\(String(data: await buffer.buffer, encoding: .utf8)!)'")
          }

        }
        else {
          Task.detached {
            await buffer.append(data)
            debug("\(name) appended \(String(data: data, encoding: .utf8)!)")
          }
        }

      }
      return (buffer, pipe, handle)
    }

  }


}
