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

#if DEBUG
  // MARK: - Symbol column

  /// The header of a code block has its symbol in the symbol column, as the
  /// header of a terminal has (task ^dsh1gqf). So the title of a code block
  /// and the command of a terminal of the same width start at the same x.
  extension CodeBlockViewHostedTests {
    /// The space from the leading edge of a mounted code block to the start
    /// of its header title.
    ///
    /// The title is a static text element. Its text is its value, not its
    /// label, so the step finds it by its identifier
    /// (``CodeBlockView/titleIdentifier``), as the terminal step finds the
    /// command, and first checks that it shows `title`.
    ///
    /// - Parameters:
    ///   - block: The code block to mount.
    ///   - title: The text of the header title.
    /// - Returns: The space, in points.
    /// - Throws: An issue when no title element shows `title`.
    static func titleLeading(of block: CodeBlockView, title: String) throws -> CGFloat {
      let harness = HostedViewHarness(block)
      defer { harness.close() }
      harness.render()

      try #require(harness.element(identifier: CodeBlockView.titleIdentifier)?.label == title)
      return try leading(ofIdentifier: CodeBlockView.titleIdentifier, in: harness)
    }

    /// The space from the leading edge of a mounted terminal to the start of
    /// the command in its header.
    ///
    /// - Returns: The space, in points.
    /// - Throws: The error of the scripted session, or an issue when the
    ///   terminal shows no command.
    static func terminalCommandLeading() async throws -> CGFloat {
      let (session, terminal) = try await TerminalViewHostedTests.openTerminal(
        TerminalViewHostedTests.headerFields)
      defer { session.close() }
      let harness = HostedViewHarness(TerminalView(entry: terminal))
      defer { harness.close() }
      harness.render()

      return try leading(ofIdentifier: TerminalView.commandIdentifier, in: harness)
    }

    /// The space from the leading edge of the hosting view of a rendered
    /// harness to the leading edge of the element with an identifier.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the element.
    ///   - harness: The rendered harness that shows the element.
    /// - Returns: The space, in points.
    /// - Throws: An issue when no element has `identifier`.
    static func leading<Content: View>(
      ofIdentifier identifier: String, in harness: HostedViewHarness<Content>
    ) throws -> CGFloat {
      let frame = try #require(harness.frame(identifier: identifier))
      let view = harness.screenFrame(of: harness.hostingView)
      return frame.minX - view.minX
    }

    @Test func theTitleOfACodeBlockStartsAtTheXOfTheCommandOfATerminal() async throws {
      let block = CodeBlockView(code: Self.swiftCode, language: "swift")

      let title = try Self.titleLeading(of: block, title: "swift")

      #expect(title == (try await Self.terminalCommandLeading()))
    }

    @Test func thePlainTextTitleOfACodeBlockStartsAtTheXOfTheCommandOfATerminal() async throws {
      let block = CodeBlockView(code: Self.swiftCode, language: nil)

      let title = try Self.titleLeading(of: block, title: CodeBlockView.plainTextName)

      #expect(title == (try await Self.terminalCommandLeading()))
    }
  }
#endif

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
