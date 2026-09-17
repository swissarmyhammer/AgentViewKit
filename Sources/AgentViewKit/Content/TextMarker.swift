import Foundation

/// One part of a marked text: plain text or a numbered marker.
nonisolated enum MarkedTextPart: Equatable, Sendable {
  /// Text with no marker.
  case text(String)

  /// The marker with the number.
  case marker(Int)
}

/// The run of a parsed text that holds a marker.
nonisolated struct MarkedRun {
  /// The attributes of the run.
  let attributes: AttributeContainer

  /// Whether the run is inline code.
  let isInlineCode: Bool

  /// Whether the run is in a code block.
  let isCodeBlock: Bool

  /// Whether the run is inline code or is in a code block.
  var isCode: Bool { isInlineCode || isCodeBlock }
}

/// A pair of characters that hold a numbered place in a Markdown text
/// (plan.md §4.2, §9 B, §9 C).
///
/// A parser puts a marker in the raw text, lets the Markdown parse run, and
/// then puts its own content in place of each marker. The characters must be
/// in the Unicode private use area, so Markdown text does not have them and
/// the parse keeps them. ``MathMarkdownParser`` and ``CitationMarkdownParser``
/// use this type with different characters.
nonisolated struct TextMarker: Sendable {
  /// The character that starts a marker.
  let start: Character

  /// The character that ends a marker.
  let end: Character

  /// A marker and its place in a text.
  private struct Found {
    /// The range of the marker, with its start and end characters.
    let range: Range<Substring.Index>

    /// The number of the marker.
    let number: Int
  }

  /// The marker text of a number.
  ///
  /// - Parameter number: The number.
  /// - Returns: The start character, the number, and the end character.
  func marker(_ number: Int) -> String {
    String(start) + String(number) + String(end)
  }

  /// Splits a text at its markers.
  ///
  /// - Parameter text: The text.
  /// - Returns: The parts, in text order. A start character with no valid
  ///   marker after it stays in the text.
  func parts(of text: String) -> [MarkedTextPart] {
    parts(of: Substring(text))
  }

  /// Replaces each marker in the runs of a parsed text.
  ///
  /// A run with no marker stays as it is. The text of a run with a marker
  /// keeps the attributes of the run.
  ///
  /// - Parameters:
  ///   - parsed: The parsed text.
  ///   - replacement: The function that makes the text in place of the
  ///     marker with a number, in a run.
  /// - Returns: The text with the replacements.
  func replacingMarkers(
    in parsed: AttributedString,
    with replacement: (Int, MarkedRun) -> AttributedString
  ) -> AttributedString {
    parsed.runs
      .map { run -> AttributedString in
        let piece = AttributedString(parsed[run.range])
        let text = String(piece.characters)
        guard text.contains(start) else { return piece }
        let context = MarkedRun(
          attributes: run.attributes,
          isInlineCode: run.inlinePresentationIntent?.contains(.code) == true,
          isCodeBlock: run.presentationIntent?.components.contains { component in
            if case .codeBlock = component.kind { true } else { false }
          } == true
        )
        return parts(of: text)
          .map { part in
            switch part {
            case .text(let plain): AttributedString(plain, attributes: run.attributes)
            case .marker(let number): replacement(number, context)
            }
          }
          .reduce(into: AttributedString()) { $0.append($1) }
      }
      .reduce(into: AttributedString()) { $0.append($1) }
  }

  /// Splits a part of a text at its markers.
  ///
  /// - Parameter text: The part of the text.
  /// - Returns: The parts, in text order.
  private func parts(of text: Substring) -> [MarkedTextPart] {
    guard let found = firstMarker(in: text, from: text.startIndex) else {
      return text.isEmpty ? [] : [.text(String(text))]
    }
    let before = text[..<found.range.lowerBound]
    let head: [MarkedTextPart] = before.isEmpty ? [] : [.text(String(before))]
    return head + [.marker(found.number)] + parts(of: text[found.range.upperBound...])
  }

  /// Finds the first valid marker of a text at or after a position.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - index: The position where the search starts.
  /// - Returns: The marker, or `nil` when the text has no valid marker there.
  private func firstMarker(in text: Substring, from index: Substring.Index) -> Found? {
    guard let startIndex = text[index...].firstIndex(of: start) else { return nil }
    let afterStart = text.index(after: startIndex)
    guard let endIndex = text[afterStart...].firstIndex(of: end),
      let number = Int(text[afterStart..<endIndex])
    else {
      return firstMarker(in: text, from: afterStart)
    }
    return Found(range: startIndex..<text.index(after: endIndex), number: number)
  }
}
