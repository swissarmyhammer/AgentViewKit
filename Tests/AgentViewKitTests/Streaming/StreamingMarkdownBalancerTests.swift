import AgentViewKit
import Testing

@Suite struct StreamingMarkdownBalancerTests {
  private typealias Balanced = StreamingMarkdownBalancer.BalancedTail

  private func balance(_ tail: String) -> Balanced {
    StreamingMarkdownBalancer.balance(tail: tail)
  }

  // MARK: - Each delimiter

  @Test func closesDanglingStrong() {
    #expect(balance("some **bold") == .markdown("some **bold**"))
  }

  @Test func closesDanglingEmphasisStar() {
    #expect(balance("some *em") == .markdown("some *em*"))
  }

  @Test func closesDanglingEmphasisUnderscore() {
    #expect(balance("some _em") == .markdown("some _em_"))
  }

  @Test func closesDanglingCodeSpan() {
    #expect(balance("run `swift") == .markdown("run `swift`"))
  }

  @Test func closesADoubleBacktickCodeSpanWithTheSameRun() {
    #expect(balance("run ``a ` b") == .markdown("run ``a ` b``"))
  }

  @Test func closesDanglingLinkText() {
    #expect(balance("see [the docs") == .markdown("see [the docs]"))
  }

  @Test func closesDanglingLinkDestination() {
    #expect(
      balance("see [the docs](https://example.com/pa")
        == .markdown("see [the docs](https://example.com/pa)"))
  }

  @Test func keepsBalancedText() {
    let text = "a **b** and *c* and _d_ and `e` and [f](g)"

    #expect(balance(text) == .markdown(text))
  }

  @Test func keepsAnEmptyTail() {
    #expect(balance("") == .markdown(""))
  }

  // MARK: - Nested delimiters

  @Test func closesNestedDelimitersInReverseOrder() {
    #expect(balance("a **b *c") == .markdown("a **b *c***"))
  }

  @Test func closesEmphasisInsideLinkText() {
    #expect(balance("[**bold") == .markdown("[**bold**]"))
  }

  @Test func closesACodeSpanBeforeTheOuterDelimiters() {
    #expect(balance("**run `x") == .markdown("**run `x`**"))
  }

  @Test func ignoresDelimitersInsideACodeSpan() {
    #expect(balance("`a ** b` and **c") == .markdown("`a ** b` and **c**"))
  }

  @Test func ignoresDelimitersInsideALinkDestination() {
    #expect(balance("[a](http://x/_y") == .markdown("[a](http://x/_y)"))
  }

  @Test func aTripleStarRunOpensStrongAndEmphasis() {
    #expect(balance("***both") == .markdown("***both***"))
  }

  // MARK: - Delimiters that do not open

  @Test func ignoresAnEscapedDelimiter() {
    #expect(balance(#"a \*b and \[c"#) == .markdown(#"a \*b and \[c"#))
  }

  @Test func ignoresAnEscapedBackslashThenClosesTheDelimiter() {
    #expect(balance(#"a \\*b"#) == .markdown(#"a \\*b*"#))
  }

  @Test func ignoresAStarWithASpaceAfterIt() {
    #expect(balance("* item and 2 * 3") == .markdown("* item and 2 * 3"))
  }

  @Test func ignoresAnIntrawordUnderscore() {
    #expect(balance("call snake_case") == .markdown("call snake_case"))
  }

  @Test func ignoresADelimiterAtTheEnd() {
    #expect(balance("some **") == .markdown("some **"))
  }

  @Test func ignoresAClosingBracketWithNoOpener() {
    #expect(balance("a] b") == .markdown("a] b"))
  }

  @Test func putsClosersBeforeTrailingWhitespace() {
    #expect(balance("some **bold \n") == .markdown("some **bold** \n"))
  }

  // MARK: - Code fences

  @Test func anOpenFenceWithALanguageReturnsTheBody() {
    #expect(
      balance("```swift\nlet a = 1\nlet b")
        == .openFence(language: "swift", body: "let a = 1\nlet b"))
  }

  @Test func anOpenFenceKeepsTheBodyAsIs() {
    #expect(balance("```\n**bold `x") == .openFence(language: nil, body: "**bold `x"))
  }

  @Test func anOpenFenceWithOnlyTheOpeningLineHasAnEmptyBody() {
    #expect(balance("```python") == .openFence(language: "python", body: ""))
  }

  @Test func theLanguageIsTheFirstWordOfTheInfoString() {
    #expect(
      balance("``` rust  title=\"a.rs\"\nfn main")
        == .openFence(language: "rust", body: "fn main"))
  }

  @Test func anOpenFenceIsFoundAfterACrlfLine() {
    #expect(balance("```js\r\nlet a") == .openFence(language: "js", body: "let a"))
  }

  @Test func aClosedFenceIsKeptAsIs() {
    let text = "```\n**a\n```"

    #expect(balance(text) == .markdown(text))
  }

  @Test func anEvenCountOfFencesIsClosedAndAnOddCountIsOpen() {
    #expect(balance("```\na\n```\n\n```go\nb") == .openFence(language: "go", body: "b"))
  }
}
