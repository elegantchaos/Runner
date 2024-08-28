import Foundation

extension URL {
  /// Create a URL to an item in the PATH.
  /// Returns nil if it can't find the item.
  ///
  /// Note that the item doesn't have to be an
  /// executable, and can contain subdirectories.
  public init?(inPath item: String) {
    let fm = FileManager.default
    if let path = ProcessInfo.processInfo.environment["PATH"] {
      for root in path.split(separator: ":") {
        let url = URL(fileURLWithPath: String(root)).appendingPathComponent(item)
        if fm.fileExists(atPath: url.path) {
          self = url
          return
        }
      }
    }

    return nil
  }

  /// Create a URL to an item in the PATH.
  /// Returns a fallback URL if it can't find the item.
  public init(inPath item: String, fallback: String) {
    self = URL(inPath: item) ?? URL(fileURLWithPath: fallback)
  }
}
