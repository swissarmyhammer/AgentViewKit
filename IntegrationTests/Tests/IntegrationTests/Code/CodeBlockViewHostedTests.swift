import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorSwiftUI
import EditorTestSupport
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct CodeBlockViewHostedTests {
  static let swiftCode = "let x = 1\nprint(x)"

  // MARK: - Identifier and label

  @Test func mountsACodeBlockElementWithTheLanguageLabel() {
    let harness = HostedViewHarness(CodeBlockView(code: "{\"a\": 1}", language: "json"))
    defer { harness.close() }
    harness.render()

    let element = harness.element(identifier: CodeBlockView.identifier)
    #expect(element?.label == "json code block")
    #expect(harness.element(identifier: CodeBlockView.copyIdentifier) != nil)
  }

  @Test func unknownLanguageMountsAsPlainText() {
    let harness = HostedViewHarness(CodeBlockView(code: Self.swiftCode, language: nil))
    defer { harness.close() }
    harness.render()

    let element = harness.element(identifier: CodeBlockView.identifier)
    #expect(element?.label == "plain text code block")
  }

  @Test func emptyLanguageMountsAsPlainText() {
    let harness = HostedViewHarness(CodeBlockView(code: Self.swiftCode, language: "  "))
    defer { harness.close() }
    harness.render()

    let element = harness.element(identifier: CodeBlockView.identifier)
    #expect(element?.label == "plain text code block")
  }

  @Test func theHeaderShowsTheFilename() {
    let harness = HostedViewHarness(
      CodeBlockView(code: Self.swiftCode, language: "swift", filename: "main.swift"))
    defer { harness.close() }
    harness.render()

    let titles = harness.accessibilityElements().filter { $0.label == "main.swift" }
    #expect(!titles.isEmpty)
    #expect(harness.element(identifier: CodeBlockView.identifier)?.label == "swift code block")
  }

  // MARK: - Syntax

  @Test func aBundledLanguageAttachesSyntax() {
    let model = EditorModel("{}")
    let harness = HostedViewHarness(CodeBlockView(code: "{}", language: "JSON", model: model))
    defer { harness.close() }
    harness.render()

    #expect(model.syntax != nil)
    #expect(model.isReadOnly)
  }

  @Test func aLanguageWithNoGrammarAttachesNoSyntax() {
    let model = EditorModel(Self.swiftCode)
    let harness = HostedViewHarness(
      CodeBlockView(code: Self.swiftCode, language: "cobol", model: model))
    defer { harness.close() }
    harness.render()

    #expect(model.syntax == nil)
    #expect(model.textMateGrammar == nil)
  }

  @Test func aLanguageWithATextMateGrammarAttachesThatGrammar() {
    let code = "export const x = 1;"
    let model = EditorModel(code)
    let harness = HostedViewHarness(CodeBlockView(code: code, language: "ts", model: model))
    defer { harness.close() }
    harness.render()

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
    harness.render()

    source.code = "let x = 1"
    harness.render()

    #expect(model.text == "let x = 1")
    #expect(model.isReadOnly)
  }

  // MARK: - Copy

  @Test func copyWritesTheCodeToThePasteboard() throws {
    try NSPasteboard.withIsolated { pasteboard in
      let harness = HostedViewHarness(
        CodeBlockView(code: Self.swiftCode, language: "swift")
          .environment(\.pasteboard, pasteboard))
      defer { harness.close() }
      harness.render()

      try pasteboard.expectOneCopy(of: Self.swiftCode) {
        try harness.perform(.press, on: CodeBlockView.copyIdentifier)
      }
    }
  }

  @Test func theCopyButtonHasALabel() {
    let harness = HostedViewHarness(CodeBlockView(code: Self.swiftCode, language: "swift"))
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: CodeBlockView.copyIdentifier)?.label == "Copy code")
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
