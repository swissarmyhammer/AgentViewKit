import Testing

@testable import AgentViewKit

/// Tests of `ParagraphViewCache`: a settled paragraph keeps the same stored
/// value from one update of the response to the next (task ^fzn2beh).
///
/// SwiftUI computes the compare layout of a view type on a background queue.
/// Until that layout is ready, SwiftUI compares the bytes of the old and the
/// new view value, and it does not call `==`. Thus a settled paragraph does not
/// evaluate again only when its new value has the same bytes as its old value.
/// These tests compare the bytes, as SwiftUI does.
@Suite @MainActor struct ParagraphViewCacheTests {
  /// The id of the message of the paragraphs.
  static let messageID = "paragraph-view-cache-message"

  /// A text with two paragraphs. Each paragraph text is too long for the
  /// inline storage of a Swift string, so each split makes new text storage.
  static let text = "The first paragraph has a long text.\n\nThe second paragraph has a long text."

  /// The text after the second paragraph changed.
  static let changedText = "The first paragraph has a long text.\n\nThe second paragraph has a new text."

  /// The text with only the first paragraph.
  static let firstParagraphText = "The first paragraph has a long text."

  /// One new paragraph view for each paragraph of `text`, from a new split.
  ///
  /// - Parameter text: The Markdown text.
  /// - Returns: The views, in message order.
  static func views(of text: String) -> [ParagraphView] {
    ParagraphSplitter.paragraphs(text).map { paragraph in
      ParagraphView(messageID: messageID, paragraph: paragraph)
    }
  }

  /// Tells whether two views have the same bytes, as SwiftUI compares them
  /// before the compare layout of the type is ready.
  ///
  /// - Parameters:
  ///   - lhs: A paragraph view.
  ///   - rhs: A paragraph view.
  /// - Returns: `true` when each byte of the two values is equal.
  static func haveTheSameBytes(_ lhs: ParagraphView, _ rhs: ParagraphView) -> Bool {
    withUnsafeBytes(of: lhs) { left in
      withUnsafeBytes(of: rhs) { right in left.elementsEqual(right) }
    }
  }

  @Test func twoSplitsOfOneTextGiveEqualViewsWithDifferentBytes() throws {
    let first = try #require(Self.views(of: Self.text).first)
    let second = try #require(Self.views(of: Self.text).first)

    #expect(first == second)
    #expect(!Self.haveTheSameBytes(first, second))
  }

  @Test func aSettledParagraphGetsItsStoredValueAgain() throws {
    let cache = ParagraphViewCache()
    let stored = cache.reuse(Self.views(of: Self.text))

    let reused = cache.reuse(Self.views(of: Self.text))

    try #require(reused.count == stored.count)
    for (old, new) in zip(stored, reused) {
      #expect(Self.haveTheSameBytes(old, new), "The paragraph \(new.paragraph.id.index) has new bytes.")
    }
  }

  @Test func aChangedParagraphGetsItsNewValue() throws {
    let cache = ParagraphViewCache()
    let stored = cache.reuse(Self.views(of: Self.text))
    let changed = Self.views(of: Self.changedText)

    let result = cache.reuse(changed)

    try #require(result.count == stored.count)
    #expect(Self.haveTheSameBytes(result[0], stored[0]))
    #expect(result[1] == changed[1])
    #expect(Self.haveTheSameBytes(result[1], changed[1]))
  }

  @Test func aParagraphThatLeavesTheListIsNotStoredAgain() throws {
    let cache = ParagraphViewCache()
    let stored = cache.reuse(Self.views(of: Self.text))
    _ = cache.reuse(Self.views(of: Self.firstParagraphText))
    let returned = Self.views(of: Self.text)

    let result = cache.reuse(returned)

    try #require(result.count == stored.count)
    #expect(Self.haveTheSameBytes(result[0], stored[0]))
    #expect(Self.haveTheSameBytes(result[1], returned[1]))
  }
}
