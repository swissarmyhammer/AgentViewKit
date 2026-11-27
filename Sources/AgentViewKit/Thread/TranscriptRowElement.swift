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
/// The element is one view, so the virtual stack of the list
/// (``TranscriptRowStack``) places and measures one view for each element.
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
/// motion, so a flick does not swap the editors of the rows in view. A row
/// whose height the thread does not know yet shows its real form. When
/// such a row comes into view in a live motion with the height of its
/// first layout, it reads that height again and takes its static form, so
/// it mounts its editors one time in the motion. The mouse holds a row only
/// when it comes on the row at rest: a row that moves under the mouse does
/// not mount its editors.
///
/// Only a row that shows its static form in a live motion of the user
/// (``SwiftUI/EnvironmentValues/transcriptRowsMoveLive``) waits in the
/// ``TranscriptRowMountQueue`` of the thread (card ^7625j1b). The mount of
/// a row that the list makes in a live motion waits from the start of the
/// row, so the row stays static at rest also when it did not appear before
/// the rest. A row in view puts its mount in the queue when it shows its
/// static form in a live motion. A row that shows its real form never
/// waits: its mount leaves the queue at once, so a row that is real at the
/// end of a motion stays real at rest. A row that a scroll of the kit
/// makes, such as the row of a jump, does not wait. A row that leaves the
/// view leaves the queue and keeps its wait, so a row that the list keeps
/// out of view does not mount its editors. At rest, each EditorKit text
/// area of the row shows its editor after its own turn
/// (``TranscriptSlotMount``), and the row keeps the frame of its static
/// form until each text area is real, so the rows in view do not mount
/// their editors in one frame. While the row waits, it gives the queue its
/// distance from the vertical center of the view. A row that is real at
/// rest or in a motion for a different cause, such as a hold, leaves the
/// queue at once,
/// and each of its text areas shows its editor.
///
/// In a live motion of the user, the row and its status lines take no hit
/// test, so SwiftUI does not hit-test their hover responders on each frame
/// of a flick, and the live motion ends the hover of the row
/// (``TranscriptRowHover``). A scroll-wheel event goes to the scroll view
/// of the list. At rest, the row takes the hit test again.
struct TranscriptRowElement: View, Equatable {
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
  @Environment(\.transcriptRowsMoveLive) private var rowsMoveLive
  @Environment(\.staticRowHeights) private var heights
  @Environment(\.transcriptRowMounts) private var mounts
  @Environment(\.sessionModel) private var session
  @Environment(\.textSelectionRegion) private var threadSelection
  @FocusedValue(\.commandPath) private var focusedPath

  /// The text selection region of the row.
  @State private var selection = TranscriptRowSelection()

  /// Whether the mouse came on the row at rest, and is still on it.
  @State private var hover = TranscriptRowHover()

  /// Whether the row showed its real form at rest. A row that the list
  /// makes while the rows move did not, until its turn in the queue.
  @State private var wasShownAtRest = false

  /// The count of the reads of the height of the first layout of the row.
  /// A row in view that is real in a live motion, only because the thread
  /// did not know its height, changes it when the thread knows the height,
  /// so the row evaluates its form again with that height. The height
  /// record is not observable.
  @State private var heightReads = 0

  /// The turn of the row in the queue of the thread.
  @State private var mount: TranscriptRowMount

  /// Makes the element of an entry.
  ///
  /// - Parameters:
  ///   - slot: The entry of the row, and its position.
  ///   - isLast: Whether the entry is the last entry of the transcript.
  ///   - lines: The status lines after the entry, in arrival order.
  ///   - entersWhileMoving: Whether the rows of the thread move in a live
  ///     motion of the user when the list makes the row. The mount of such
  ///     a row waits from its start, until the row shows its real form.
  init(slot: TranscriptRowSlot, isLast: Bool, lines: [ModelChangeLine], entersWhileMoving: Bool = false) {
    self.slot = slot
    self.isLast = isLast
    self.lines = lines
    _mount = State(initialValue: TranscriptRowMount(waits: entersWhileMoving))
  }

  var body: some View {
    let row = ItemRow(entry: slot.entry)
    let rowsMove = rowsMove
    // The body reads the count, so a new read of the height evaluates it.
    let _ = heightReads
    let slotForm = TranscriptRowForm.slotForm(
      rowsMove: rowsMove, waitsToMount: mounts != nil && mount.waits, holds: holds,
      knowsHeight: heights?.knowsHeight(of: slot.id) ?? false)
    let isStatic = slotForm != .real
    let formChange = TranscriptRowFormChange(isStatic: isStatic, rowsMove: rowsMove, rowsMoveLive: rowsMoveLive)
    VStack(alignment: .leading, spacing: editorStyle.tile.margin) {
      row
        .equatable()
        .accessibilityReadingGroup(ThreadAccessibility.threadGroupID)
        .modifier(TranscriptSearchRowMark(rowKey: row.id))
        .environment(\.transcriptRowPosition, slot.position)
        .modifier(TranscriptRowLiveness(position: slot.position))
        .coordinateSpace(.named(TranscriptFileOrder.rowSpace))
        .textSelectionRegion(selection.forwarding(to: threadSelection))
        .environment(\.transcriptRowMount, mount)
        .modifier(
          TranscriptStaticRow(id: slot.id, slotForm: slotForm, heights: heights) {
            noteFirstHeight(rowsMoveLive: rowsMoveLive)
          })
        .onHover { hovering in
          // A row that comes under the mouse while the rows move takes no
          // hold, so it does not mount its editors during the move.
          hover.note(hovering: hovering, rowsMove: rowsMove)
        }
      TranscriptStatusLines(lines: lines)
    }
    .padding(.bottom, isLast ? editorStyle.rowPadding : 0)
    // In a live motion, the content moves under a still mouse, and SwiftUI
    // hit-tests each hover responder of the rows again on each frame. The
    // rows take no hit test then, so they have no hover responder to test.
    // A scroll-wheel event goes to the scroll view of the list.
    .allowsHitTesting(!rowsMoveLive)
    .background {
      if mount.waits {
        Color.clear.onGeometryChange(for: CGFloat.self, of: TranscriptRowMount.centerDistance(of:)) { distance in
          mount.centerDistance = distance
        }
      }
    }
    .onAppear { noteAppear(isStatic: isStatic, rowsMoveLive: rowsMoveLive) }
    .onDisappear { noteDisappear() }
    .onChange(of: formChange, initial: true) { _, change in
      noteForm(change)
    }
  }

  /// Tells whether two elements show the same row: the same entry object at
  /// the same position, the same last state, and the same status lines.
  ///
  /// The virtual stack of the list evaluates its body each time that the
  /// rows in view change (``TranscriptRowStack``). With this equality, an
  /// element that stays in the stack does not evaluate its body again then
  /// (card ^kr7cx7b). The motion of the rows when the list makes the element
  /// sets only the first turn of the element, so it is not part of the
  /// equality.
  ///
  /// - Parameters:
  ///   - lhs: An element.
  ///   - rhs: An element.
  /// - Returns: `true` when the two elements show the same row.
  static func == (lhs: TranscriptRowElement, rhs: TranscriptRowElement) -> Bool {
    lhs.slot.position == rhs.slot.position && lhs.slot.id == rhs.slot.id
      && ObjectIdentifier(lhs.slot.entry.object) == ObjectIdentifier(rhs.slot.entry.object)
      && lhs.isLast == rhs.isLast && lhs.lines == rhs.lines
  }

  /// Records that the row comes into view. A static row in a live motion,
  /// or a row whose mount waits, puts its mount in the queue of the thread.
  /// A real row whose height the thread knows now reads that height
  /// (``readHeightIfNeeded(rowsMoveLive:)``).
  ///
  /// - Parameters:
  ///   - isStatic: Whether the row shows its static form.
  ///   - rowsMoveLive: Whether the rows of the thread move in a live
  ///     motion of the user.
  private func noteAppear(isStatic: Bool, rowsMoveLive: Bool) {
    mount.isInView = true
    if isStatic {
      guard rowsMoveLive || mount.waits else { return }
      mounts?.enqueue(mount)
    } else if heights?.knowsHeight(of: slot.id) == true {
      readHeightIfNeeded(rowsMoveLive: rowsMoveLive)
    }
  }

  /// Records that the thread knows the height of the row for the first
  /// time: a row in view reads that height
  /// (``readHeightIfNeeded(rowsMoveLive:)``). A row out of view reads it
  /// when it comes into view, so it does not change form out of view.
  ///
  /// - Parameter rowsMoveLive: Whether the rows of the thread move in a
  ///   live motion of the user.
  private func noteFirstHeight(rowsMoveLive: Bool) {
    guard mount.isInView else { return }
    readHeightIfNeeded(rowsMoveLive: rowsMoveLive)
  }

  /// Evaluates the form of the row again with the height that the thread
  /// knows now, when the row is real in a live motion only because the
  /// thread did not know its height, and the thread has a queue. The row
  /// then takes its static form in the step in which it gets its height,
  /// and waits in the queue, so it mounts its editors one time in the
  /// motion.
  ///
  /// - Parameter rowsMoveLive: Whether the rows of the thread move in a
  ///   live motion of the user.
  private func readHeightIfNeeded(rowsMoveLive: Bool) {
    guard mounts != nil, rowsMoveLive, !holds.keepsRealRow else { return }
    heightReads += 1
  }

  /// Records that the row leaves the view: its mount leaves the queue of
  /// the thread, and keeps its wait.
  private func noteDisappear() {
    mount.isInView = false
    mounts?.withdraw(mount)
  }

  /// Records a new form of the row.
  ///
  /// A real row leaves the queue and does not wait, at rest or in a
  /// motion. A real row at rest holds its real form in the next motion. A
  /// row in view that takes its static form in a live motion puts its
  /// mount in the queue. A live motion ends the hover of the row
  /// (``TranscriptRowHover/noteLiveMotion()``).
  ///
  /// - Parameter change: The form of the row and the motion of the rows.
  private func noteForm(_ change: TranscriptRowFormChange) {
    if change.rowsMoveLive, hover.isHovered {
      hover.noteLiveMotion()
    }
    guard change.isStatic else {
      mounts?.release(mount)
      if !change.rowsMove, !wasShownAtRest {
        wasShownAtRest = true
      }
      return
    }
    if change.rowsMoveLive, mount.isInView {
      mounts?.enqueue(mount)
    }
  }

  /// The holds that keep the row real while the rows move.
  ///
  /// Only the last row reads the state of the agent, so a change of the
  /// state evaluates no other row.
  private var holds: TranscriptRowHolds {
    TranscriptRowHolds(
      wasRealAtRest: wasShownAtRest,
      hasFocus: TranscriptRowHolds.hasFocus(itemScope: slot.entry.itemScopeSegment, focusedPath: focusedPath),
      isHovered: hover.isHovered,
      hasSelection: selection.holdsSelection,
      streams: isLast && session?.isRunning == true)
  }
}

/// The form of a row of a thread and the motion of its rows, whose change
/// the row records (``TranscriptRowElement``, card ^7625j1b).
struct TranscriptRowFormChange: Equatable {
  /// Whether the row shows its static form.
  let isStatic: Bool

  /// Whether the rows of the thread move (``TranscriptRowMotion``).
  let rowsMove: Bool

  /// Whether the rows of the thread move in a live motion of the user.
  let rowsMoveLive: Bool
}

/// Whether the mouse is on a row of a thread, as the row records it for its
/// hover hold (``TranscriptRowHolds/isHovered``, card ^9ync5h3).
///
/// The mouse holds a row only when it comes on the row at rest: a row that
/// moves under the mouse does not mount its editors. In a live motion, the
/// rows take no hit test and get no hover callback
/// (``TranscriptRowElement``), so a live motion clears the hover. When the
/// rows come to rest, the next hover callback of SwiftUI sets it again.
struct TranscriptRowHover: Equatable {
  /// Whether the mouse came on the row at rest, and is still on it.
  private(set) var isHovered = false

  /// Records a hover callback of the row.
  ///
  /// - Parameters:
  ///   - hovering: Whether the mouse is on the row.
  ///   - rowsMove: Whether the rows of the thread move. A mouse that comes
  ///     on the row while the rows move does not hover it.
  mutating func note(hovering: Bool, rowsMove: Bool) {
    guard !hovering || !rowsMove else { return }
    isHovered = hovering
  }

  /// Records that the rows of the thread move in a live motion of the
  /// user: the row takes no more hover callback, so its hover ends.
  mutating func noteLiveMotion() {
    isHovered = false
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
