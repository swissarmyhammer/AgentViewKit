import EditorTestSupport
import Foundation
import Testing

/// Holds EditorKit `style.md` "Text input": **every place where the user types uses an
/// EditorKit editor** — `EditorView` for multi-line text, `SingleLineField` for one line.
///
/// The scan is the one `TextInputControlScanner` of EditorKit's `EditorTestSupport`, the
/// scan each kit runs over its own sources; AgentViewKit keeps no scanner of its own. It
/// reads `Sources/` (the kit, its style library, the demo support and the test support)
/// and `Examples/` (the demo app and the README snippets). A file that only reads
/// EditorKit's own text view goes in ``allowList`` with the reason.
@Suite struct TextInputControlScanTests {
  /// The files that may name a system text input, by package-relative path, each with
  /// the reason. None of them shows a system text input to the user.
  static let allowList: [String: String] = [
    "Sources/AgentViewKit/Input/PromptCaretProbe.swift":
      "Finds the NSTextView of EditorKit's own prompt editor with a cast, to read its caret; it makes no text view.",
  ]

  @Test("no kit, demo or example source uses a system text input")
  func noSystemTextInput() throws {
    let package = PackageFiles()
    let found = try TextInputControlScanner.violations(
      under: [package.sources, package.file("Examples")], of: package, allowing: Self.allowList)
    let report = found.map { "  \($0)" }.joined(separator: "\n")

    #expect(found.isEmpty, "Use an EditorKit editor for each text input (style.md, Text input). Found:\n\(report)")
  }
}
