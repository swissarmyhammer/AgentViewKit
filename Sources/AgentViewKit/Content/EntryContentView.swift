import EditorStyle
import FoundationModelsACP
import SwiftUI

/// The content blocks of one transcript entry of a `SessionModel`, such as the
/// content of an agent message, of a thought, or the summary of a compaction
/// (plan.md §3.2).
///
/// The view gets the ACP blocks as the entry holds them. It joins the
/// adjacent text chunks (``joiningAdjacentText(in:)``) one time for each
/// change of the content, and keeps the joined blocks for that content
/// (``ParseMemo``). It shows each block in a ``ContentBlockView``. The id of
/// the block view at `index` is `<id>-<index>`.
struct EntryContentView: View {
  /// The content blocks of the entry, as the entry holds them.
  let content: [FoundationModelsACP.ContentBlock]

  /// The start of the id of each block view, such as the row key of the
  /// entry.
  let id: String

  /// The shown blocks of the last content, kept for that content.
  @State private var joinMemo =
    ParseMemo<[FoundationModelsACP.ContentBlock], [FoundationModelsACP.ContentBlock]>()

  /// The start of the ``BodyEvaluationCounter`` key of each entry.
  static let counterKeyPrefix = "entry-content-"

  /// The start of the ``BodyEvaluationCounter`` key of the text joins of
  /// each entry.
  static let joinCounterKeyPrefix = "entry-join-"

  /// The ``BodyEvaluationCounter`` key of the entry `id`.
  ///
  /// - Parameter id: The start of the id of each block view of the entry.
  /// - Returns: `entry-content-<id>`.
  static func counterKey(for id: String) -> String {
    BodyEvaluationKey.make(prefix: counterKeyPrefix, id: id)
  }

  /// The ``BodyEvaluationCounter`` key of the text joins of the entry `id`.
  ///
  /// - Parameter id: The start of the id of each block view of the entry.
  /// - Returns: `entry-join-<id>`.
  static func joinCounterKey(for id: String) -> String {
    BodyEvaluationKey.make(prefix: joinCounterKeyPrefix, id: id)
  }

  /// The blocks that the view shows: the content of an entry, with each run of
  /// adjacent text blocks with the same annotations as one text block.
  ///
  /// The session model adds each streamed chunk of an entry as one block. The
  /// texts of a run join with no separator, so the view shows the streamed
  /// text as one text, and not as one paragraph for each chunk.
  ///
  /// The join is one pass over the blocks: it finds the runs, and joins the
  /// texts of each run with one `joined()` call. Thus its time is linear in
  /// the length of the content.
  ///
  /// - Parameter content: The content blocks of an entry.
  /// - Returns: The blocks to show, in order.
  nonisolated static func joiningAdjacentText(
    in content: [FoundationModelsACP.ContentBlock]
  ) -> [FoundationModelsACP.ContentBlock] {
    runs(in: content).map { joined(content[$0]) }
  }

  /// The ranges of the runs of `content`. A run is a block that is not text,
  /// or adjacent text blocks with the same annotations.
  ///
  /// - Parameter content: The content blocks of an entry.
  /// - Returns: The ranges, in order. Together they hold each block one time.
  private nonisolated static func runs(
    in content: [FoundationModelsACP.ContentBlock]
  ) -> [Range<Int>] {
    let starts = content.indices.filter { index in
      index == content.startIndex || !continuesRun(content[index - 1], with: content[index])
    }
    return zip(starts, starts.dropFirst() + [content.endIndex]).map { $0..<$1 }
  }

  /// Whether `second` continues the run of `first`.
  ///
  /// - Parameters:
  ///   - first: The earlier block.
  ///   - second: The later block.
  /// - Returns: `true` when the two blocks are text with the same
  ///   annotations.
  private nonisolated static func continuesRun(
    _ first: FoundationModelsACP.ContentBlock, with second: FoundationModelsACP.ContentBlock
  ) -> Bool {
    guard let firstText = textContent(of: first), let secondText = textContent(of: second) else {
      return false
    }
    return firstText.annotations == secondText.annotations
  }

  /// One block with the text of each block of a run.
  ///
  /// - Parameter run: The blocks of one run, not empty.
  /// - Returns: The first block of the run when the run has one block, or
  ///   the run is not text. Otherwise one text block with the texts of the
  ///   run, with the annotations and the `_meta` value of the first block.
  private nonisolated static func joined(
    _ run: ArraySlice<FoundationModelsACP.ContentBlock>
  ) -> FoundationModelsACP.ContentBlock {
    let first = run[run.startIndex]
    guard run.count > 1, var text = textContent(of: first) else { return first }
    text.text = run.compactMap { textContent(of: $0)?.text }.joined()
    return .text(text)
  }

  /// The text content of `block`.
  ///
  /// - Parameter block: A content block.
  /// - Returns: The text content, or `nil` when the block is not text.
  private nonisolated static func textContent(
    of block: FoundationModelsACP.ContentBlock
  ) -> TextContent? {
    guard case .text(let text) = block else { return nil }
    return text
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
    #if DEBUG
      let _ = BodyEvaluationCounter.note(Self.counterKey(for: id))
    #endif
    let joined = joinMemo.value(
      for: content, counterKey: Self.joinCounterKey(for: id), parse: Self.joiningAdjacentText(in:))
    let blocks = Array(joined.enumerated())
    ForEach(blocks, id: \.offset) { index, block in
      ContentBlockView(block: block, id: Self.blockID(entryID: id, index: index))
    }
  }
}

#Preview("Each kind of content, one after the other") {
  // The image and the sound hold their bytes, so the blocks read no file.
  EditorScrollView {
    VStack(alignment: .leading) {
      EntryContentView(content: PreviewFixtures.contentOfEachKind, id: "preview-content")
    }
    .frame(width: PreviewFixtures.narrowWidth)
    .padding()
  }
}
