import FoundationModelsACP
import SwiftUI

/// The content blocks of one transcript entry of a `SessionModel`, such as the
/// content of an agent message, of a thought, or the summary of a compaction
/// (plan.md §3.2).
///
/// The view gets the ACP blocks as the entry holds them, and it keeps no copy.
/// Each evaluation joins the adjacent text chunks again
/// (``joiningAdjacentText(in:)``), and shows each block in a
/// ``ContentBlockView``. The id of the block view at `index` is
/// `<id>-<index>`.
struct EntryContentView: View {
  /// The content blocks of the entry, as the entry holds them.
  let content: [FoundationModelsACP.ContentBlock]

  /// The start of the id of each block view, such as the row key of the
  /// entry.
  let id: String

  /// The blocks that the view shows: the content of an entry, with each run of
  /// adjacent text blocks with the same annotations as one text block.
  ///
  /// The session model adds each streamed chunk of an entry as one block. The
  /// texts of a run join with no separator, so the view shows the streamed
  /// text as one text, and not as one paragraph for each chunk.
  ///
  /// - Parameter content: The content blocks of an entry.
  /// - Returns: The blocks to show, in order.
  nonisolated static func joiningAdjacentText(
    in content: [FoundationModelsACP.ContentBlock]
  ) -> [FoundationModelsACP.ContentBlock] {
    content.reduce(into: []) { blocks, block in
      if let last = blocks.last, let joined = joinedText(of: last, and: block) {
        blocks[blocks.index(before: blocks.endIndex)] = joined
      } else {
        blocks.append(block)
      }
    }
  }

  /// One text block with the text of two text blocks.
  ///
  /// - Parameters:
  ///   - first: The earlier block.
  ///   - second: The later block.
  /// - Returns: The joined block, with the annotations and the `_meta` value
  ///   of `first`, or `nil` when a block is not text or the annotations are
  ///   different.
  private nonisolated static func joinedText(
    of first: FoundationModelsACP.ContentBlock, and second: FoundationModelsACP.ContentBlock
  ) -> FoundationModelsACP.ContentBlock? {
    guard case .text(let firstText) = first, case .text(let secondText) = second,
      firstText.annotations == secondText.annotations
    else { return nil }
    var joined = firstText
    joined.text += secondText.text
    return .text(joined)
  }

  /// The id of the view of the block at `index` of an entry.
  ///
  /// - Parameters:
  ///   - entryID: The start of the id, such as the row key of the entry.
  ///   - index: The position of the block in the shown blocks.
  /// - Returns: `<entry id>-<index>`.
  static func blockID(entryID: String, index: Int) -> String {
    "\(entryID)-\(index)"
  }

  var body: some View {
    let blocks = Array(Self.joiningAdjacentText(in: content).enumerated())
    ForEach(blocks, id: \.offset) { index, block in
      ContentBlockView(block: block, id: Self.blockID(entryID: id, index: index))
    }
  }
}
