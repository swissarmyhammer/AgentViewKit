import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorSwiftUI
import SwiftUI
import Testing
import Textual

@Suite(.serialized, .hostedSerially) @MainActor struct CodeBlockViewHostedTests {
  static let swiftCode = "let x = 1\nprint(x)"

  // MARK: - Identifier and label

  @Test func mountsACodeBlockElementWithTheLanguageLabel() {
    let harness = HostedViewHarness(CodeBlockView(code: "{\"a\": 1}", language: "json"))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: CodeBlockView.identifier)
    #expect(element?.label == "json code block")
    #expect(harness.element(identifier: CodeBlockView.copyIdentifier) != nil)
  }

  @Test func unknownLanguageMountsAsPlainText() {
    let harness = HostedViewHarness(CodeBlockView(code: Self.swiftCode, language: nil))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: CodeBlockView.identifier)
    #expect(element?.label == "plain text code block")
  }

  @Test func emptyLanguageMountsAsPlainText() {
    let harness = HostedViewHarness(CodeBlockView(code: Self.swiftCode, language: "  "))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: CodeBlockView.identifier)
    #expect(element?.label == "plain text code block")
  }

  @Test func theHeaderShowsTheFilename() {
    let harness = HostedViewHarness(
      CodeBlockView(code: Self.swiftCode, language: "swift", filename: "main.swift"))
    defer { harness.close() }
    harness.pump()

    let titles = harness.accessibilityElements().filter { $0.label == "main.swift" }
    #expect(!titles.isEmpty)
    #expect(harness.element(identifier: CodeBlockView.identifier)?.label == "swift code block")
  }

  // MARK: - Syntax

  @Test func aBundledLanguageAttachesSyntax() {
    let model = EditorModel("{}")
    let harness = HostedViewHarness(CodeBlockView(code: "{}", language: "JSON", model: model))
    defer { harness.close() }
    harness.pump()

    #expect(model.syntax != nil)
    #expect(model.isReadOnly)
  }

  @Test func aLanguageWithNoGrammarAttachesNoSyntax() {
    let model = EditorModel(Self.swiftCode)
    let harness = HostedViewHarness(
      CodeBlockView(code: Self.swiftCode, language: "cobol", model: model))
    defer { harness.close() }
    harness.pump()

    #expect(model.syntax == nil)
    #expect(model.textMateGrammar == nil)
  }

  @Test func aLanguageWithATextMateGrammarAttachesThatGrammar() {
    let code = "export const x = 1;"
    let model = EditorModel(code)
    let harness = HostedViewHarness(CodeBlockView(code: code, language: "ts", model: model))
    defer { harness.close() }
    harness.pump()

    #expect(model.syntax == nil)
    #expect(model.textMateGrammar?.scopeName == "source.ts")
  }

  // MARK: - Model

  @Test func aChangedCodeUpdatesTheGivenModel() {
    let source = CodeSource(code: "let x")
    let model = EditorModel("let x")
    model.isReadOnly = true
    let harness = HostedViewHarness(CodeSourceView(source: source, model: model))
    defer { harness.close() }
    harness.pump()

    source.code = "let x = 1"
    harness.pump()

    #expect(model.text == "let x = 1")
    #expect(model.isReadOnly)
  }

  // MARK: - Copy

  @Test func copyWritesTheCodeToThePasteboard() throws {
    let pasteboard = FakePasteboard()
    let harness = HostedViewHarness(
      CodeBlockView(code: Self.swiftCode, language: "swift")
        .environment(\.pasteboard, pasteboard))
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: CodeBlockView.copyIdentifier)

    #expect(pasteboard.copies == [Self.swiftCode])
  }

  @Test func theCopyButtonHasALabel() {
    let harness = HostedViewHarness(CodeBlockView(code: Self.swiftCode, language: "swift"))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: CodeBlockView.copyIdentifier)?.label == "Copy code")
  }

  // MARK: - Textual

  @Test func aFencedBlockInATextualDocumentMountsACodeBlock() throws {
    let pasteboard = FakePasteboard()
    let markdown = "Some prose.\n\n```json\n{\"a\": 1}\n```\n\nMore prose."
    let harness = HostedViewHarness(
      StructuredText(markdown: markdown)
        .textual.codeBlockStyle(EditorKitCodeBlockStyle())
        .environment(\.pasteboard, pasteboard))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: CodeBlockView.identifier)
    #expect(element?.label == "json code block")
    try harness.press(identifier: CodeBlockView.copyIdentifier)
    #expect(pasteboard.copies == ["{\"a\": 1}"])
  }

  @Test func aFencedBlockWithNoLanguageMountsAsPlainText() {
    let markdown = "```\nplain\n```"
    let harness = HostedViewHarness(
      StructuredText(markdown: markdown)
        .textual.codeBlockStyle(EditorKitCodeBlockStyle()))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: CodeBlockView.identifier)?.label == "plain text code block")
  }

  @Test func theStyleUsesTheCachedModelOfTheBlockID() {
    let cache = CodeBlockModelCache()
    let blockID = CodeBlockID(messageID: "message-1", paragraphID: "paragraph-1")
    let markdown = "```json\n{}\n```"
    let harness = HostedViewHarness(
      StructuredText(markdown: markdown)
        .textual.codeBlockStyle(EditorKitCodeBlockStyle())
        .codeBlockModelCache(cache, blockID: blockID))
    defer { harness.close() }
    harness.pump()

    #expect(cache.count == 1)
    let model = cache.model(for: blockID, code: "")
    #expect(model.text == "{}")
    #expect(model.syntax != nil)
  }
}

/// The code of a hosted test view, which a test can change.
@Observable
final class CodeSource {
  /// The code that the view shows.
  var code: String

  /// Makes a source with `code`.
  init(code: String) {
    self.code = code
  }
}

/// A code block that shows the code of a ``CodeSource``.
struct CodeSourceView: View {
  /// The source of the code.
  let source: CodeSource
  /// The model of the code block.
  let model: EditorModel

  var body: some View {
    CodeBlockView(code: source.code, language: nil, model: model)
  }
}
