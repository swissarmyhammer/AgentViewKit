import Foundation

/// Finds and reads the files of this package on disk for a test.
///
/// This is the one place that finds the package root. The structure tests
/// and the kit tests use it. The tests read the files as text. They do not
/// run `swift package describe`, because `swift test` holds the build lock
/// while the tests run.
public enum PackageFiles {
  /// The error when a relative path does not stay in the package root.
  public struct PathOutsideRoot: Error, Equatable {
    /// The relative path that the caller gave.
    public let relativePath: String

    /// Makes the error for a path.
    ///
    /// - Parameter relativePath: The relative path that the caller gave.
    public init(relativePath: String) {
      self.relativePath = relativePath
    }
  }

  /// The number of path parts between this file and the package root:
  /// `Sources/PackageFileSupport/PackageFiles.swift`.
  private static let depthBelowRoot = 3

  /// The directory that holds `Package.swift`.
  public static let root: URL = {
    var directory = URL(filePath: #filePath)
    for _ in 0..<depthBelowRoot {
      directory.deleteLastPathComponent()
    }
    return directory.standardizedFileURL
  }()

  /// The URL of a path relative to the package root.
  ///
  /// - Parameter relativePath: A path such as `Sources/AgentViewKit`.
  /// - Returns: The absolute file URL, in the package root.
  /// - Throws: ``PathOutsideRoot`` when `relativePath` is absolute, has a `..`
  ///   part, or resolves to a location outside the package root.
  public static func file(_ relativePath: String) throws -> URL {
    let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
    guard !relativePath.hasPrefix("/"), !parts.contains("..") else {
      throw PathOutsideRoot(relativePath: relativePath)
    }
    let url = root.appending(path: relativePath).standardizedFileURL
    let rootPath = root.path(percentEncoded: false)
    let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    guard url.path(percentEncoded: false).hasPrefix(prefix) else {
      throw PathOutsideRoot(relativePath: relativePath)
    }
    return url
  }

  /// The text of a file relative to the package root.
  ///
  /// - Parameter relativePath: A path such as `Docs/decisions/usage-model.md`.
  /// - Returns: The file contents, decoded as UTF-8.
  /// - Throws: ``PathOutsideRoot`` when the path does not stay in the package
  ///   root, or the error of `String(contentsOf:encoding:)` when the file
  ///   cannot be read or is not UTF-8.
  public static func text(of relativePath: String) throws -> String {
    try String(contentsOf: file(relativePath), encoding: .utf8)
  }

  /// The file extension of a Swift source file.
  private static let swiftExtension = "swift"

  /// The Swift files below a directory, in its subdirectories too.
  ///
  /// A directory that does not exist is an error. A wrong path must fail the
  /// test, not scan zero files and pass.
  ///
  /// - Parameter directory: The directory to read.
  /// - Returns: The URL of each Swift file below `directory`.
  /// - Throws: `CocoaError(.fileReadNoSuchFile)` when `directory` is not an
  ///   existing directory.
  public static func swiftFiles(in directory: URL) throws -> [URL] {
    var isDirectory: ObjCBool = false
    let path = directory.path(percentEncoded: false)
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    guard exists, isDirectory.boolValue,
      let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
    else {
      throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: path])
    }
    return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == swiftExtension }
  }
}
