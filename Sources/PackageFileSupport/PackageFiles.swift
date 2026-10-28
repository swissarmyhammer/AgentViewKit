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

  /// The error when a file is not below the directory that a relative path
  /// starts at.
  public struct FileOutsideDirectory: Error, Equatable {
    /// The file that the caller gave.
    public let file: URL
    /// The directory that the caller gave.
    public let directory: URL

    /// Makes the error for a file and a directory.
    ///
    /// - Parameters:
    ///   - file: The file that the caller gave.
    ///   - directory: The directory that the caller gave.
    public init(file: URL, directory: URL) {
      self.file = file
      self.directory = directory
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

  /// The path of a file relative to a directory that holds it.
  ///
  /// The function resolves each symlink in both URLs before it compares
  /// them. Thus the result does not depend on the place of the checkout:
  /// for example, on macOS `/tmp` is a link to `/private/tmp`, and a file
  /// enumerator can give either form. The function compares path parts, not
  /// the length of a text prefix.
  ///
  /// - Parameters:
  ///   - file: The file, at some depth below `directory`.
  ///   - directory: The directory that the relative path starts at.
  /// - Returns: The path parts of `file` below `directory`, joined with `/`,
  ///   such as `Sources/AgentViewKit/Content/MathView.swift`.
  /// - Throws: ``FileOutsideDirectory`` when `file` is not below
  ///   `directory` after the symlinks are resolved.
  public static func relativePath(of file: URL, to directory: URL) throws -> String {
    let fileParts = file.resolvingSymlinksInPath().pathComponents
    let directoryParts = directory.resolvingSymlinksInPath().pathComponents
    guard fileParts.count > directoryParts.count, fileParts.starts(with: directoryParts) else {
      throw FileOutsideDirectory(file: file, directory: directory)
    }
    return fileParts.dropFirst(directoryParts.count).joined(separator: "/")
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
    try items(below: directory, options: []).filter { $0.pathExtension == swiftExtension }
  }

  /// The files below a directory with one of some extensions, in its
  /// subdirectories too, with no hidden item.
  ///
  /// The scan skips each hidden file and each hidden directory with all that
  /// it holds, such as `.git`, `.build` and `.kanban` below the package root.
  /// A directory that does not exist is an error, as in ``swiftFiles(in:)``.
  ///
  /// - Parameters:
  ///   - directory: The directory to read.
  ///   - extensions: The file extensions to keep, without the dot, such as
  ///     `md`.
  /// - Returns: The URL of each file below `directory` with an extension in
  ///   `extensions`.
  /// - Throws: `CocoaError(.fileReadNoSuchFile)` when `directory` is not an
  ///   existing directory.
  public static func visibleFiles(in directory: URL, withExtensions extensions: Set<String>) throws -> [URL] {
    try items(below: directory, options: .skipsHiddenFiles).filter { extensions.contains($0.pathExtension) }
  }

  /// Each item below a directory, in its subdirectories too.
  ///
  /// - Parameters:
  ///   - directory: The directory to read.
  ///   - options: The options of the file enumerator.
  /// - Returns: The URL of each file and each directory below `directory`.
  /// - Throws: `CocoaError(.fileReadNoSuchFile)` when `directory` is not an
  ///   existing directory.
  private static func items(
    below directory: URL,
    options: FileManager.DirectoryEnumerationOptions
  ) throws -> [URL] {
    var isDirectory: ObjCBool = false
    let path = directory.path(percentEncoded: false)
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    guard exists, isDirectory.boolValue,
      let enumerator = FileManager.default.enumerator(
        at: directory, includingPropertiesForKeys: nil, options: options)
    else {
      throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: path])
    }
    return enumerator.compactMap { $0 as? URL }
  }

  /// The relative path and the text of each Swift file below a directory.
  ///
  /// This is the one traversal for a test that reads Swift sources: it lists
  /// the files with ``swiftFiles(in:)``, makes each path with
  /// ``relativePath(of:to:)``, and reads each file as UTF-8 text.
  ///
  /// - Parameters:
  ///   - directory: The directory to read. The scan includes subdirectories.
  ///   - base: The directory that the path of each file is relative to.
  /// - Returns: The path and the text of each file, sorted by path.
  /// - Throws: `CocoaError(.fileReadNoSuchFile)` when `directory` is not an
  ///   existing directory, ``FileOutsideDirectory`` when a file is not below
  ///   `base`, or the error of `String(contentsOf:encoding:)` when a file
  ///   cannot be read or is not UTF-8.
  public static func swiftFileTexts(below directory: URL, relativeTo base: URL) throws -> [(path: String, text: String)] {
    try swiftFiles(in: directory)
      .map { url in
        (path: try relativePath(of: url, to: base), text: try String(contentsOf: url, encoding: .utf8))
      }
      .sorted { $0.path < $1.path }
  }
}
