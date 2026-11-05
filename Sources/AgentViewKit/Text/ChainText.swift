import Foundation

/// The text of a chain of parts that one catalog pattern of two parts
/// joins: a path of names, or a run of sentences.
///
/// A chain has one separator between each two parts, and no list format of
/// Foundation gives it: a list format has words such as "and", and no form
/// for a path or a run of sentences. So each kind of chain is one catalog
/// string of two parts, the pattern, and the chain applies it to the parts
/// one after the other, as a list format applies its own patterns. The
/// separator and the order of the two parts belong to the catalog: a
/// language can change the separator, or put the next part first.
enum ChainText {
  /// The visible path of some names, such as "Agent › Reviewer › Linter".
  ///
  /// - Parameters:
  ///   - names: The names, from the root.
  ///   - locale: The locale of the text.
  /// - Returns: The path, or an empty text when `names` is empty.
  static func visiblePath(_ names: [String], locale: Locale) -> String {
    chain(names) { head, next in
      String(
        localized: "chain.visible-path", defaultValue: "\(head) › \(next)", bundle: .module, locale: locale,
        comment: "A path of names that the user reads: the path so far, then the next name.")
    }
  }

  /// The spoken path of some names, such as "Agent, then Reviewer, then
  /// Linter".
  ///
  /// - Parameters:
  ///   - names: The names, from the root.
  ///   - locale: The locale of the text.
  /// - Returns: The path, or an empty text when `names` is empty.
  static func spokenPath(_ names: [String], locale: Locale) -> String {
    chain(names) { head, next in
      String(
        localized: "chain.spoken-path", defaultValue: "\(head), then \(next)", bundle: .module, locale: locale,
        comment: "A path of names that VoiceOver reads: the path so far, then the next name.")
    }
  }

  /// The run of some sentences, such as "It is short. It is wrong.".
  ///
  /// - Parameters:
  ///   - sentences: The sentences, in order.
  ///   - locale: The locale of the text.
  /// - Returns: The sentences, or an empty text when `sentences` is empty.
  static func sentences(_ sentences: [String], locale: Locale) -> String {
    chain(sentences) { head, next in
      String(
        localized: "chain.sentences", defaultValue: "\(head) \(next)", bundle: .module, locale: locale,
        comment: "A run of sentences: the sentences so far, then the next sentence.")
    }
  }

  /// Joins some parts with a pattern of two parts, from the first part.
  ///
  /// - Parameters:
  ///   - parts: The parts, in order.
  ///   - pattern: The text of the chain so far and the next part.
  /// - Returns: The chain, the one part of a chain of one part, or an empty
  ///   text for no part.
  private static func chain(_ parts: [String], joining pattern: (String, String) -> String) -> String {
    guard let first = parts.first else { return "" }
    return parts.dropFirst().reduce(first, pattern)
  }
}
