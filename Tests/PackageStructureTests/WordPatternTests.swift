import Testing

/// The shared whole-word pattern of ``WordPattern``.
@Suite struct WordPatternTests {
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
