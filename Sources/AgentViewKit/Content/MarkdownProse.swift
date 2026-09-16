import SwiftUI
import Textual

/// One Markdown text of a response, with its math (plan.md §4.2, §9 B).
///
/// ``ParagraphView`` and the streaming tail of ``ResponseView`` show their
/// text with this view, so that settled text and streaming text show math
/// the same way.
///
/// - A text that is only one `$$…$$` block shows a block ``MathView``,
///   centered.
/// - Other text renders through Textual with ``MathMarkdownParser``. Each
///   math span gets an accessibility element from
///   ``MathSpanAccessibility``.
struct MarkdownProse: View {
  /// The Markdown text.
  let text: String

  var body: some View {
    let parser = MathMarkdownParser()
    if let block = MathSpanScanner.soleBlock(in: text),
      MathView.canTypeset(block.latex, display: block.display)
    {
      MathView(latex: block.latex, display: block.display)
        .frame(maxWidth: .infinity)
    } else {
      StructuredText(text, parser: parser)
        .overlay(alignment: .topLeading) {
          MathSpanAccessibility(spans: parser.mathSpans(in: text))
        }
    }
  }
}
