import Foundation

/// Makes files in a new temporary directory for one test.
///
/// Each value has its own directory. Call ``remove()`` at the end of the
/// test.
struct TemporaryDirectory {
  /// The directory that holds the files.
  let url: URL

  /// Makes a new, empty directory under the temporary directory of the
  /// process.
  ///
  /// - Throws: The error of the file manager when it cannot make the
  ///   directory.
  init() throws {
    url = FileManager.default.temporaryDirectory
      .appendingPathComponent("AgentViewKitTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  /// Writes a file in the directory.
  ///
  /// - Parameters:
  ///   - name: The file name, with its extension.
  ///   - contents: The bytes of the file.
  /// - Returns: The URL of the file.
  /// - Throws: The error of the write.
  func file(named name: String, contents: Data) throws -> URL {
    let fileURL = url.appendingPathComponent(name, isDirectory: false)
    try contents.write(to: fileURL)
    return fileURL
  }

  /// Removes the directory and each file in it.
  func remove() {
    try? FileManager.default.removeItem(at: url)
  }
}
