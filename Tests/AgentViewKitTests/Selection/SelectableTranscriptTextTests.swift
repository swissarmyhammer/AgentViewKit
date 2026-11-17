@testable import AgentViewKit
import Foundation
import Testing

/// Each text of the transcript is in a component that takes part in the one
/// selection of the thread (Docs/decisions/text-selection.md).
///
/// The unit tests mount no view, so the tests read the view types and the
/// source of the kit. Two facts hold:
///
/// - The selectable Textual components (Markdown prose and plain text) have
///   the region modifier in their body. EditorKit views join the region by
///   themselves.
/// - No view of the kit selects text with a selection that the kit cannot
///   clear: no SwiftUI `.textSelection(.enabled)`, and no Textual selection
///   or `StructuredText` outside the region modifier.
@MainActor @Suite struct SelectableTranscriptTextTests {
  /// The name of the region modifier type.
  static let region = "TextualSelectionRegion"

  /// The folder of the package.
  static let packageRoot = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  /// The Swift files of a source target, with their text.
  ///
  /// - Parameter target: The folder name of the target.
  /// - Returns: The path of each file in the target, and its text.
  static func sources(of target: String) throws -> [(path: String, text: String)] {
    let folder = packageRoot.appending(path: "Sources/\(target)")
    let enumerator = try #require(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil))
    return try enumerator.compactMap { $0 as? URL }
      .filter { $0.pathExtension == "swift" }
      .map { url in (url.path(percentEncoded: false), try String(contentsOf: url, encoding: .utf8)) }
  }

  /// The lines of `text` that are code, not comments.
  static func codeLines(of text: String) -> [String] {
    text.split(separator: "\n", omittingEmptySubsequences: false)
      .map { String($0) }
      .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
  }

  @Test func markdownProseIsASelectionRegion() {
    let body = MarkdownProse(text: "Some *text*.").body
    #expect(String(describing: type(of: body)).contains(Self.region))
  }

  @Test func plainTextIsASelectionRegion() {
    let body = SelectableText("A command").body
    #expect(String(describing: type(of: body)).contains(Self.region))
  }

  /// Plain text is a ``SelectableText``. Markdown (``RenderedMarkdownView``)
  /// and code (``CodeBlockView``) show in an EditorKit `EditorView`, which
  /// joins the selection of the thread by itself (D185).
  @Test func attachmentTextIsASelectionRegion() {
    let body = AttachmentTextContent(text: "Notes", type: .plainText, filename: nil).body
    let name = String(describing: type(of: body))
    #expect(name.contains("SelectableText"))
    #expect(name.contains("RenderedMarkdownView"))
    #expect(name.contains("CodeBlockView"))
  }

  @Test func kitHasNoSwiftUITextSelection() throws {
    var found: [String] = []
    for target in ["AgentViewKit", "AgentViewKitStyle"] {
      for (path, text) in try Self.sources(of: target) where !path.hasSuffix("SelectableTextStyle.swift") {
        for line in Self.codeLines(of: text) where line.contains(".textSelection(") && !line.contains(".textual.") {
          found.append("\(path): \(line)")
        }
      }
    }
    #expect(found.isEmpty, "\(found)")
  }

  @Test func eachTextualTextIsASelectionRegion() throws {
    var found: [String] = []
    for (path, text) in try Self.sources(of: "AgentViewKit") where !path.hasSuffix("TextualSelectionRegion.swift") {
      let lines = Self.codeLines(of: text)
      for (index, line) in lines.enumerated() {
        if line.contains(".textual.textSelection(") {
          found.append("\(path): \(line)")
        }
        guard line.contains("StructuredText(") else { continue }
        let following = lines[index..<min(lines.count, index + 8)].joined(separator: "\n")
        if !following.contains(".selectableTextualRegion()") {
          found.append("\(path): \(line)")
        }
      }
    }
    #expect(found.isEmpty, "\(found)")
  }
}
