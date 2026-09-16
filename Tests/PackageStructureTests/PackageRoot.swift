import Foundation

/// Finds the files of this package on disk for the structure tests.
///
/// The tests read the files as text. They do not run `swift package describe`,
/// because `swift test` holds the build lock while the tests run.
enum PackageRoot {
  /// The number of path parts between this file and the package root:
  /// `Tests/PackageStructureTests/PackageRoot.swift`.
  private static let depthBelowRoot = 3

  /// The directory that holds `Package.swift`.
  static let url: URL = {
    var directory = URL(filePath: #filePath)
    for _ in 0..<depthBelowRoot {
      directory.deleteLastPathComponent()
    }
    return directory
  }()

  /// The URL of a path relative to the package root.
  ///
  /// - Parameter relativePath: A path such as `Sources/AgentViewKit`.
  /// - Returns: The absolute file URL.
  static func file(_ relativePath: String) -> URL {
    url.appending(path: relativePath)
  }

  /// The text of a file relative to the package root.
  ///
  /// - Parameter relativePath: A path such as `Package.swift`.
  /// - Returns: The file contents, decoded as UTF-8.
  static func text(of relativePath: String) throws -> String {
    try String(contentsOf: file(relativePath), encoding: .utf8)
  }
}
