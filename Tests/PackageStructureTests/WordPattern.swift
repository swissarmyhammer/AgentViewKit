import RegexBuilder

/// The word patterns that the source scans of this target share.
///
/// One pattern serves each scan that finds a name as a whole word, for
/// example ``RemovedVocabularyTests`` and ``ViewPreviewTests``. Thus the
/// word boundaries of the scans cannot become different. One pattern also
/// serves each scan that finds a member after a receiver, for example
/// ``SystemStructureTests`` and ``GlassForm/memberCallPattern(_:_:)``.
enum WordPattern {
  /// The pattern that finds a member after a receiver: a word boundary, the
  /// receiver, then optional whitespace, then `.`, then the member. For the
  /// receiver `buttonStyle(` and the member `glass`, it finds
  /// `buttonStyle(.glass`.
  ///
  /// The word boundary before the receiver is the same simple boundary as in
  /// ``wholeWord(_:)``. Thus the receiver does not match inside a longer
  /// name: for the receiver `fill(`, it does not find `outfill(.tint`. The
  /// receiver must start with a word character.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Parameters:
  ///   - receiver: The pattern of the receiver. It starts with a word
  ///     character.
  ///   - member: The pattern of the name of the member.
  /// - Returns: The pattern.
  static func memberPattern(
    after receiver: some RegexComponent<Substring>, _ member: some RegexComponent<Substring>
  ) -> Regex<Substring> {
    Regex {
      Anchor.wordBoundary
      receiver
      ZeroOrMore(.whitespace)
      "."
      member
    }
    .wordBoundaryKind(.simple)
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

  /// The pattern of a dot with no name directly before it: the dot of a
  /// modifier or of an implicit member, such as `.selection` after `(`.
  static var dotAfterNoName: Regex<Substring> {
    Regex {
      Anchor.wordBoundary.inverted
      "."
    }
    .wordBoundaryKind(.simple)
  }

  /// The pattern of the text between the parentheses of a call: text with
  /// no parentheses, and pairs of parentheses with up to two levels of
  /// nested pairs. The text can continue on the next lines.
  static var argumentText: Regex<Substring> {
    let other = CharacterClass.anyOf("()").inverted
    let innerPair = Regex {
      "("
      ZeroOrMore(other)
      ")"
    }
    let pair = Regex {
      "("
      ZeroOrMore {
        ChoiceOf {
          other
          innerPair
        }
      }
      ")"
    }
    return Regex {
      ZeroOrMore {
        ChoiceOf {
          other
          pair
        }
      }
    }
  }
}
