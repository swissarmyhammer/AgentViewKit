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
///   ``MathSpanAccessibility``.
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
      StructuredText(marked.text, parser: CitationMarkdownParser(base: parser))
        .overlay(alignment: .topLeading) {
          MathSpanAccessibility(spans: parser.mathSpans(in: text))
        }
        .overlay(alignment: .topLeading) {
          InlineCitationAccessibility(numbers: marked.numbers)
        }
    }
  }
}
