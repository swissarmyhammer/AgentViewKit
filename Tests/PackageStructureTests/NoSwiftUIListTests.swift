import EditorTestSupport
import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// Holds the rule that no view stands its rows on a SwiftUI `List`: the user
/// decision that EditorKit ^7wt12an applied to each sibling package.
///
/// A `List` is a native table, with a selection, arrow keys and a background of
/// its own. The selection and the keys of the kit are its command scopes, the
/// `nav.*` commands of EditorKit and its jump mode, and its rows stand in a
/// `LazyVStack` inside a `ScrollView` (`AgentRowList`). The scan reads the
/// Swift files of the kit, of its style library, of the demo support and of the
/// demo app, one line at a time with the source scan of EditorTestSupport. A
/// code line that holds the word `List` followed by `(` or `{` is a finding. A
/// `//` comment line is not code, so a comment may name a list.
@Suite struct NoSwiftUIListTests {
  /// The directories that the scan reads, relative to the package root: the
  /// kit, its style library, the demo support and the demo app.
  static let scannedPaths = [
    KitSourceFiles.kitPath,
    KitSourceFiles.stylePath,
    "Sources/DemoSupport",
    "Examples/AgentViewKitDemo",
  ]

  /// The name of the SwiftUI list view.
  static let listName = "List"

  /// The pattern of a list: `List` as a whole word, then `(` or `{`, with any
  /// white space between them, such as `List(items)` or `List {`.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var listPattern: Regex<AnyRegexOutput> {
    Regex(
      Regex {
        WordPattern.wholeWord(listName)
        ZeroOrMore(.whitespace)
        ChoiceOf {
          "("
          "{"
        }
      })
  }

  /// The files of one scanned directory.
  ///
  /// - Parameter path: The directory, relative to the package root.
  /// - Returns: The Swift files below the directory.
  /// - Throws: The error of `PackageFiles.file(_:)` when the directory is not
  ///   in the package.
  static func files(below path: String) throws -> [URL] {
    swiftFiles(under: try PackageFiles.file(path))
  }

  /// Finds the lists in `files`.
  ///
  /// - Parameter files: The Swift files to read.
  /// - Returns: `<path>:<line>: <text>` for each code line that holds a list,
  ///   with the path relative to the package root.
  /// - Throws: The error of a file read.
  static func lists(in files: [URL]) throws -> [String] {
    try sourceScanViolations(in: files, matching: listPattern, where: isSourceCodeLine) { file, index, line in
      let path = (try? PackageFiles.relativePath(of: file, to: PackageFiles.root)) ?? file.path
      return "\(path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))"
    }
  }

  @Test func thePatternFindsAListAsAWholeWordOnly() throws {
    let lines = [
      "List(items) { item in",
      "List {",
      "SwiftUI.List(selection: $selection) {",
      "List{",
      "TaskList(entries)",
      "AgentRowList(items, id: \\.name)",
      "let list = Listing()",
      "// List {",
    ]

    let found = lines.filter { isSourceCodeLine($0) && (try? Self.listPattern.firstMatch(in: $0)) != nil }

    #expect(found == ["List(items) { item in", "List {", "SwiftUI.List(selection: $selection) {", "List{"])
  }

  @Test(arguments: scannedPaths)
  func eachScannedDirectoryHasSwiftFiles(path: String) throws {
    #expect(!(try Self.files(below: path)).isEmpty, "The scan reads no file below \(path).")
  }

  @Test func noViewStandsItsRowsOnASwiftUIList() throws {
    let files = try Self.scannedPaths.flatMap(Self.files(below:))

    let found = try Self.lists(in: files)

    #expect(found.isEmpty, "Stand the rows in an AgentRowList, not a SwiftUI List: \(found)")
  }
}
