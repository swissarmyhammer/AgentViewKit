import Foundation
import FoundationModelsACP

/// The names that the inspections of the client models give to the blocks
/// of their objects, so two blocks of one type have two different names.
///
/// EditorKit shows the name of each block in its name row. An inspection
/// that gives no name, or a name of `nil`, names each block by the title of
/// its type.
enum InspectionName {
  /// The largest number of words in a name made from a text.
  static let firstWordCount = 6

  /// The first words of a text, as the name of the object of the text.
  ///
  /// The name starts at the first word and stops at the end of the word
  /// ``firstWordCount``. Each run of spaces and line breaks becomes one
  /// space. A text with more words gets an ellipsis after its last shown
  /// word.
  ///
  /// - Parameter text: The text, such as the text of a message.
  /// - Returns: The first words, such as "The parser reads one token too…",
  ///   or `nil` for a text with no word.
  static func firstWords(of text: String) -> String? {
    let words = wordRanges(in: text, limit: firstWordCount + 1)
    guard let first = words.first else { return nil }
    let isCut = words.count > firstWordCount
    let end = isCut ? words[firstWordCount - 1].upperBound : text.endIndex
    let shown = text[first.lowerBound..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    guard isCut else { return shown }
    return String(
      localized: "inspection.first-words", defaultValue: "\(shown)…", bundle: .module,
      comment: "The name of an object in the inspector: the first words of its text, cut before the next word.")
  }

  /// The name of a message: its author and its time, or its first words.
  ///
  /// - Parameters:
  ///   - author: The author of the message, such as the id of the session
  ///     that sent it, or `nil` when the entry has none.
  ///   - startedAt: The start time of the message, or `nil` when the client
  ///     did not see it start.
  ///   - text: The text of the message.
  ///   - locale: The locale of the time.
  ///   - timeZone: The time zone of the time.
  /// - Returns: The author and the time in ``EntryTimingView/startStyle``,
  ///   such as "child-1 · 6:15 AM", when the message has both; else the
  ///   ``firstWords(of:)`` of its text.
  static func message(
    author: String?, startedAt: Date?, text: String, locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
  ) -> String? {
    guard let author, let startedAt else { return firstWords(of: text) }
    let time = EntryTimingView.startStyle(locale: locale, timeZone: timeZone)
    return String(
      localized: "inspection.author-and-time", defaultValue: "\(author) · \(startedAt, format: time)",
      bundle: .module, locale: locale,
      comment: "The name of a message in the inspector: its author, then its start time, such as 6:15 AM.")
  }

  /// The name of a plan: the first words of its current step.
  ///
  /// The current step is the first step that is not complete. In a plan
  /// whose steps are all complete, it is the last step.
  ///
  /// - Parameter steps: The steps of the plan, in plan order.
  /// - Returns: The ``firstWords(of:)`` of the current step, or `nil` for a
  ///   plan with no step.
  static func plan(_ steps: [PlanEntry]) -> String? {
    let current = steps.first { $0.status != .completed } ?? steps.last
    return current.flatMap { firstWords(of: $0.content) }
  }

  /// The ranges of the first words of a text, in text order.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - limit: The largest number of ranges to find.
  /// - Returns: The ranges, at most `limit`.
  private static func wordRanges(in text: String, limit: Int) -> [Range<String.Index>] {
    var ranges: [Range<String.Index>] = []
    text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, range, _, stop in
      ranges.append(range)
      stop = ranges.count >= limit
    }
    return ranges
  }
}
