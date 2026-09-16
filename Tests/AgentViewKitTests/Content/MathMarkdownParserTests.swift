import AgentViewKit
import Foundation
import Testing

/// Tests of ``MathMarkdownParser``: how it finds the math spans of a
/// Markdown text and what it puts in their place.
@Suite @MainActor struct MathMarkdownParserTests {
  /// An inline expression, with no dollar signs.
  static let inlineSource = "E = mc^2"

  /// A block expression with a thin space escape, with no dollar signs.
  static let blockSource = #"\int_0^1 x\,dx"#

  /// A matrix with a row break escape, with no dollar signs.
  static let matrixSource = #"\begin{pmatrix}1&2\\3&4\end{pmatrix}"#

  /// An expression that the engine cannot parse: the command does not exist.
  static let malformedSource = #"\nosuchcommand{x}"#

  /// The text of the code runs of `output`, in text order.
  ///
  /// - Parameter output: The parsed text.
  /// - Returns: The text of each run that has the inline code intent.
  static func codeRunTexts(_ output: AttributedString) -> [String] {
    output.runs
      .filter { $0.inlinePresentationIntent?.contains(.code) == true }
      .map { String(output[$0.range].characters) }
  }

  @Test func eachExpressionMakesOneSpan() {
    let text = "Energy $\(Self.inlineSource)$ and $$\(Self.blockSource)$$ here."
    #expect(MathMarkdownParser().mathSpans(in: text) == [
      MathMarkdownParser.Span(latex: Self.inlineSource, display: false),
      MathMarkdownParser.Span(latex: Self.blockSource, display: true),
    ])
  }

  @Test func theSpanKeepsTheBackslashEscapesOfTheSource() {
    let text = "$$\(Self.matrixSource)$$"
    #expect(MathMarkdownParser().mathSpans(in: text) == [
      MathMarkdownParser.Span(latex: Self.matrixSource, display: true)
    ])
  }

  @Test func aBlockSpanCanHaveLineBreaks() {
    let source = "a + b\n= c"
    #expect(MathMarkdownParser().mathSpans(in: "$$\n\(source)\n$$") == [
      MathMarkdownParser.Span(latex: "\n\(source)\n", display: true)
    ])
  }

  @Test(arguments: [
    "It costs $5 and $10.",
    "It costs $ 5 and 10 $.",
    "Pay $x $ now.",
    #"A literal \$x\$ sign."#,
    "An empty block $$ $$ here.",
    "No close $x",
    "Two lines $x\ny$ here.",
  ])
  func textWithNoMathHasNoSpan(text: String) {
    #expect(MathMarkdownParser().mathSpans(in: text).isEmpty)
  }

  @Test func theParserIgnoresMathInCode() {
    let text = "Code `$x$` here.\n\n```\n$$y$$\n```\n\n~~~~\n$z$\n~~~~"
    #expect(MathMarkdownParser().mathSpans(in: text).isEmpty)
  }

  @Test func aDollarInCodeDoesNotPairWithADollarOutside() {
    let text = "Run `echo $HOME` and see $x$."
    #expect(MathMarkdownParser().mathSpans(in: text) == [
      MathMarkdownParser.Span(latex: "x", display: false)
    ])
  }

  @Test func aCodeSpanWithLongerTicksHoldsShorterTicks() {
    let text = "See ``a ` $x$ b`` and $y$."
    #expect(MathMarkdownParser().mathSpans(in: text) == [
      MathMarkdownParser.Span(latex: "y", display: false)
    ])
  }

  @Test func anExpressionBecomesOneAttachmentCharacter() throws {
    let output = try MathMarkdownParser().attributedString(
      for: "Energy $\(Self.inlineSource)$ here.")
    #expect(String(output.characters) == "Energy \u{FFFC} here.")
  }

  @Test func malformedSourceBecomesCodeText() throws {
    let parser = MathMarkdownParser()
    let text = "Bad $\(Self.malformedSource)$ math."
    #expect(parser.mathSpans(in: text).isEmpty)
    let output = try parser.attributedString(for: text)
    #expect(String(output.characters) == "Bad \(Self.malformedSource) math.")
    #expect(Self.codeRunTexts(output) == [Self.malformedSource])
  }

  @Test func mathInAnIndentedCodeBlockKeepsItsSource() throws {
    let output = try MathMarkdownParser().attributedString(for: "    let a = $x$\n")
    #expect(String(output.characters).contains("$x$"))
    #expect(!String(output.characters).contains("\u{FFFC}"))
  }

  @Test func textWithNoMathParsesAsMarkdown() throws {
    let output = try MathMarkdownParser().attributedString(for: "Some **bold** text.")
    #expect(String(output.characters) == "Some bold text.")
    let bold = output.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
    #expect(bold.count == 1)
  }

  @Test func emphasisAroundMathKeepsTheEmphasis() throws {
    let output = try MathMarkdownParser().attributedString(for: "A *$x$* b.")
    let emphasized = output.runs.filter { $0.inlinePresentationIntent?.contains(.emphasized) == true }
    #expect(emphasized.map { String(output[$0.range].characters) } == ["\u{FFFC}"])
  }
}
