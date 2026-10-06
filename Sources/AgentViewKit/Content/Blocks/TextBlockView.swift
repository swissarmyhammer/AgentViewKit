import SwiftUI

/// The default view of one text block (plan.md §4.2, §9 A2).
///
/// The view shows the text in a ``ResponseView`` that the id of the block
/// view keys, not the id of the message that holds the block. The code block
/// cache and the evaluation counters use that id, so two text blocks of one
/// message must not use the same id.
struct TextBlockView: View {
  /// The Markdown text of the block.
  let text: String

  /// The id of the block view, such as `<message id>-<block index>`.
  let id: String

  var body: some View {
    ResponseView(id: id, markdown: text)
  }
}
