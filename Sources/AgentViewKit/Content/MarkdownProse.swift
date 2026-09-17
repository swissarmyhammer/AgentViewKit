import SwiftUI
import Textual

/// One Markdown text of a response, with its math and its citation pills
/// (plan.md §4.2, §9 B, §9 C).
///
/// ``ParagraphView`` and the streaming tail of ``ResponseView`` show their
/// text with this view, so that settled text and streaming text show math
/// the same way.
///
/// - A text that is only one `$$…$$` block shows a block ``MathView``,
///   centered. It shows no citation pill.
/// - Other text renders through Textual with ``MathMarkdownParser``. Each
///   math span gets an accessibility element from
///   ``MathSpanAccessibility``. The text element reads each span at its
///   place, as its LaTeX source (``MathMarkdownParser/spokenText(for:)``).
/// - Each citation placement becomes an ``InlineCitation`` pill in the text,
///   through ``CitationMarkdownParser``. Each pill gets an accessibility
///   element from ``InlineCitationAccessibility``.
struct MarkdownProse: View {
  /// The Markdown text.
  let text: String

  /// The citation pills of the text.
  var citations: [CitationPlacement] = []

  var body: some View {
    let parser = MathMarkdownParser()
    if let block = MathSpanScanner.soleBlock(in: text),
      MathView.canTypeset(block.latex, display: block.display)
    {
      MathView(latex: block.latex, display: block.display)
        .frame(maxWidth: .infinity)
    } else {
      let marked = CitationMarkers.marked(text, placements: citations)
      let spans = parser.mathSpans(in: text)
      StructuredText(marked.text, parser: CitationMarkdownParser(base: parser))
        .modifier(SpokenMathText(spoken: spans.isEmpty ? nil : parser.spokenText(for: text)))
        .overlay(alignment: .topLeading) {
          MathSpanAccessibility(spans: spans)
        }
        .overlay(alignment: .topLeading) {
          InlineCitationAccessibility(numbers: marked.numbers)
        }
    }
  }
}

/// Makes the text of a paragraph with math one element that reads each math
/// span at its place (plan.md §6).
///
/// Textual draws the math in a canvas, so the text element does not read
/// it. With a spoken text, the modifier combines the text into one element
/// with the spoken text as its label. The elements of
/// ``MathSpanAccessibility`` stay, so that each formula is also an element
/// of its own.
private struct SpokenMathText: ViewModifier {
  /// The text that VoiceOver reads, or `nil` to keep the text as it is.
  let spoken: String?

  func body(content: Content) -> some View {
    if let spoken {
      content
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: spoken))
    } else {
      content
    }
  }
}
