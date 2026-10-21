import Testing

/// The shared patterns of ``WordPattern``.
@Suite struct WordPatternTests {
  /// The pattern of the member `.tint` after the receiver `fill(`.
  static var tintMemberPattern: Regex<Substring> {
    WordPattern.memberPattern(after: "fill(", WordPattern.wholeWord("tint"))
  }

  @Test func memberPatternFindsTheMemberAfterTheReceiverAndTheDot() {
    #expect("shape.fill(.tint)".contains(Self.tintMemberPattern))
  }

  @Test func memberPatternFindsTheMemberAfterWhitespaceBeforeTheDot() {
    #expect("shape.fill( .tint)".contains(Self.tintMemberPattern))
  }

  @Test func memberPatternDoesNotFindAnotherMember() {
    #expect(!"shape.fill(.tintColor)".contains(Self.tintMemberPattern))
  }

  @Test func memberPatternDoesNotFindTheReceiverInsideALongerWord() {
    #expect(!"shape.outfill(.tint)".contains(Self.tintMemberPattern))
  }

  @Test func wholeWordFindsTheWordBetweenTwoBoundaries() {
    #expect("let view = PlainView()".contains(WordPattern.wholeWord("PlainView")))
  }

  @Test func wholeWordDoesNotFindTheWordInsideALongerWord() {
    #expect(!"PlainViewRow()".contains(WordPattern.wholeWord("PlainView")))
    #expect(!"MyPlainView()".contains(WordPattern.wholeWord("PlainView")))
  }

  @Test func wholeWordFindsTheWordAfterADotBetweenTwoLetters() {
    #expect("thread.pendingAuthorizations".contains(WordPattern.wholeWord("pendingAuthorizations")))
  }
}
