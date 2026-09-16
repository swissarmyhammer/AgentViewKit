import Foundation

/// Reads the files of this package from disk for a test.
///
/// A test that compares code with a decision file or a fixture file uses this
/// type, so that each test does not find the package root itself.
public nonisolated enum PackageFiles {
  /// The number of path parts between this file and the package root:
  /// `Sources/AgentViewKitTestSupport/PackageFiles.swift`.
  private static let depthBelowRoot = 3

  /// The directory that holds `Package.swift`.
  public static let root: URL = {
    var directory = URL(filePath: #filePath)
    for _ in 0..<depthBelowRoot {
      directory.deleteLastPathComponent()
    }
    return directory
  }()

  /// The text of a file relative to the package root.
  ///
  /// - Parameter relativePath: A path such as `Docs/decisions/usage-model.md`.
  /// - Returns: The file contents, decoded as UTF-8.
  /// - Throws: The error of `String(contentsOf:encoding:)` when the file
  ///   cannot be read or is not UTF-8.
  public static func text(of relativePath: String) throws -> String {
    try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
  }
}
