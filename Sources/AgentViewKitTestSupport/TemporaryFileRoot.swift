import Foundation

/// A temporary directory with files, for the tests that read the disk.
public struct TemporaryFileRoot: ~Copyable {
  /// The directory.
  public let url: URL

  /// Makes a directory with `files`. A path that ends in `/` is a directory.
  ///
  /// - Parameter files: The paths to make, relative to the directory.
  public init(files: [String]) throws {
    url = FileManager.default.temporaryDirectory
      .appending(path: "FileReferenceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    for file in files {
      let item = url.appending(path: file)
      if file.hasSuffix("/") {
        try FileManager.default.createDirectory(at: item, withIntermediateDirectories: true)
      } else {
        try FileManager.default.createDirectory(
          at: item.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(file.utf8).write(to: item)
      }
    }
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }
}
