import Foundation

/// The files of a unified diff, with their counts (plan.md §4.1, decision 12).
///
/// This parser finds the files, the hunks, and the added and removed lines.
/// It does not render the diff. EditorKit parses and renders the diff in the
/// renderer that ``SwiftUI/View/diffRenderer(_:)`` installs.
public nonisolated enum DiffSummary {
  /// The change that a patch makes to one file.
  public enum Operation: Sendable, Hashable {
    /// The patch makes the file.
    case added

    /// The patch removes the file.
    case deleted

    /// The patch changes the lines of the file.
    case modified

    /// The patch moves the file to a new path.
    ///
    /// - Parameter from: The old path of the file.
    case renamed(from: String)
  }

  /// One hunk of a file: the `@@` header and the lines after it.
  public struct Hunk: Sendable, Hashable {
    /// The `@@` line of the hunk.
    public var header: String

    /// The context, added, and removed lines of the hunk, with their first
    /// character.
    public var lines: [String]

    /// Makes a hunk.
    ///
    /// - Parameters:
    ///   - header: The `@@` line of the hunk.
    ///   - lines: The lines of the hunk, with their first character.
    public init(header: String, lines: [String]) {
      self.header = header
      self.lines = lines
    }
  }

  /// The summary of one file in a patch.
  public struct FileSummary: Sendable, Hashable, Identifiable {
    /// The path of the file after the change. A deleted file has its old
    /// path.
    public var path: String

    /// The change that the patch makes to the file.
    public var operation: Operation

    /// The hunks of the file, in patch order.
    public var hunks: [Hunk]

    /// Makes a file summary.
    ///
    /// - Parameters:
    ///   - path: The path of the file.
    ///   - operation: The change to the file.
    ///   - hunks: The hunks of the file.
    public init(path: String, operation: Operation, hunks: [Hunk]) {
      self.path = path
      self.operation = operation
      self.hunks = hunks
    }

    /// The path of the file.
    public var id: String { path }

    /// The added and removed lines of each hunk, in patch order.
    public var changedLines: [String] {
      hunks.flatMap(\.lines).filter { line in
        line.hasPrefix(DiffSummary.addedMarker) || line.hasPrefix(DiffSummary.removedMarker)
      }
    }

    /// The number of added lines.
    public var added: Int {
      hunks.flatMap(\.lines).count(where: { $0.hasPrefix(DiffSummary.addedMarker) })
    }

    /// The number of removed lines.
    public var removed: Int {
      hunks.flatMap(\.lines).count(where: { $0.hasPrefix(DiffSummary.removedMarker) })
    }

    /// The name of the language of the file, such as "Swift".
    public var language: String {
      DiffSummary.language(forPath: path)
    }

    /// The label that VoiceOver reads for the file.
    ///
    /// The label is "<language> diff, +<added> −<removed>", such as
    /// "Swift diff, +2 −1".
    public var accessibilityLabel: String {
      DiffSummary.accessibilityLabel(language: language, added: added, removed: removed)
    }
  }

  // MARK: - Markers

  /// The first character of an added line.
  static let addedMarker = "+"

  /// The first character of a removed line.
  static let removedMarker = "-"

  /// The first character of a "No newline at end of file" line.
  static let noNewlineMarker = "\\"

  /// The start of the first header line of a file in a git patch.
  static let gitHeader = "diff --git "

  /// The start of the old path line.
  static let oldPathHeader = "--- "

  /// The start of the new path line.
  static let newPathHeader = "+++ "

  /// The start of a hunk header.
  static let hunkHeader = "@@"

  /// The start of the old path line of a rename.
  static let renameFromHeader = "rename from "

  /// The start of the new path line of a rename.
  static let renameToHeader = "rename to "

  /// The start of the mode line of an added file.
  static let newFileHeader = "new file mode"

  /// The start of the mode line of a deleted file.
  static let deletedFileHeader = "deleted file mode"

  /// The path that stands for no file.
  static let devNull = "/dev/null"

  /// The prefixes of the old and new paths in a git patch.
  static let pathPrefixes = ["a/", "b/"]

  /// The separator before the new path on a `diff --git` line.
  static let gitNewPathSeparator = " b/"

  /// The language name of a file with no extension.
  static let plainLanguage = String(localized: "Text")

  /// The language names of the common file extensions.
  static let languageNames: [String: String] = [
    "c": "C", "cc": "C++", "cpp": "C++", "cs": "C#", "css": "CSS", "go": "Go",
    "h": "C", "hpp": "C++", "html": "HTML", "java": "Java", "js": "JavaScript",
    "json": "JSON", "jsx": "JavaScript", "kt": "Kotlin", "m": "Objective-C",
    "md": "Markdown", "mm": "Objective-C++", "php": "PHP", "py": "Python",
    "rb": "Ruby", "rs": "Rust", "sh": "Shell", "sql": "SQL", "swift": "Swift",
    "toml": "TOML", "ts": "TypeScript", "tsx": "TypeScript", "txt": "Text",
    "xml": "XML", "yaml": "YAML", "yml": "YAML", "zsh": "Shell",
  ]

  // MARK: - Text

  /// The name of the language of the file at `path`.
  ///
  /// - Parameter path: The path of the file.
  /// - Returns: The name for a known extension, such as "Swift". The
  ///   extension in capitals for an unknown extension, such as "XYZ".
  ///   "Text" for a file with no extension.
  public static func language(forPath path: String) -> String {
    let pathExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
    guard !pathExtension.isEmpty else { return plainLanguage }
    return languageNames[pathExtension] ?? pathExtension.uppercased()
  }

  /// The label that VoiceOver reads for a diff.
  ///
  /// - Parameters:
  ///   - language: The name of the language of the file.
  ///   - added: The number of added lines.
  ///   - removed: The number of removed lines.
  /// - Returns: "<language> diff, +<added> −<removed>".
  public static func accessibilityLabel(language: String, added: Int, removed: Int) -> String {
    String(localized: "\(language) diff, +\(added) \u{2212}\(removed)")
  }

  // MARK: - Parse

  /// Finds the files of a unified diff or a git patch.
  ///
  /// A file starts at a `diff --git` line, or at a `---` line that is not in
  /// a hunk. The line counts in each `@@` header tell where the hunk ends,
  /// so a removed line that starts with `--` does not start a file.
  ///
  /// - Parameter gitPatch: The patch text.
  /// - Returns: One summary for each file, in patch order. Text with no file
  ///   header gives no summary.
  public static func parse(gitPatch: String) -> [FileSummary] {
    var parser = Parser()
    // A "\r\n" pair is one newline character, so this split also removes it.
    for line in gitPatch.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      parser.read(String(line))
    }
    return parser.finish()
  }

  /// Removes the `a/` or `b/` prefix and the time stamp of a path.
  ///
  /// - Parameter text: The path text after the `---` or `+++` marker.
  /// - Returns: The path, or `nil` for `/dev/null`.
  static func cleanPath(_ text: String) -> String? {
    let path = text.split(separator: "\t", maxSplits: 1).first.map(String.init) ?? text
    guard path != devNull else { return nil }
    for prefix in pathPrefixes where path.hasPrefix(prefix) {
      return String(path.dropFirst(prefix.count))
    }
    return path
  }

  /// The old and new line counts of a hunk header.
  ///
  /// - Parameter header: A line such as `@@ -1,3 +1,4 @@`.
  /// - Returns: The counts. A range with no count has one line.
  static func lineCounts(of header: String) -> (old: Int, new: Int) {
    let ranges = header.split(separator: " ")
    func count(marker: Character) -> Int {
      guard let range = ranges.first(where: { $0.first == marker }) else { return 0 }
      let parts = range.dropFirst().split(separator: ",")
      return parts.count > 1 ? Int(parts[1]) ?? 0 : 1
    }
    return (count(marker: "-"), count(marker: "+"))
  }

  /// The state of one pass over the lines of a patch.
  private struct Parser {
    /// The files that are complete.
    var files: [FileSummary] = []

    /// The file that the parser reads now.
    var current: FileSummary?

    /// The old path of the current file, from its header lines.
    var oldPath: String?

    /// The hunk that the parser reads now.
    var hunk: Hunk?

    /// The old lines that the current hunk still has.
    var oldRemaining = 0

    /// The new lines that the current hunk still has.
    var newRemaining = 0

    /// Reads one line of the patch.
    ///
    /// - Parameter line: The line, with no line break.
    mutating func read(_ line: String) {
      if hunk != nil, oldRemaining > 0 || newRemaining > 0 {
        readHunkLine(line)
        return
      }
      if hunk != nil, line.hasPrefix(DiffSummary.noNewlineMarker) {
        return
      }
      closeHunk()
      if line.hasPrefix(DiffSummary.gitHeader) {
        startFile(path: Self.gitNewPath(line))
      } else if line.hasPrefix(DiffSummary.oldPathHeader) {
        readOldPath(line)
      } else if line.hasPrefix(DiffSummary.newPathHeader), current != nil {
        readNewPath(line)
      } else if line.hasPrefix(DiffSummary.hunkHeader), current != nil {
        let counts = DiffSummary.lineCounts(of: line)
        hunk = Hunk(header: line, lines: [])
        oldRemaining = counts.old
        newRemaining = counts.new
      } else if current != nil {
        readExtendedHeader(line)
      }
    }

    /// Reads one line in a hunk and counts it down.
    ///
    /// - Parameter line: The line.
    mutating func readHunkLine(_ line: String) {
      if line.hasPrefix(DiffSummary.addedMarker) {
        newRemaining -= 1
      } else if line.hasPrefix(DiffSummary.removedMarker) {
        oldRemaining -= 1
      } else if line.hasPrefix(DiffSummary.noNewlineMarker) {
        return
      } else {
        // A context line. An empty line is a context line with no space.
        oldRemaining -= 1
        newRemaining -= 1
      }
      hunk?.lines.append(line)
    }

    /// Reads a `---` line. The line starts a file when the current file
    /// already has hunks, or when there is no current file.
    ///
    /// - Parameter line: The line.
    mutating func readOldPath(_ line: String) {
      let path = DiffSummary.cleanPath(String(line.dropFirst(DiffSummary.oldPathHeader.count)))
      if current == nil || current?.hunks.isEmpty == false {
        startFile(path: path ?? "")
      }
      oldPath = path
      if path == nil {
        current?.operation = .added
      }
    }

    /// Reads a `+++` line.
    ///
    /// - Parameter line: The line.
    mutating func readNewPath(_ line: String) {
      let path = DiffSummary.cleanPath(String(line.dropFirst(DiffSummary.newPathHeader.count)))
      guard let path else {
        current?.operation = .deleted
        if let oldPath {
          current?.path = oldPath
        }
        return
      }
      current?.path = path
    }

    /// Reads a git header line, such as a mode line or a rename line.
    ///
    /// - Parameter line: The line.
    mutating func readExtendedHeader(_ line: String) {
      if line.hasPrefix(DiffSummary.newFileHeader) {
        current?.operation = .added
      } else if line.hasPrefix(DiffSummary.deletedFileHeader) {
        current?.operation = .deleted
      } else if line.hasPrefix(DiffSummary.renameFromHeader) {
        current?.operation = .renamed(
          from: String(line.dropFirst(DiffSummary.renameFromHeader.count)))
      } else if line.hasPrefix(DiffSummary.renameToHeader) {
        current?.path = String(line.dropFirst(DiffSummary.renameToHeader.count))
      }
    }

    /// Closes the current file and starts a file at `path`.
    ///
    /// - Parameter path: The first known path of the file.
    mutating func startFile(path: String) {
      closeFile()
      current = FileSummary(path: path, operation: .modified, hunks: [])
    }

    /// Adds the current hunk to the current file.
    mutating func closeHunk() {
      if let hunk {
        current?.hunks.append(hunk)
      }
      hunk = nil
      oldRemaining = 0
      newRemaining = 0
    }

    /// Adds the current file to the complete files.
    mutating func closeFile() {
      closeHunk()
      if let current {
        files.append(current)
      }
      current = nil
      oldPath = nil
    }

    /// Closes the last file.
    ///
    /// - Returns: The files of the patch.
    mutating func finish() -> [FileSummary] {
      closeFile()
      return files
    }

    /// The new path on a `diff --git a/<old> b/<new>` line.
    ///
    /// - Parameter line: The line.
    /// - Returns: The new path, or the text after the header when the line
    ///   has no ` b/` part.
    static func gitNewPath(_ line: String) -> String {
      let paths = line.dropFirst(DiffSummary.gitHeader.count)
      guard let range = paths.range(of: DiffSummary.gitNewPathSeparator, options: .backwards)
      else {
        return String(paths)
      }
      return String(paths[range.upperBound...])
    }
  }
}
