@testable import AgentViewKit
import Foundation
import Testing

/// Each text of the transcript is in a component that takes part in the one
/// selection of the thread (Docs/decisions/text-selection.md).
///
/// The unit tests mount no view, so the tests read the view types and the
/// source of the kit. Two facts hold:
///
/// - Each text that the user can select is an EditorKit view: an
///   `EditorView` for Markdown and code, and an `EditorLabel` for plain
///   text. Each one joins the selection region of the thread by itself.
/// - No view of the kit selects text with a selection that the kit cannot
///   clear: no SwiftUI `.textSelection(.enabled)`.
@MainActor @Suite struct SelectableTranscriptTextTests {
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

  /// The text of an answer shows in an EditorKit `EditorView`
  /// (``RenderedMarkdownView``), which joins the selection of the thread by
  /// itself (D185).
  @Test func theTextOfAnAnswerIsAnEditorView() {
    let body = ResponseView(id: "answer", markdown: "Some *text*.").body
    #expect(String(describing: type(of: body)).contains("RenderedMarkdownView"))
  }

  /// Plain text is an EditorKit `EditorLabel`. Markdown
  /// (``RenderedMarkdownView``) and code (``CodeBlockView``) show in an
  /// EditorKit `EditorView`. Each one joins the selection of the thread by
  /// itself (D185).
  @Test func attachmentTextIsASelectionRegion() {
    let body = AttachmentTextContent(text: "Notes", type: .plainText, filename: nil).body
    let name = String(describing: type(of: body))
    #expect(name.contains("EditorLabel"))
    #expect(name.contains("RenderedMarkdownView"))
    #expect(name.contains("CodeBlockView"))
  }

  @Test func kitHasNoSwiftUITextSelection() throws {
    var found: [String] = []
    for target in ["AgentViewKit", "AgentViewKitStyle"] {
      for (path, text) in try Self.sources(of: target) {
        for line in Self.codeLines(of: text) where line.contains(".textSelection(") {
          found.append("\(path): \(line)")
        }
      }
    }
    #expect(found.isEmpty, "\(found)")
  }
}
