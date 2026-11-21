import Testing

@testable import AgentViewKit

/// The prose and the fenced code blocks of the Markdown text of a response
/// (``MarkdownCodeFences``).
@Suite struct MarkdownCodeFencesTests {
  /// The segments of `markdown`.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The segments, in text order.
  static func segments(of markdown: String) -> [MarkdownSegment] {
    MarkdownCodeFences.segments(in: markdown)
  }

  @Test func aFenceBetweenTwoParagraphsMakesProseCodeAndProse() {
    #expect(
      Self.segments(of: "Intro.\n\n```swift\nlet a = 1\n```\n\nEnd.") == [
        .prose("Intro."), .code(code: "let a = 1", language: "swift", filename: nil),
        .prose("End."),
      ])
  }

  @Test func aTildeFenceIsACodeBlock() {
    #expect(
      Self.segments(of: "~~~python\nx = 1\n~~~") == [
        .code(code: "x = 1", language: "python", filename: nil)
      ])
  }

  @Test func aBacktickLineDoesNotCloseATildeFence() {
    #expect(
      Self.segments(of: "~~~\na\n```\n~~~") == [.code(code: "a\n```", language: nil, filename: nil)]
    )
  }

  @Test func aLongerClosingFenceClosesTheFence() {
    #expect(
      Self.segments(of: "```\na\n`````\n\nEnd.") == [
        .code(code: "a", language: nil, filename: nil), .prose("End."),
      ])
  }

  @Test func aShorterClosingFenceDoesNotCloseTheFence() {
    #expect(
      Self.segments(of: "````\na\n```\nb\n````") == [
        .code(code: "a\n```\nb", language: nil, filename: nil)
      ])
  }

  @Test func anIndentedFenceRemovesItsIndentFromTheCode() {
    #expect(
      Self.segments(of: "   ```js\n   let a\n    let b\n   ```") == [
        .code(code: "let a\n let b", language: "js", filename: nil)
      ])
  }

  @Test func anIndentOfFourSpacesIsNoFence() {
    let text = "    ```\n    code\n    ```"

    #expect(Self.segments(of: text) == [.prose(text)])
  }

  @Test func aWordAfterTheLanguageIsTheFileName() {
    #expect(
      Self.segments(of: "```swift Sources/App.swift\nlet a = 1\n```") == [
        .code(code: "let a = 1", language: "swift", filename: "Sources/App.swift")
      ])
  }

  @Test func aTitleAttributeIsTheFileName() {
    #expect(
      Self.segments(of: "```js title=\"app.js\"\nlet a\n```") == [
        .code(code: "let a", language: "js", filename: "app.js")
      ])
  }

  @Test func theAttributeFormGivesTheClassAsTheLanguage() {
    #expect(
      Self.segments(of: "```{.python file='run.py'}\nx\n```") == [
        .code(code: "x", language: "python", filename: "run.py")
      ])
  }

  @Test func aFenceWithNoClosingLineRunsToTheEndOfTheText() {
    #expect(
      Self.segments(of: "Text.\n\n```swift\nlet a = 1\nlet b") == [
        .prose("Text."), .code(code: "let a = 1\nlet b", language: "swift", filename: nil),
      ])
  }

  @Test func twoFencesOneAfterTheOtherMakeTwoCodeBlocks() {
    #expect(
      Self.segments(of: "```a\n1\n```\n```b\n2\n```") == [
        .code(code: "1", language: "a", filename: nil),
        .code(code: "2", language: "b", filename: nil),
      ])
  }

  @Test func aTextWithNoFenceIsOneProseSegmentEqualToTheText() {
    let text = "One.\n\nTwo.\n"

    #expect(Self.segments(of: text) == [.prose(text)])
  }

  @Test func theProseRangeIsTheProseInTheText() {
    let text = "Intro.\r\nMore.\n\n```\ncode\n```"
    let range = MarkdownCodeFences.pieces(in: text).first?.range

    #expect(range.map { String(text[$0]) } == "Intro.\r\nMore.")
  }
}
