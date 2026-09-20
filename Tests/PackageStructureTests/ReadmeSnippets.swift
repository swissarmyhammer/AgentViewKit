import Foundation
import PackageFileSupport

/// The compiled snippets of `README.md` (plan.md §1).
///
/// A snippet is a Swift code block of the README whose first line is
/// `// readme:compile <Name>`. `Scripts/extract-readme-snippets.sh` writes
/// each snippet to `Examples/ReadmeSnippets/Snippets/<Name>.swift`, and the
/// `ReadmeSnippetsTests` target compiles that directory. Thus a snippet that
/// does not compile fails the build.
///
/// This type reads the README the same way as the script: a block opens on
/// a line that is exactly ```` ```swift ```` and closes on a line that is
/// exactly ```` ``` ````. `ReadmeSnippetTests` holds the README and the files
/// equal, so that `swift test` finds a snippet that changed in one place
/// only.
enum ReadmeSnippets {
  /// One compiled snippet of the README.
  struct Snippet: Equatable {
    /// The text after the marker on the first line. It is the file name
    /// without `.swift`.
    let name: String

    /// The lines of the block, with the marker line, joined with newlines.
    let body: String
  }

  /// The text that starts the first line of a snippet.
  static let marker = "// readme:compile"

  /// The line that opens a Swift block.
  static let openFence = "```swift"

  /// The line that closes a block.
  static let closeFence = "```"

  /// The path of the README, relative to the package root.
  static let readmePath = "README.md"

  /// The path of the snippet files, relative to the package root.
  static let snippetsPath = "Examples/ReadmeSnippets/Snippets"

  /// The Swift blocks of a Markdown text, without the fences.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The lines of each block, joined with newlines, in text order.
  static func swiftBlocks(in markdown: String) -> [String] {
    // The scan keeps the closed blocks, and the lines of the open block or
    // `nil` outside a block.
    let scan = markdown.components(separatedBy: "\n").reduce(
      into: (closed: [String](), open: [String]?.none)
    ) { scan, line in
      switch (scan.open, line) {
      case (nil, openFence):
        scan.open = []
      case (nil, _):
        break
      case (let block?, closeFence):
        scan.closed.append(block.joined(separator: "\n"))
        scan.open = nil
      case (let block?, _):
        scan.open = block + [line]
      }
    }
    return scan.closed
  }

  /// The snippets of a Markdown text: the Swift blocks whose first line
  /// starts with ``marker``.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The snippets, in text order.
  static func snippets(in markdown: String) -> [Snippet] {
    swiftBlocks(in: markdown).compactMap { body in
      guard let firstLine = body.components(separatedBy: "\n").first, firstLine.hasPrefix(marker) else {
        return nil
      }
      let name = firstLine.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
      return Snippet(name: name, body: body)
    }
  }

  /// The number of lines of a text that start with ``marker``.
  ///
  /// - Parameter text: The text to count in.
  /// - Returns: The count.
  static func markerLineCount(in text: String) -> Int {
    text.components(separatedBy: "\n").filter { $0.hasPrefix(marker) }.count
  }

  /// The README text.
  static func readme() throws -> String {
    try PackageFiles.text(of: readmePath)
  }

  /// The snippets of the README.
  static func readmeSnippets() throws -> [Snippet] {
    try snippets(in: readme())
  }

  /// The text of each snippet file on disk, keyed by the file name without
  /// `.swift`.
  static func snippetFiles() throws -> [String: String] {
    let files = try PackageFiles.swiftFiles(in: PackageFiles.file(snippetsPath))
    return Dictionary(
      uniqueKeysWithValues: try files.map { file in
        (file.deletingPathExtension().lastPathComponent, try String(contentsOf: file, encoding: .utf8))
      })
  }
}
