import EditorComplete
import EditorCore
import EditorDecorations
import EditorExtensions
import Foundation

/// The EditorKit completion source for `@file` references (plan.md §4.1,
/// §9 D).
///
/// The source answers when the caret is in a token that starts with `@`. The
/// text after the `@` is a path relative to the file root. The source lists
/// the entries of the directory part of the path whose names start with the
/// last part. Directories come first.
///
/// An accepted file inserts `@`, the path, and a space. An accepted directory
/// inserts `@`, the path, and a `/`, so that the user can continue into the
/// directory. The source lists entries through an EditorKit `FileSystem`. It
/// declines a path that goes up with `..` or that starts with `/`, so that it
/// never lists an entry outside the root.
///
/// EditorKit's `PathCompletionSource` needs a `/` in the token, and it reads
/// the `@` as part of the directory name. So this source does its own scan and
/// reuses the `FileSystem` contract of EditorKit.
public nonisolated struct FileReferenceSource: EditorExtensions.CompletionSource {
  /// The text that opens a file reference token.
  public static let trigger = "@"

  /// The file system that lists the entries under the root.
  let fileSystem: any FileSystem

  /// Makes a file reference source.
  ///
  /// - Parameter fileSystem: The file system that lists the entries under the
  ///   root. The path `""` names the root.
  public init(fileSystem: any FileSystem) {
    self.fileSystem = fileSystem
  }

  /// Makes a file reference source over a directory on disk.
  ///
  /// - Parameter root: The directory that the references are relative to.
  public init(root: URL) {
    self.init(fileSystem: DirectoryFileSystem(root: root))
  }

  /// The `@` opening, so that the completion engine replaces the full token
  /// when the token has no `/` or `.`.
  public var tokenOpenings: [CompletionTokenOpening] {
    [CompletionTokenOpening(text: Self.trigger)]
  }

  /// The entries that match the file reference at the caret.
  ///
  /// - Parameter context: The completion context of the engine.
  /// - Returns: The matching entries, or `nil` when the caret is not in a file
  ///   reference, the path is not safe, the directory cannot be listed, or the
  ///   query is cancelled.
  public func completions(for context: CompletionContext) async -> CompletionResult? {
    guard !Task.isCancelled, let reference = FileReference(at: context) else { return nil }
    guard let entries = try? await fileSystem.entries(at: reference.directory) else { return nil }
    guard !Task.isCancelled else { return nil }
    let items = Self.matches(of: reference.name, in: entries).enumerated().compactMap {
      reference.completion(for: $1, rank: $0)
    }
    return CompletionResult(items: items)
  }

  /// The entries whose names start with `name`, directories first and then
  /// in name order. The comparison ignores case. A name that starts with `.`
  /// shows only when `name` also starts with `.`.
  ///
  /// - Parameters:
  ///   - name: The last part of the typed path.
  ///   - entries: The entries of the directory.
  /// - Returns: The matching entries, in order.
  static func matches(of name: String, in entries: [FileSystemEntry]) -> [FileSystemEntry] {
    let query = name.lowercased()
    return
      entries
      .filter { $0.name.lowercased().hasPrefix(query) }
      .filter { query.hasPrefix(".") || !$0.name.hasPrefix(".") }
      .sorted { lhs, rhs in
        if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
      }
  }

  /// Whether `path` is a relative path that stays under the root.
  ///
  /// - Parameter path: The path after the `@`.
  /// - Returns: `false` when the path starts with `/` or has a `..` part.
  static func isSafe(_ path: String) -> Bool {
    !path.hasPrefix("/") && !path.split(separator: "/").contains("..")
  }
}

/// The `@` reference at the caret of a completion query.
nonisolated struct FileReference {
  /// The directory part of the path, without the last `/`. The root is `""`.
  let directory: String

  /// The last part of the path, after the last `/`.
  let name: String

  /// The UTF-8 offset of the `@` in the document.
  let start: Int

  /// The UTF-8 offset of the start of the range that the engine replaces.
  let replacementStart: Int

  /// Finds the reference at the caret of `context`.
  ///
  /// The reference is the run of characters that are not white space before
  /// the caret. The run must start with `@`, and the character before the
  /// `@` must be white space or the start of the line.
  ///
  /// - Parameter context: The completion context of the engine.
  /// - Returns: `nil` when the caret is not in a safe reference.
  init?(at context: CompletionContext) {
    let line = context.editor.line(containing: context.position)
    guard let caret = CompletionTokenizer.caretIndex(in: line, caret: context.position) else {
      return nil
    }
    let text = line.text
    var runStart = caret
    while runStart > text.startIndex, !text[text.index(before: runStart)].isWhitespace {
      runStart = text.index(before: runStart)
    }
    let run = text[runStart..<caret]
    guard run.hasPrefix(FileReferenceSource.trigger) else { return nil }
    let path = String(run.dropFirst(FileReferenceSource.trigger.count))
    guard FileReferenceSource.isSafe(path) else { return nil }
    if let slash = path.lastIndex(of: "/") {
      directory = String(path[..<slash])
      name = String(path[path.index(after: slash)...])
    } else {
      directory = ""
      name = path
    }
    start =
      line.range.lowerBound.utf8Offset
      + text.utf8.distance(from: text.startIndex, to: runStart)
    replacementStart = context.replacing.lowerBound.utf8Offset
  }

  /// The completion row of one entry.
  ///
  /// The engine replaces its own token, which can start after the `@`. So the
  /// inserted text is the part of the full reference from the start of that
  /// token.
  ///
  /// - Parameters:
  ///   - entry: The directory entry.
  ///   - rank: The position of the entry in the order of the source. The
  ///     sort key keeps this order when two rows have the same score.
  /// - Returns: The row, or `nil` when the token of the engine does not start
  ///   in this reference.
  func completion(for entry: FileSystemEntry, rank: Int) -> Completion? {
    let path = directory.isEmpty ? entry.name : directory + "/" + entry.name
    let reference = FileReferenceSource.trigger + path
    let offset = replacementStart - start
    guard offset >= 0, offset <= reference.utf8.count else { return nil }
    let tail = String(decoding: reference.utf8.dropFirst(offset), as: UTF8.self)
    let label = entry.isDirectory ? entry.name + "/" : entry.name
    let insert = tail + (entry.isDirectory ? "/" : " ")
    return Completion(
      label: label, insert: .text(insert), kind: .path,
      detail: directory.isEmpty ? nil : directory, filterText: tail,
      sortKey: String(format: "%08d", rank))
  }
}

/// A `FileSystem` over a directory on disk.
///
/// The `FileReferenceSource` gives only safe relative paths. The file system
/// also resolves symbolic links and declines a directory outside the root.
nonisolated struct DirectoryFileSystem: FileSystem {
  /// The directory that the path `""` names.
  let root: URL

  /// The entries directly in `directory`.
  ///
  /// - Parameter directory: A path relative to the root.
  /// - Returns: The entries, with their directory flag.
  /// - Throws: An error when the directory is outside the root or cannot be
  ///   listed.
  func entries(at directory: String) async throws -> [FileSystemEntry] {
    try Task.checkCancellation()
    let base = root.standardizedFileURL.resolvingSymlinksInPath()
    let url = base.appending(path: directory, directoryHint: .isDirectory)
      .standardizedFileURL.resolvingSymlinksInPath()
    guard Self.isInside(url, base) else {
      throw CocoaError(.fileReadNoPermission)
    }
    let contents = try FileManager.default.contentsOfDirectory(
      at: url, includingPropertiesForKeys: [.isDirectoryKey])
    return try contents.map { item in
      try Task.checkCancellation()
      let isDirectory = try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
      return FileSystemEntry(name: item.lastPathComponent, isDirectory: isDirectory)
    }
  }

  /// Whether `url` is `base` or a path under `base`.
  ///
  /// - Parameters:
  ///   - url: A resolved file URL.
  ///   - base: The resolved root.
  /// - Returns: `true` when the path of `url` is in `base`.
  static func isInside(_ url: URL, _ base: URL) -> Bool {
    let path = url.standardizedFileURL.pathComponents
    let root = base.standardizedFileURL.pathComponents
    return path.starts(with: root)
  }
}

/// The EditorKit tag detector for accepted `@file` references.
///
/// The detector finds each `@` reference whose path is in ``paths``. The
/// editor shows each match as a chip. A reference that the user types but
/// does not accept stays plain text.
nonisolated struct FileReferenceDetector: EditorDecorations.TagDetector {
  /// The kind of each match.
  static let kind = "file-reference"

  /// The paths of the accepted references, relative to the file root.
  let paths: Set<String>

  /// The accepted references in `range`.
  ///
  /// - Parameters:
  ///   - range: The range to scan.
  ///   - context: The editor context.
  /// - Returns: One match for each accepted reference.
  func detect(in range: EditorRange, context: EditorContext) -> [EditorDecorations.TagMatch] {
    guard !paths.isEmpty else { return [] }
    let text = context.text(in: range)
    let document = context.state.document
    return Self.references(in: text).compactMap { reference in
      guard paths.contains(reference.path) else { return nil }
      let lower = range.lowerBound.utf8Offset + reference.range.lowerBound
      let upper = range.lowerBound.utf8Offset + reference.range.upperBound
      return EditorDecorations.TagMatch(
        range: EditorRange(document.position(utf8Offset: lower), document.position(utf8Offset: upper)),
        kind: Self.kind, text: reference.text)
    }
  }

  /// Each `@` reference in `text`.
  ///
  /// A reference starts at an `@` at the start of the text or after white
  /// space, and ends before the next white space.
  ///
  /// - Parameter text: The text to scan.
  /// - Returns: The UTF-8 range, the full text, and the path of each
  ///   reference.
  static func references(in text: String) -> [(range: Range<Int>, text: String, path: String)] {
    text.matches(of: /@(?<path>\S+)/).compactMap { match in
      if match.range.lowerBound > text.startIndex,
        !text[text.index(before: match.range.lowerBound)].isWhitespace
      {
        return nil
      }
      let utf8 = text.utf8
      let lower = utf8.distance(from: utf8.startIndex, to: match.range.lowerBound)
      let upper = utf8.distance(from: utf8.startIndex, to: match.range.upperBound)
      return (lower..<upper, String(text[match.range]), String(match.output.path))
    }
  }
}
