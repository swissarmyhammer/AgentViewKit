import SwiftUI
import Textual

// MARK: - Placements

/// One citation pill in one paragraph of a response.
nonisolated struct CitationPlacement: Hashable, Sendable {
  /// The zero-based character offset of the pill in the paragraph text.
  let offset: Int

  /// The one-based number of the cited source.
  let number: Int
}

nonisolated extension ContentBlock {
  /// Whether the block is a structured block with the citation schema name.
  var isCitation: Bool {
    if case .structured(let schemaName, _) = content {
      return schemaName == CitationPayload.schemaName
    }
    return false
  }
}

nonisolated extension CitationPayload {
  /// The payload of the first citation block that decodes.
  ///
  /// - Parameter blocks: The blocks of a message.
  /// - Returns: The payload, or `nil` when no citation block decodes.
  static func first(in blocks: [ContentBlock]) -> CitationPayload? {
    for block in blocks where block.isCitation && block.isVisible(to: .user) {
      guard case .structured(_, let payload) = block.content else { continue }
      if let citation = try? CitationPayload(content: payload) {
        return citation
      }
    }
    return nil
  }

  /// The pills of each paragraph, keyed by the paragraph index.
  ///
  /// The number of a pill is the position of its source in ``sources`` plus
  /// one. A marker of a source that is not in ``sources`` makes no pill. The
  /// pills of one paragraph keep the order of ``markers``.
  ///
  /// - Returns: The placements of each paragraph that has a pill.
  func placementsByParagraph() -> [Int: [CitationPlacement]] {
    var numbers: [String: Int] = [:]
    for (position, source) in sources.enumerated() where numbers[source.id] == nil {
      numbers[source.id] = position + 1
    }
    var result: [Int: [CitationPlacement]] = [:]
    for marker in markers {
      guard let number = numbers[marker.sourceID] else { continue }
      result[marker.paragraphIndex, default: []].append(
        CitationPlacement(offset: marker.offset, number: number))
    }
    return result
  }
}

// MARK: - Markers

/// The markers that hold the place of a citation pill in a paragraph text.
///
/// ``MarkdownProse`` puts a marker in the text at each placement. After the
/// Markdown parse, ``CitationMarkdownParser`` puts a pill in place of each
/// marker. The marker characters are in the Unicode private use area, so
/// Markdown text does not have them and the parse keeps them. They are not
/// the characters of the ``MathMarkdownParser`` markers.
nonisolated enum CitationMarkers {
  /// The character that starts a marker.
  static let start: Character = "\u{E002}"

  /// The character that ends a marker.
  static let end: Character = "\u{E003}"

  /// One part of a text: plain text or a marker.
  enum Part: Equatable {
    /// Text with no marker.
    case text(String)
    /// The marker of the source with the one-based number.
    case marker(Int)
  }

  /// The marker of a source.
  ///
  /// - Parameter number: The one-based number of the source.
  /// - Returns: The marker text.
  static func marker(number: Int) -> String {
    String(start) + String(number) + String(end)
  }

  /// Puts a marker in a paragraph text at each placement.
  ///
  /// An offset below zero is zero, and an offset past the end is the end.
  /// Markers at the same offset keep the order of `placements`. A paragraph
  /// with a code fence line gets no marker, because the code block shows its
  /// text as it is.
  ///
  /// - Parameters:
  ///   - text: The Markdown text of one paragraph.
  ///   - placements: The pills of the paragraph.
  /// - Returns: The text with the markers, and the source numbers of the
  ///   markers in text order.
  static func marked(
    _ text: String, placements: [CitationPlacement]
  ) -> (text: String, numbers: [Int]) {
    guard !placements.isEmpty, !hasFence(text) else { return (text, []) }
    let count = text.count
    let ordered = placements.enumerated()
      .map { (offset: min(max($0.element.offset, 0), count), order: $0.offset, number: $0.element.number) }
      .sorted { ($0.offset, $0.order) < ($1.offset, $1.order) }
    var output = ""
    var position = text.startIndex
    var consumed = 0
    for placement in ordered {
      let next = text.index(position, offsetBy: placement.offset - consumed)
      output += text[position..<next]
      output += marker(number: placement.number)
      position = next
      consumed = placement.offset
    }
    output += text[position...]
    return (output, ordered.map(\.number))
  }

  /// Splits a text at its markers.
  ///
  /// - Parameter text: The text.
  /// - Returns: The parts, in text order. A start character with no valid
  ///   marker after it stays in the text.
  static func parts(of text: String) -> [Part] {
    var parts: [Part] = []
    var rest = Substring(text)
    var plain = ""
    while let startIndex = rest.firstIndex(of: start) {
      let afterStart = rest.index(after: startIndex)
      guard let endIndex = rest[afterStart...].firstIndex(of: end),
        let number = Int(rest[afterStart..<endIndex])
      else {
        plain += rest[...startIndex]
        rest = rest[afterStart...]
        continue
      }
      plain += rest[..<startIndex]
      if !plain.isEmpty {
        parts.append(.text(plain))
        plain = ""
      }
      parts.append(.marker(number))
      rest = rest[rest.index(after: endIndex)...]
    }
    plain += rest
    if !plain.isEmpty {
      parts.append(.text(plain))
    }
    return parts
  }

  /// Tells whether a text has a code fence line.
  ///
  /// - Parameter text: The text.
  /// - Returns: `true` when one line of `text` opens a code fence.
  private static func hasFence(_ text: String) -> Bool {
    MarkdownFence.normalizeLineBreaks(text)
      .split(separator: "\n", omittingEmptySubsequences: false)
      .contains { MarkdownFence.opening($0) != nil }
  }
}

// MARK: - Parser

/// A Markdown parser that puts a citation pill in place of each
/// ``CitationMarkers`` marker (plan.md §9 C).
///
/// The base parser parses the text first. Then each marker becomes one
/// attachment character with a ``InlineCitationAttachment`` and the citation
/// link of its source. Textual sends a click on the pill to the `openURL`
/// action, and ``SwiftUI/View/citationScope()`` gets the link. A marker in a
/// code block makes nothing, because the code block shows its text as it is.
struct CitationMarkdownParser<Base: MarkupParser>: MarkupParser {
  /// The parser of the Markdown text.
  let base: Base

  func attributedString(for input: String) throws -> AttributedString {
    let parsed = try base.attributedString(for: input)
    guard input.contains(CitationMarkers.start) else { return parsed }

    var output = AttributedString()
    for run in parsed.runs {
      let piece = parsed[run.range]
      let text = String(piece.characters)
      guard text.contains(CitationMarkers.start) else {
        output.append(piece)
        continue
      }
      let isCodeBlock =
        run.presentationIntent?.components.contains { component in
          if case .codeBlock = component.kind { true } else { false }
        } == true
      for part in CitationMarkers.parts(of: text) {
        switch part {
        case .text(let plain):
          output.append(AttributedString(plain, attributes: run.attributes))
        case .marker(let number):
          guard !isCodeBlock else { continue }
          output.append(Self.pill(number: number, attributes: run.attributes))
        }
      }
    }
    return output
  }

  /// The attributed text of one pill.
  ///
  /// - Parameters:
  ///   - number: The one-based number of the source.
  ///   - attributes: The attributes of the run that holds the marker.
  /// - Returns: One attachment character with the pill and the link.
  private static func pill(number: Int, attributes: AttributeContainer) -> AttributedString {
    var attributes = attributes
    attributes.textual.attachment = AnyAttachment(InlineCitationAttachment(number: number))
    attributes.link = InlineCitation.url(index: number)
    return AttributedString(MathMarkdownParser.attachmentCharacter, attributes: attributes)
  }
}

/// A Textual attachment that shows one ``InlineCitationPill``.
///
/// Textual draws an attachment in a canvas. A canvas has no accessibility
/// children, so ``MarkdownProse`` adds one element for each pill with
/// ``InlineCitationAccessibility``.
nonisolated struct InlineCitationAttachment: Textual.Attachment {
  /// The one-based number of the source.
  let number: Int

  /// The text of the pill in a copy: `[<number>]`.
  var description: String { "[\(number)]" }

  /// A selection of the pill selects its text.
  var selectionStyle: AttachmentSelectionStyle { .text }

  @MainActor var body: some View {
    InlineCitationPill(index: number)
  }

  func baselineOffset(in environment: TextEnvironmentValues) -> CGFloat {
    metrics(in: environment).baselineOffset
  }

  func sizeThatFits(_ proposal: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
    metrics(in: environment).size
  }

  /// The sizes of the pill at the font size of `environment`.
  ///
  /// - Parameter environment: The text environment of the run.
  /// - Returns: The sizes.
  private func metrics(in environment: TextEnvironmentValues) -> InlineCitationMetrics {
    InlineCitationMetrics(index: number, textFontSize: FontScaled(CGFloat(1)).resolve(in: environment))
  }
}

/// One accessibility element for each citation pill of a text.
///
/// Textual draws the pills in a canvas, which has no accessibility children.
/// Put this view in an overlay of the text, so that each pill has a button
/// element. The press action of the element selects the source. The view
/// draws nothing.
struct InlineCitationAccessibility: View {
  /// The one-based source numbers of the pills, in text order.
  let numbers: [Int]

  @Environment(\.citationSelection) private var selection

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(numbers.enumerated()), id: \.offset) { _, number in
        Color.clear
          .frame(width: 1, height: 1)
          .accessibilityElement()
          .accessibilityAddTraits(.isButton)
          .inlineCitationAccessibility(index: number)
          .accessibilityAction { selection?.select(number) }
      }
    }
  }
}
