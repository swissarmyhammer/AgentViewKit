import RegexBuilder

/// The whole-word pattern that the source scans of this target share.
///
/// One pattern serves each scan that finds a name as a whole word, for
/// example ``RemovedVocabularyTests`` and ``PreviewCoverageTests``. Thus the
/// word boundaries of the scans cannot become different.
enum WordPattern {
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
