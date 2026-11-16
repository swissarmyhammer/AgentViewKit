import Foundation

/// The files of a folder that is not in a git repository: a walk with a
/// limit, for the `languages` module (D194 (f)).
nonisolated public enum StatusLineFolderWalk {
  /// The most files that a walk reads.
  public static let fileLimit = 5_000

  /// The deepest folder level that a walk reads, below the folder.
  public static let depthLimit = 6

  /// The files of a folder, relative to it. The walk skips hidden files and
  /// folders, and the contents of a package such as an app.
  ///
  /// - Parameters:
  ///   - folder: The path of the folder.
  ///   - limit: The most files.
  /// - Returns: The relative paths, at most `limit`.
  public static func files(in folder: String, limit: Int = fileLimit) -> [String] {
    let root = URL(filePath: folder, directoryHint: .isDirectory).standardizedFileURL
    guard
      let enumerator = FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants])
    else { return [] }
    let rootPath = root.path(percentEncoded: false)
    let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    var files: [String] = []
    for case let url as URL in enumerator {
      if enumerator.level > depthLimit {
        enumerator.skipDescendants()
        continue
      }
      guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
      let path = url.standardizedFileURL.path(percentEncoded: false)
      guard path.hasPrefix(prefix) else { continue }
      files.append(String(path.dropFirst(prefix.count)))
      if files.count >= limit { break }
    }
    return files
  }
}

/// The languages of the code of a folder, for the `languages` module.
nonisolated public enum StatusLineLanguageDetector {
  /// The languages of a list of files, the language with the most files
  /// first.
  ///
  /// A file counts for a language when its extension is in
  /// `detect_extensions`, or its name is in `detect_files`. A folder in
  /// `detect_folders` counts one time. A language with fewer files than
  /// `minimum_files`, and a disabled language, do not show. At most
  /// `maximum` languages show. Two languages with the same count keep the
  /// order of the list.
  ///
  /// - Parameters:
  ///   - files: The relative paths of the files.
  ///   - module: The options of the module.
  /// - Returns: The languages that show, in order.
  public static func languages(of files: [String], module: LanguagesModule) -> [LanguagesModule.Language] {
    let enabled = module.languages.enumerated().filter { !$0.element.disabled }
    var extensionOwners: [String: [Int]] = [:]
    var fileOwners: [String: [Int]] = [:]
    var folderOwners: [String: [Int]] = [:]
    for (index, language) in enabled {
      for value in language.detectExtensions { extensionOwners[value.lowercased(), default: []].append(index) }
      for value in language.detectFiles { fileOwners[value, default: []].append(index) }
      for value in language.detectFolders { folderOwners[value, default: []].append(index) }
    }
    var counts: [Int: Int] = [:]
    var foundFolders: Set<Int> = []
    for path in files {
      let parts = path.split(separator: "/")
      guard let name = parts.last.map(String.init) else { continue }
      var owners = Set(fileOwners[name] ?? [])
      if let dot = name.lastIndex(of: "."), dot != name.startIndex {
        owners.formUnion(extensionOwners[name[name.index(after: dot)...].lowercased()] ?? [])
      }
      for owner in owners { counts[owner, default: 0] += 1 }
      for folder in parts.dropLast() {
        for owner in folderOwners[String(folder)] ?? [] where !foundFolders.contains(owner) {
          foundFolders.insert(owner)
          counts[owner, default: 0] += 1
        }
      }
    }
    let minimum = max(1, module.minimumFiles)
    return
      counts
      .filter { $0.value >= minimum }
      .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
      .prefix(max(0, module.maximum))
      .map { module.languages[$0.key] }
  }
}
