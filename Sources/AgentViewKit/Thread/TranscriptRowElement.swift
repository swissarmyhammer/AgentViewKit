import EditorStyle
import FoundationModelsACPClient
import SwiftUI

/// One shown entry of the transcript and its position in the transcript.
///
/// The `ForEach` of the rows of a ``ConversationView`` maps the positions of
/// the shown entries to slots lazily, so a body of the list builds no array
/// of the entries. The id of a slot is the id of its entry, so the row
/// identity is `TranscriptEntry.id` (plan.md §3.8) and not the position: a
/// replay gives a position to a new entry.
struct TranscriptRowSlot: Identifiable {
  /// The position of the entry in the transcript.
  let position: Int

  /// The entry.
  let entry: TranscriptEntry

  /// The id of the entry.
  var id: TranscriptEntry.ID {
    entry.id
  }
}

/// One element of the `ForEach` of the rows of a ``ConversationView``: the
/// row of an entry, and the modelChanged status lines after it
/// (task ^c4sg6gz).
///
/// The element is one view, so the lazy stack of the list measures one view
/// for each element.
///
/// The row gives its position in the transcript and its coordinate space to
/// the file views in it, which place their files in the
/// ``TranscriptFileOrder`` of the thread (card ^4138tmp). The row gets its
/// liveness as a `Bool` (``TranscriptRowLiveness``), so a move of the
/// ``LiveRowRange`` evaluates only the responses of the rows that enter or
/// leave the range. The row gets the search mark of its entry
/// (``TranscriptSearchRowMark``). A row with no search hit gets nothing.
/// The row and the lines are in the linked reading group of the thread, so
/// VoiceOver reads from one row into the next row
/// (``ThreadAccessibility/threadGroupID``).
struct TranscriptRowElement: View {
  /// The entry of the row, and its position.
  let slot: TranscriptRowSlot

  /// Whether the entry is the last entry of the transcript.
  ///
  /// The element of the last entry has the row padding of the style below
  /// it, in place of a bottom inset of the content of the list. Thus the
  /// bottom of the element is the end of the content, and a scroll to the
  /// bottom of the element stops at the end of the content (task ^pc1w14d).
  let isLast: Bool

  /// The status lines after the entry, in arrival order.
  let lines: [ModelChangeLine]

  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    let row = ItemRow(entry: slot.entry)
    VStack(alignment: .leading, spacing: editorStyle.tile.margin) {
      row
        .equatable()
        .accessibilityReadingGroup(ThreadAccessibility.threadGroupID)
        .modifier(TranscriptSearchRowMark(rowKey: row.id))
        .environment(\.transcriptRowPosition, slot.position)
        .modifier(TranscriptRowLiveness(position: slot.position))
        .coordinateSpace(.named(TranscriptFileOrder.rowSpace))
      TranscriptStatusLines(lines: lines)
    }
    .padding(.bottom, isLast ? editorStyle.rowPadding : 0)
  }
}

/// The status lines of the modelChanged notices at one place of a
/// ``ConversationView``, in the linked reading group of the thread.
///
/// A line has no text identity, so it is not a scroll target of the anchors
/// (``ModelChangeLine/ID``).
struct TranscriptStatusLines: View {
  /// The lines, in arrival order.
  let lines: [ModelChangeLine]

  var body: some View {
    ForEach(lines) { line in
      ModelChangeNoticeView(line: line)
        .accessibilityReadingGroup(ThreadAccessibility.threadGroupID)
    }
  }
}
