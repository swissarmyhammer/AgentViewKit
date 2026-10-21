import RegexBuilder

/// The word patterns that the source scans of this target share.
///
/// One pattern serves each scan that finds a name as a whole word, for
/// example ``RemovedVocabularyTests`` and ``PreviewCoverageTests``. Thus the
/// word boundaries of the scans cannot become different. One pattern also
/// serves each scan that finds a member after a receiver, for example
/// ``FixedColorTests`` and ``GlassForm/memberCallPattern(_:_:)``.
enum WordPattern {
  /// The pattern that finds a member after a receiver: the receiver, then
  /// optional whitespace, then `.`, then the member. For the receiver
  /// `buttonStyle(` and the member `glass`, it finds `buttonStyle(.glass`.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Parameters:
  ///   - receiver: The pattern of the receiver.
  ///   - member: The pattern of the name of the member.
  /// - Returns: The pattern.
  static func memberPattern(
    after receiver: some RegexComponent<Substring>, _ member: some RegexComponent<Substring>
  ) -> Regex<Substring> {
    Regex {
      receiver
      ZeroOrMore(.whitespace)
      "."
      member
    }
  }

  /// The pattern that matches a word only as a whole word.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// The pattern uses simple word boundaries. The default boundaries follow
  /// Unicode word segmentation, which does not break at a `.` between two
  /// letters. Thus `thread.pendingAuthorizations` would not match.
  ///
  /// - Parameter word: The word.
  /// - Returns: The pattern.
  static func wholeWord(_ word: String) -> Regex<Substring> {
    Regex {
      Anchor.wordBoundary
      word
      Anchor.wordBoundary
    }
    .wordBoundaryKind(.simple)
  }
}
