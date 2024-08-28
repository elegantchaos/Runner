import Foundation

extension URL {
  /// Create a URL to an item in the system path.
  /// On unix systems, this is the $PATH environment variable.
  /// Returns nil if it can't find the item.
  ///
  /// Note that the item doesn't have to be the name of an
  /// executable, and it can contain subdirectories; it just
  /// has to be in the system path somewhere.
  public init?(inSystemPathWithName item: String) {
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

  /// Create a URL to an item in the system path.
  /// On unix systems, this is the $PATH environment variable.
  /// Returns a fallback URL if it can't find the item.
  ///
  /// Note that the item doesn't have to be the name of an
  /// executable, and it can contain subdirectories; it just
  /// has to be in the system path somewhere.
  public init(inSystemPathWithName item: String, fallback: String) {
    self = URL(inSystemPathWithName: item) ?? URL(fileURLWithPath: fallback)
  }
}
