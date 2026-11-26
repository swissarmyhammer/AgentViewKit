import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
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
///
/// A row that comes into the list while the rows move
/// (``TranscriptRowMotion``) shows its static form (``TranscriptStaticRow``,
/// card ^9ync5h3), unless a hold keeps it real (``TranscriptRowHolds``): the
/// keyboard focus in its item scope, the mouse, the text selection of the
/// thread in one of its text areas, or the stream of its entry. A row that
/// was shown at rest before the motion started stays real for the whole
/// motion, so a flick does not swap the editors of the rows in view. A row whose height the thread does not know yet
/// shows its real form. The mouse holds a row only when it comes on the row
/// at rest: a row that moves under the mouse does not mount its editors.
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
  @Environment(\.transcriptRowsMove) private var rowsMove
  @Environment(\.staticRowHeights) private var heights
  @Environment(\.sessionModel) private var session
  @Environment(\.textSelectionRegion) private var threadSelection
  @FocusedValue(\.commandPath) private var focusedPath

  /// The text selection region of the row.
  @State private var selection = TranscriptRowSelection()

  /// Whether the mouse came on the row at rest, and is still on it.
  @State private var isHovered = false

  /// Whether the row was shown at rest, and thus in its real form. A row
  /// that the list makes while the rows move was not.
  @State private var wasShownAtRest = false

  var body: some View {
    let row = ItemRow(entry: slot.entry)
    let rowsMove = rowsMove
    let isStatic = TranscriptRowForm.isStatic(
      rowsMove: rowsMove, holds: holds, knowsHeight: heights?.knowsHeight(of: slot.id) ?? false)
    VStack(alignment: .leading, spacing: editorStyle.tile.margin) {
      row
        .equatable()
        .accessibilityReadingGroup(ThreadAccessibility.threadGroupID)
        .modifier(TranscriptSearchRowMark(rowKey: row.id))
        .environment(\.transcriptRowPosition, slot.position)
        .modifier(TranscriptRowLiveness(position: slot.position))
        .coordinateSpace(.named(TranscriptFileOrder.rowSpace))
        .textSelectionRegion(selection.forwarding(to: threadSelection))
        .modifier(TranscriptStaticRow(id: slot.id, isStatic: isStatic, heights: heights))
        .onHover { hovering in
          // A row that comes under the mouse while the rows move takes no
          // hold, so it does not mount its editors during the move.
          if !hovering || !rowsMove {
            isHovered = hovering
          }
        }
      TranscriptStatusLines(lines: lines)
    }
    .padding(.bottom, isLast ? editorStyle.rowPadding : 0)
    .onAppear { noteRest(rowsMove: rowsMove) }
    .onChange(of: rowsMove) { noteRest(rowsMove: rowsMove) }
  }

  /// Records that the row was shown at rest, when the rows do not move.
  ///
  /// - Parameter rowsMove: Whether the rows of the thread move.
  private func noteRest(rowsMove: Bool) {
    guard !rowsMove, !wasShownAtRest else { return }
    wasShownAtRest = true
  }

  /// The holds that keep the row real while the rows move.
  ///
  /// Only the last row reads the state of the agent, so a change of the
  /// state evaluates no other row.
  private var holds: TranscriptRowHolds {
    TranscriptRowHolds(
      wasRealAtRest: wasShownAtRest,
      hasFocus: TranscriptRowHolds.hasFocus(itemScope: slot.entry.itemScopeSegment, focusedPath: focusedPath),
      isHovered: isHovered,
      hasSelection: selection.holdsSelection,
      streams: isLast && session?.isRunning == true)
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
