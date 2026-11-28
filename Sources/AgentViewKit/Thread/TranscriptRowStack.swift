import EditorStyle
import FoundationModelsACPClient
import SwiftUI
import Synchronization

/// The geometry of the shown rows of a thread, and the position in the
/// transcript of the first shown row (``TranscriptRowStack``).
nonisolated struct TranscriptStackGeometry: Equatable, Sendable {
  /// The position in the transcript of the first shown row.
  let firstPosition: Int

  /// The geometry of the shown rows.
  let rows: TranscriptRowGeometry

  /// The index in ``rows`` of the row at a position of the transcript.
  ///
  /// - Parameter position: The position in the transcript.
  /// - Returns: The index, which can be outside the shown rows.
  func index(ofPosition position: Int) -> Int {
    position - firstPosition
  }

  /// The row key of the row at a position of the transcript.
  ///
  /// - Parameter position: The position in the transcript.
  /// - Returns: The row key, or `nil` when the row is not shown.
  func rowKey(atPosition position: Int) -> String? {
    let index = index(ofPosition: position)
    return rows.rowKeys.indices.contains(index) ? rows.rowKeys[index] : nil
  }
}

/// The heights of the parts of the list of a thread under its bars: the
/// top and the bottom content insets of its scroll view
/// (``TranscriptRowStack``, card ^6fax5yx).
///
/// In an ``AgentThreadView``, the list goes on under the header and under
/// the composer, and the scroll view gives the heights of the bars as its
/// content insets. The bounds of the scroll view leave out those parts, but
/// the glass of each bar shows the rows under it.
nonisolated struct TranscriptScrollInsets: Equatable, Sendable {
  /// The insets of a list with no bars.
  static let zero = TranscriptScrollInsets(top: .zero, bottom: .zero)

  /// The height of the part under the top bar, in points.
  let top: CGFloat

  /// The height of the part under the bottom bar, in points.
  let bottom: CGFloat
}

/// The heights of the parts of the list of a thread under its bars, which
/// the window of the virtual stack reads (``TranscriptRowWindow``).
///
/// The list writes the value from its scroll geometry. Only the body of the
/// window reads it, so a change evaluates only the window, and not the list
/// or the stack. An evaluation of the list in the first layout passes of a
/// thread, when the bars get their heights, moved the first scroll to the
/// bottom away from the bottom in the inspector gallery screen
/// (card ^6fax5yx).
@MainActor @Observable final class TranscriptScrollInsetsModel {
  /// The heights of the parts under the bars.
  var value = TranscriptScrollInsets.zero

  /// Makes a model of a list with no bars.
  init() {}
}

/// The rows in view of the virtual stack of a thread, and the height of the
/// part in view (``TranscriptRowStack``).
///
/// The window of the stack reads the value from its geometry on each frame
/// of a scroll, and keeps it in its record (``TranscriptViewportRecord``)
/// with no action of SwiftUI. The value changes only when the first or the
/// last row in view changes, or when the height of the part in view
/// changes.
nonisolated struct TranscriptViewport: Equatable, Sendable {
  /// The positions in the transcript of the rows in view between the bars
  /// of the list: the rows in the bounds of the scroll view.
  let visible: Range<Int>

  /// The positions in the transcript of the rows that show: the rows in
  /// view between the bars, and the rows under the bars
  /// (``TranscriptScrollInsets``).
  let shown: Range<Int>

  /// The height of the part in view between the bars.
  let height: CGFloat

  /// Reads the value from the part in view of the stack.
  ///
  /// - Parameters:
  ///   - bounds: The bounds of the scroll view, in the coordinates of the
  ///     stack. They leave out the parts under the bars.
  ///   - insets: The heights of the parts under the bars.
  ///   - geometry: The geometry of the shown rows.
  init(bounds: CGRect, insets: TranscriptScrollInsets, geometry: TranscriptStackGeometry) {
    let first = geometry.firstPosition
    let rows = geometry.rows.visibleRows(offset: bounds.minY, viewportHeight: bounds.height)
    let shownRows = geometry.rows.rows(from: bounds.minY - insets.top, to: bounds.maxY + insets.bottom)
    visible = (rows.lowerBound + first)..<(rows.upperBound + first)
    shown = (shownRows.lowerBound + first)..<(shownRows.upperBound + first)
    height = bounds.height
  }

  /// Whether the rows in view moved down the transcript from an older
  /// report to this one: `true` for a move down, `false` for a move up,
  /// and `nil` when the rows in view did not move.
  ///
  /// - Parameter old: The older report.
  /// - Returns: The direction of the move, or `nil`.
  func movesDown(from old: TranscriptViewport) -> Bool? {
    if visible.lowerBound != old.visible.lowerBound {
      return visible.lowerBound > old.visible.lowerBound
    }
    guard visible.upperBound != old.visible.upperBound else { return nil }
    return visible.upperBound > old.visible.upperBound
  }

  /// The position of the lead row of a motion: the row next to the shown
  /// rows in the direction of the motion.
  ///
  /// - Parameters:
  ///   - movesDown: Whether the motion goes down the transcript.
  ///   - positions: The positions of the rows of the transcript that the
  ///     stack shows.
  /// - Returns: The position, or `nil` when no row is past the shown rows
  ///   in that direction.
  func leadPosition(movesDown: Bool, in positions: Range<Int>) -> Int? {
    let lead = movesDown ? shown.upperBound : shown.lowerBound - 1
    return positions.contains(lead) ? lead : nil
  }
}

/// The latest scroll offset of the list of a thread, which the virtual stack
/// reads when it keeps the rows in view at their place
/// (``TranscriptRowStack``).
///
/// The value is not observable: the list writes it on each frame of a
/// scroll, in the transform of its scroll geometry (``record(_:)``), and no
/// body reads it.
///
/// The offset is in the coordinates of a point of the scroll position
/// (`ScrollPosition.scrollTo(y:)`), which the stack writes. Those
/// coordinates start below the top content inset of the scroll view: the
/// content offset less that inset (``positionY(contentOffsetY:topInset:)``).
/// In an ``AgentThreadView``, the top inset is the height of the header. A
/// write of the content offset moved the list up by that height, the move
/// brought new rows under the header, and their heights moved the list
/// again, up to the top of the transcript (card ^6fax5yx).
@MainActor final class TranscriptScrollOffset {
  /// The vertical offset of the list, in points, in the coordinates of a
  /// point of the scroll position.
  var y: CGFloat = .zero

  /// The vertical offset of a scroll geometry in the coordinates of a
  /// point of the scroll position.
  ///
  /// - Parameters:
  ///   - contentOffsetY: The vertical content offset of the scroll view.
  ///     It is minus the top inset when the top of the content is in view
  ///     below the top bar.
  ///   - topInset: The top content inset of the scroll view.
  /// - Returns: The offset that `ScrollPosition.scrollTo(y:)` takes to put
  ///   the list at the same place.
  nonisolated static func positionY(contentOffsetY: CGFloat, topInset: CGFloat) -> CGFloat {
    contentOffsetY + topInset
  }

  /// Makes an offset of zero.
  init() {}

  /// Records the offset of a scroll geometry, in the coordinates of a
  /// point of the scroll position (``positionY(contentOffsetY:topInset:)``).
  ///
  /// The list calls it in the transform of its scroll geometry, so a frame
  /// of a scroll writes the offset with no action of SwiftUI.
  ///
  /// - Parameter geometry: The scroll geometry of the list.
  /// - Returns: `true`, the same value on each frame, so the change of the
  ///   geometry runs no action.
  func record(_ geometry: ScrollGeometry) -> Bool {
    y = Self.positionY(contentOffsetY: geometry.contentOffset.y, topInset: geometry.contentInsets.top)
    return true
  }
}

/// The index of a row in the virtual stack of a thread
/// (``TranscriptStackLayout``).
private nonisolated struct TranscriptRowIndexKey: LayoutValueKey {
  static let defaultValue = 0
}

/// Places the mounted rows of a thread at their known tops, and has the
/// exact height of all the shown rows (card ^kr7cx7b).
///
/// The layout does not measure a row to place it. It proposes the width of
/// the stack and no height to each row, so each row takes its own height.
/// The record of the elements (``TranscriptElementHeights``) gives that
/// height to the geometry, and a row whose height was not known moves the
/// rows after it in the next pass.
struct TranscriptStackLayout: Layout {
  /// The geometry of the shown rows.
  let geometry: TranscriptRowGeometry

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    CGSize(width: proposal.width ?? .zero, height: geometry.totalHeight)
  }

  /// The stack has no explicit horizontal alignment guide.
  ///
  /// The default implementation of `Layout` places each subview to merge
  /// their guides, and so it measures each mounted row again. The scroll
  /// view asks for the guides of its content on each layout pass (for its
  /// `.alignment` scroll anchor). In the flick trace, that cost was about
  /// 12 % of the main thread (card ^kr7cx7b).
  func explicitAlignment(
    of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    nil
  }

  /// The stack has no explicit vertical alignment guide, for the same
  /// reason as the horizontal guide.
  func explicitAlignment(
    of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    nil
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for subview in subviews {
      let index = subview[TranscriptRowIndexKey.self]
      guard geometry.heights.indices.contains(index) else { continue }
      subview.place(
        at: CGPoint(x: bounds.minX, y: bounds.minY + geometry.top(ofRow: index)), anchor: .topLeading,
        proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
  }
}

extension View {
  /// Gives the view the index of its row in the virtual stack of a thread.
  ///
  /// - Parameter index: The index of the row in the shown rows.
  /// - Returns: The view with the index as its layout value.
  fileprivate func transcriptRowIndex(_ index: Int) -> some View {
    layoutValue(key: TranscriptRowIndexKey.self, value: index)
  }
}

/// The virtual stack of the shown rows of a ``ConversationView`` (card
/// ^kr7cx7b, spike ^fa3j934).
///
/// One custom layout (``TranscriptStackLayout``) places the rows. Its height
/// is the exact sum of the heights of the shown rows and the spacings
/// (``TranscriptRowGeometry``), and it mounts only the rows in view (with
/// the rows under the bars of the thread, ``TranscriptScrollInsets``), a
/// margin of the rows that it mounted before, and the rows at the end of a
/// scroll of the list that did not end
/// (``TranscriptRowGeometry/mountedRows(visible:shown:viewportHeight:itemRow:keepsBottom:kept:)``).
/// The height of each row comes from ``TranscriptElementHeights``.
///
/// The stack computes the geometry, and its window (``TranscriptRowWindow``)
/// mounts the rows. The window evaluates its body only when the rows in
/// view need a row that it did not mount (``TranscriptMountPlan``), so a
/// scroll step that mounts no row evaluates no body and runs no action of
/// SwiftUI, and the stack does not read the height of each row again.
///
/// When the heights change, such as when a row gets its first layout or
/// the cache of the rows computes a row, and the change moves the first row
/// in view, the stack first lays out the old geometry, and then it takes
/// the new geometry and moves the offset in one step, so that the first row
/// in view stays at its place
/// (``TranscriptRowGeometry/anchoredOffset(_:anchorRowKey:from:)``). The
/// stack does not move the offset while the list follows the bottom (the
/// bottom anchor of the list keeps the end in view), while the scroll
/// position keeps an edge, or while a scroll to an item or to the bottom
/// did not end. A change of the shown rows, such as an
/// append or a new page, takes the new geometry at once.
struct TranscriptRowStack: View {
  /// The session model whose transcript the stack shows.
  let session: SessionModel

  /// The number of the last entries that the stack shows.
  let shownCount: Int

  /// The status lines of the modelChanged notices.
  let placements: ModelChangePlacements

  /// Whether the rows move in a live motion of the user: a row that the
  /// stack makes then waits in the queue of the rows from its start.
  let entersWhileMoving: Bool

  /// Whether the user moves the rows: the elements take no hit test
  /// (``TranscriptRowsHitTest``).
  let rowsMoveLive: Bool

  /// The position in the transcript of the item of a scroll to an item
  /// that did not end, or `nil`.
  let itemPosition: Int?

  /// Whether a scroll to the bottom did not end: the stack mounts the rows
  /// at the bottom.
  let keepsBottom: Bool

  /// The manager of the scroll position of the list.
  let anchors: ScrollAnchorManager

  /// The scroll position of the list. The stack writes it only to keep
  /// the rows in view at their place after a height change.
  let position: ConversationScrollPosition

  /// The latest scroll offset of the list.
  let scrollOffset: TranscriptScrollOffset

  /// The heights of the parts of the list under its bars: the window
  /// mounts the rows there too.
  let insets: TranscriptScrollInsetsModel

  /// The heights of the static rows of the thread: a source of the heights
  /// of the rows. The stack feeds them with its width
  /// (``TranscriptRowHeightsFeed``).
  let rowHeights: TranscriptStaticRowHeights

  /// The prefix of the ``BodyEvaluationCounter`` key of the reads of the
  /// row heights of the stack of a session.
  static let heightReadCounterKeyPrefix = "transcript-stack-height-read-"

  /// The ``BodyEvaluationCounter`` key of the reads of the row heights of
  /// the stack of a session: one count for each row whose height the stack
  /// reads when it computes its geometry.
  ///
  /// - Parameter session: The session of the stack.
  /// - Returns: The key.
  static func heightReadCounterKey(for session: SessionModel) -> String {
    BodyEvaluationKey.make(prefix: heightReadCounterKeyPrefix, object: session)
  }

  @Environment(\.editorStyle) private var editorStyle

  /// The heights of the layouts of the elements.
  @State private var elements = TranscriptElementHeights()

  /// The geometry that the stack laid out, or `nil` before the first one.
  @State private var applied: TranscriptStackGeometry?

  /// The rows in view at the last report of the window. The stack reads it
  /// only when the heights change, so it is not observable.
  @State private var viewport = TranscriptViewportRecord()

  /// The width of the stack, or zero before its first layout.
  @State private var width: CGFloat = .zero

  var body: some View {
    let transcript = session.transcript
    let metrics = metrics
    let target = targetGeometry(of: transcript, metrics: metrics)
    TranscriptRowWindow(
      session: session, geometry: shownGeometry(target), placements: placements,
      entersWhileMoving: entersWhileMoving, rowsMoveLive: rowsMoveLive, itemPosition: itemPosition,
      keepsBottom: keepsBottom, insets: insets, elements: elements, metrics: metrics, rowHeights: rowHeights,
      viewportRecord: viewport)
    .modifier(TranscriptRowHeightsFeed(heights: rowHeights, session: session))
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    .onChange(of: target, initial: true) { apply(target) }
  }

  /// The lengths of the elements: the spacing of the list, and the row
  /// padding of the style below the last element.
  private var metrics: TranscriptElementMetrics {
    TranscriptElementMetrics(spacing: editorStyle.tile.margin, bottomPadding: editorStyle.rowPadding)
  }

  /// The geometry of the shown rows from the heights that are known now.
  ///
  /// The body reads the count of the records of the elements and the
  /// heights of the cache of the rows, so a new height evaluates it again.
  ///
  /// The stack shows at most each entry of the transcript. The stack reads
  /// the transcript itself, and ``shownCount`` comes from the list, so a
  /// change that makes the transcript shorter, such as the reset of a
  /// replay, can evaluate the stack before the list gives the new count.
  ///
  /// - Parameters:
  ///   - transcript: The transcript of the session.
  ///   - metrics: The lengths of the elements.
  /// - Returns: The geometry.
  private func targetGeometry(
    of transcript: [TranscriptEntry], metrics: TranscriptElementMetrics
  ) -> TranscriptStackGeometry {
    _ = elements.revision
    let first = transcript.count - min(shownCount, transcript.count)
    let positions = first..<transcript.count
    let heights = positions.map { position in
      #if DEBUG
        BodyEvaluationCounter.note(Self.heightReadCounterKey(for: session))
      #endif
      let entry = transcript[position]
      let shape = TranscriptElementShape(
        id: entry.id, lineCount: placements.lines(at: .after(entry.id)).count,
        isLast: position == transcript.count - 1)
      return elements.height(of: shape, width: width, source: rowHeights, metrics: metrics)
    }
    let rows = TranscriptRowGeometry(
      rowKeys: positions.map { transcript[$0].rowKey }, heights: heights, spacing: metrics.spacing)
    return TranscriptStackGeometry(firstPosition: first, rows: rows)
  }

  /// The geometry to lay out: the geometry that the stack laid out last,
  /// when the change to `target` moves the first row in view
  /// (``anchoredOffset(from:to:)``) and the two have the same rows, else
  /// `target`.
  ///
  /// Only a change that moves the first row in view waits one pass, so the
  /// new geometry and the new offset come in one step. Each other change,
  /// such as a new height of the last row while the list follows the
  /// bottom, is laid out at once, so no row draws past its place for a
  /// pass. The body reads no state of the scroll position here, so a change
  /// of the pin state or of the position does not evaluate the stack and
  /// compute its geometry again.
  ///
  /// - Parameter target: The geometry from the heights that are known now.
  /// - Returns: The geometry.
  private func shownGeometry(_ target: TranscriptStackGeometry) -> TranscriptStackGeometry {
    guard let applied, applied != target, applied.firstPosition == target.firstPosition,
      applied.rows.rowKeys == target.rows.rowKeys, anchoredOffset(from: applied, to: target) != nil
    else { return target }
    return applied
  }

  /// Takes a new geometry, and moves the offset so the first row in view
  /// stays at its place, when the stack keeps the rows in view
  /// (``keepsRowsInView``).
  ///
  /// - Parameter new: The new geometry.
  private func apply(_ new: TranscriptStackGeometry) {
    let old = applied
    applied = new
    guard let old, let offset = anchoredOffset(from: old, to: new), keepsRowsInView else { return }
    scrollOffset.y = offset
    position.value.scrollTo(y: offset)
  }

  /// The offset that keeps the first row in view at its place after a
  /// change of the geometry, when the change moves that row.
  ///
  /// - Parameters:
  ///   - old: The geometry before the change.
  ///   - new: The geometry after the change.
  /// - Returns: The new offset, or `nil` when the change does not move the
  ///   first row in view.
  private func anchoredOffset(from old: TranscriptStackGeometry, to new: TranscriptStackGeometry) -> CGFloat? {
    guard let first = viewport.value?.visible.lowerBound, let key = old.rowKey(atPosition: first) else {
      return nil
    }
    let offset = scrollOffset.y
    let anchored = new.rows.anchoredOffset(offset, anchorRowKey: key, from: old.rows)
    return anchored == offset ? nil : anchored
  }

  /// Whether the stack moves the offset after a change of the heights: the
  /// list does not follow the bottom, no scroll to an item or to the bottom
  /// waits, and the scroll position keeps no edge.
  ///
  /// A view id that the position keeps after its scroll ended, such as the
  /// last row of the first scroll to the bottom after the list moved away,
  /// does not stop the move: SwiftUI does not apply that id again, and the
  /// new offset keeps the rows in view at their place in the same way.
  private var keepsRowsInView: Bool {
    let follows = anchors.isPinnedToBottom && anchors.anchorID == nil
    return !follows && itemPosition == nil && !keepsBottom && position.value.edge == nil
  }
}

/// The mounted rows of the virtual stack of a thread: the rows near the
/// part in view, in the layout of the stack (``TranscriptRowStack``, card
/// ^kr7cx7b).
///
/// Each element of the `ForEach` is one ``TranscriptRowElement`` with the id
/// of its entry and the row key as its scroll target id, in the order of
/// the transcript. Thus the row identity, the scroll targets, the reports of
/// the rows in view and the reading order are the same as in a stack of all
/// the rows. A row that leaves the window loses the state of its views, so
/// each state that must stay is in the models of the thread.
///
/// The rows in view are state of the window, and not of the stack, so a
/// change of the rows in view does not compute the geometry of the stack
/// again.
struct TranscriptRowWindow: View {
  /// The session model whose transcript the window shows.
  let session: SessionModel

  /// The geometry that the stack lays out.
  let geometry: TranscriptStackGeometry

  /// The status lines of the modelChanged notices.
  let placements: ModelChangePlacements

  /// Whether the rows move in a live motion of the user: a row that the
  /// window makes then waits in the queue of the rows from its start.
  let entersWhileMoving: Bool

  /// Whether the user moves the rows: the elements take no hit test
  /// (``TranscriptRowsHitTest``).
  let rowsMoveLive: Bool

  /// The position in the transcript of the item of a scroll to an item
  /// that did not end, or `nil`.
  let itemPosition: Int?

  /// Whether a scroll to the bottom did not end: the window mounts the
  /// rows at the bottom.
  let keepsBottom: Bool

  /// The heights of the parts of the list under its bars: the window
  /// mounts the rows there too (``TranscriptViewport/shown``).
  let insets: TranscriptScrollInsetsModel

  /// The heights of the layouts of the elements, which each element feeds.
  let elements: TranscriptElementHeights

  /// The lengths of the elements.
  let metrics: TranscriptElementMetrics

  /// The heights of the static rows of the thread.
  let rowHeights: TranscriptStaticRowHeights

  /// The record of the rows in view that the stack reads.
  let viewportRecord: TranscriptViewportRecord

  /// The prefix of the ``BodyEvaluationCounter`` key of the window of the
  /// stack of a session.
  static let counterKeyPrefix = "transcript-stack-window-"

  /// The ``BodyEvaluationCounter`` key of the window of the stack of a
  /// session: one evaluation of the window makes the `ForEach` of its rows
  /// again.
  ///
  /// - Parameter session: The session of the stack.
  /// - Returns: The key.
  static func counterKey(for session: SessionModel) -> String {
    BodyEvaluationKey.make(prefix: counterKeyPrefix, object: session)
  }

  /// The prefix of the ``BodyEvaluationCounter`` key of the reports of the
  /// window of the stack of a session.
  static let reportCounterKeyPrefix = "transcript-stack-report-"

  /// The ``BodyEvaluationCounter`` key of the reports of the window of the
  /// stack of a session: one count for each action that SwiftUI runs to
  /// give the window a new report of the rows in view.
  ///
  /// - Parameter session: The session of the stack.
  /// - Returns: The key.
  static func reportCounterKey(for session: SessionModel) -> String {
    BodyEvaluationKey.make(prefix: reportCounterKeyPrefix, object: session)
  }

  /// The count of the reports that needed a row that the window did not
  /// mount. The body reads it, so only such a report evaluates the body.
  @State private var mountRequests = 0

  /// The positions of the rows that the window mounted at its last body.
  @State private var mounted = TranscriptMountedRows()

  var body: some View {
    #if DEBUG
      let _ = BodyEvaluationCounter.note(Self.counterKey(for: session))
    #endif
    // The body reads the count, so a report that needs a row evaluates it.
    let _ = mountRequests
    let transcript = session.transcript
    let geometry = geometry
    let plan = TranscriptMountPlan(
      geometry: geometry, itemPosition: itemPosition, keepsBottom: keepsBottom, leadsMotion: rowsMoveLive)
    let record = viewportRecord
    let positions = mountedPositions(plan: plan)
    // The window reads the transcript itself, and the geometry comes from
    // the stack, so a shorter transcript can come before its geometry.
    let slots = positions.filter(transcript.indices.contains).map {
      TranscriptRowSlot(position: $0, entry: transcript[$0])
    }
    let entersWhileMoving = entersWhileMoving
    let elements = elements
    let metrics = metrics
    let rowHeights = rowHeights
    // The body reads the insets, so a new height of a bar reads the rows
    // in view again.
    let insets = insets.value
    TranscriptStackLayout(geometry: geometry.rows) {
      ForEach(slots) { slot in
        let lines = placements.lines(at: .after(slot.id))
        let shape = TranscriptElementShape(
          id: slot.id, lineCount: lines.count, isLast: slot.position == transcript.count - 1)
        TranscriptRowElement(slot: slot, isLast: shape.isLast, lines: lines, entersWhileMoving: entersWhileMoving)
          .equatable()
          .modifier(TranscriptRowsHitTest(rowsMoveLive: rowsMoveLive))
          .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            elements.record(
              height: size.height, width: size.width, for: shape, metrics: metrics, source: rowHeights)
          }
          .onDisappear { elements.noteGone(slot.id) }
          .transcriptRowIndex(geometry.index(ofPosition: slot.position))
          .id(slot.entry.rowKey)
      }
    }
    .scrollTargetLayout()
    .onGeometryChange(for: [Int].self) { [insets] proxy in
      // The record keeps each report, with no action of SwiftUI. Only the
      // rows to mount are the value of the change.
      let report = proxy.bounds(of: .scrollView).map {
        TranscriptViewport(bounds: $0, insets: insets, geometry: geometry)
      }
      record.note(report)
      return plan.rowsToMount(report: report, movesDown: record.movesDown, mounted: positions)
    } action: { rowsToMount in
      noteRowsToMount(rowsToMount)
    }
  }

  /// The positions in the transcript of the rows that the window mounts
  /// (``TranscriptMountPlan/positions(report:movesDown:kept:)``), from the
  /// latest report of the rows in view.
  ///
  /// The body records the positions (``mounted``), so a row that the window
  /// mounted stays mounted in a margin of rows
  /// (``TranscriptRowGeometry/keptRowMargin``): a height correction does
  /// not make a real row and its editors again.
  ///
  /// - Parameter plan: The plan of the mounted rows of the body.
  /// - Returns: The positions, in order.
  private func mountedPositions(plan: TranscriptMountPlan) -> [Int] {
    let positions = plan.positions(
      report: viewportRecord.value, movesDown: viewportRecord.movesDown, kept: mounted.positions)
    mounted.positions = positions
    return positions
  }

  /// Evaluates the body when a report of the rows in view needs a row that
  /// the window did not mount: a row in view, or the lead row of a live
  /// motion (``TranscriptMountPlan/leadPosition(report:movesDown:)``).
  ///
  /// The geometry of the window gives each report to the record of the
  /// rows in view (``TranscriptViewportRecord``) with no action of
  /// SwiftUI, and the value of its change is only the rows to mount. Thus
  /// a scroll step that mounts no row, such as a step in which a row leaves
  /// the view, runs no action and evaluates no body. A row that leaves the
  /// view stays mounted until the next body, in the margin of the kept rows
  /// (``TranscriptRowGeometry/keptRowMargin``).
  ///
  /// - Parameter rowsToMount: The positions of the rows that the latest
  ///   report needs and that the window did not mount.
  private func noteRowsToMount(_ rowsToMount: [Int]) {
    #if DEBUG
      BodyEvaluationCounter.note(Self.reportCounterKey(for: session))
    #endif
    guard !rowsToMount.isEmpty else { return }
    mountRequests &+= 1
  }
}

/// The rows in view of the virtual stack of a thread at the last report of
/// its window (``TranscriptRowWindow``), and the direction of their last
/// move.
///
/// The values are not observable: the geometry of the window writes them on
/// each frame of a scroll, off the actions of SwiftUI, and the stack reads
/// them only when the heights change, so that change of the rows in view
/// does not evaluate the stack. The geometry of SwiftUI reads its value off
/// the main actor, so the record holds its values under a lock.
nonisolated final class TranscriptViewportRecord: Sendable {
  /// The values of the record.
  private struct Values {
    /// The rows in view, or `nil` before the first report.
    var value: TranscriptViewport?

    /// Whether the last move of the rows in view went down the
    /// transcript, or `nil` before the first move.
    var movesDown: Bool?
  }

  /// The values, under a lock.
  private let values = Mutex(Values())

  /// The rows in view, or `nil` before the first report.
  var value: TranscriptViewport? {
    values.withLock { $0.value }
  }

  /// Whether the last move of the rows in view went down the transcript,
  /// or `nil` before the first move. The window mounts the lead row of a
  /// live motion in that direction (``TranscriptMountPlan``).
  var movesDown: Bool? {
    values.withLock { $0.movesDown }
  }

  /// Makes a record with no report.
  init() {}

  /// Records a report of the rows in view, and the direction of the move
  /// of the rows in view from the last report.
  ///
  /// - Parameter report: The report, or `nil` when the window is not in a
  ///   scroll view.
  func note(_ report: TranscriptViewport?) {
    values.withLock { values in
      if let old = values.value, let report, let movesDown = report.movesDown(from: old) {
        values.movesDown = movesDown
      }
      values.value = report
    }
  }
}

/// The positions in the transcript of the rows that the virtual stack of a
/// thread mounted at the last body of its window (``TranscriptRowWindow``).
///
/// The value is not observable: the body of the window writes it, and no
/// body reads it to evaluate again.
@MainActor final class TranscriptMountedRows {
  /// The positions, in order.
  var positions: [Int] = []

  /// Makes an empty record.
  init() {}
}
