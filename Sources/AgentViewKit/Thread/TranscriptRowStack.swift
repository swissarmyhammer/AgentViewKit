import EditorStyle
import FoundationModelsACPClient
import SwiftUI

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

/// The rows in view of the virtual stack of a thread, and the height of the
/// part in view (``TranscriptRowStack``).
///
/// The stack reads the value from its geometry on each frame of a scroll,
/// but the value changes only when the first or the last row in view
/// changes, or when the height of the part in view changes. Thus a scroll
/// that keeps the same rows in view evaluates no body.
nonisolated struct TranscriptViewport: Equatable, Sendable {
  /// The positions in the transcript of the rows in view.
  let visible: Range<Int>

  /// The height of the part in view.
  let height: CGFloat

  /// Reads the value from the part in view of the stack.
  ///
  /// - Parameters:
  ///   - bounds: The bounds of the scroll view, in the coordinates of the
  ///     stack.
  ///   - geometry: The geometry of the shown rows.
  init(bounds: CGRect, geometry: TranscriptStackGeometry) {
    let rows = geometry.rows.visibleRows(offset: bounds.minY, viewportHeight: bounds.height)
    visible = (rows.lowerBound + geometry.firstPosition)..<(rows.upperBound + geometry.firstPosition)
    height = bounds.height
  }
}

/// The latest scroll offset of the list of a thread, which the virtual stack
/// reads when it keeps the rows in view at their place
/// (``TranscriptRowStack``).
///
/// The value is not observable: the list writes it on each frame of a
/// scroll, and no body reads it.
@MainActor final class TranscriptScrollOffset {
  /// The vertical content offset of the list, in points.
  var y: CGFloat = .zero

  /// Makes an offset of zero.
  init() {}
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
/// (``TranscriptRowGeometry``), and it mounts only the rows in view, a
/// margin of the rows that it mounted before, and the rows at the end of a
/// scroll of the list that did not end
/// (``TranscriptRowGeometry/mountedRows(visible:viewportHeight:itemRow:keepsBottom:kept:)``).
/// The height of each row comes from ``TranscriptElementHeights``.
///
/// The stack computes the geometry, and its window (``TranscriptRowWindow``)
/// mounts the rows. The rows in view are state of the window only, so a
/// change of the rows in view evaluates only the body of the window, and
/// the stack does not read the height of each row again. The rows in view
/// change only when the first or the last row in view changes
/// (``TranscriptViewport``), so a scroll step that keeps the same rows in
/// view evaluates no body.
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
      keepsBottom: keepsBottom, elements: elements, metrics: metrics, rowHeights: rowHeights,
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

  /// The heights of the layouts of the elements, which each element feeds.
  let elements: TranscriptElementHeights

  /// The lengths of the elements.
  let metrics: TranscriptElementMetrics

  /// The heights of the static rows of the thread.
  let rowHeights: TranscriptStaticRowHeights

  /// The record of the rows in view that the stack reads.
  let viewportRecord: TranscriptViewportRecord

  /// The height of the part in view before the first report, in points.
  static let fallbackViewportHeight: CGFloat = 1_000

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

  /// The rows in view at the last report, or `nil` before the first one.
  @State private var viewport: TranscriptViewport?

  /// The positions of the rows that the window mounted at its last body.
  @State private var mounted = TranscriptMountedRows()

  var body: some View {
    #if DEBUG
      let _ = BodyEvaluationCounter.note(Self.counterKey(for: session))
    #endif
    let transcript = session.transcript
    let geometry = geometry
    // The body reads the state, so a report that needs a row evaluates it.
    // The record holds the same report or a later one.
    let lastMountReport = viewport
    let report = viewportRecord.value ?? lastMountReport
    // The window reads the transcript itself, and the geometry comes from
    // the stack, so a shorter transcript can come before its geometry.
    let slots = mountedPositions(report: report).filter(transcript.indices.contains).map {
      TranscriptRowSlot(position: $0, entry: transcript[$0])
    }
    let entersWhileMoving = entersWhileMoving
    let elements = elements
    let metrics = metrics
    let rowHeights = rowHeights
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
    .onGeometryChange(for: TranscriptViewport?.self) { proxy in
      proxy.bounds(of: .scrollView).map { TranscriptViewport(bounds: $0, geometry: geometry) }
    } action: { new in
      noteReport(new)
    }
  }

  /// Records a report of the rows in view, and evaluates the body only when
  /// the report needs a row that the window did not mount.
  ///
  /// A row that leaves the view stays mounted until the next body, in the
  /// margin of the kept rows
  /// (``TranscriptRowGeometry/keptRowMargin``). Thus a flick evaluates the
  /// body one time for each row that comes into view, and not again for
  /// each row that leaves it.
  ///
  /// - Parameter report: The new report, or `nil` when the window is not
  ///   in a scroll view.
  private func noteReport(_ report: TranscriptViewport?) {
    viewportRecord.value = report
    let needed = Set(rows(for: report, kept: []))
    guard !needed.isSubset(of: mounted.positions) else { return }
    viewport = report
  }

  /// The positions in the transcript of the rows that the window mounts.
  ///
  /// The body records the positions (``mounted``). A row that the window
  /// mounted stays mounted in a margin of rows
  /// (``TranscriptRowGeometry/keptRowMargin``), so a height correction does
  /// not make a real row and its editors again, and a row that leaves the
  /// view in a flick does not evaluate the body (``noteReport(_:)``).
  ///
  /// - Parameter report: The latest report of the rows in view, or `nil`
  ///   before the first one.
  /// - Returns: The positions, in order.
  private func mountedPositions(report: TranscriptViewport?) -> [Int] {
    let positions = rows(for: report, kept: mounted.positions)
    mounted.positions = positions
    return positions
  }

  /// The positions in the transcript of the rows that the window mounts for
  /// a report of the rows in view
  /// (``TranscriptRowGeometry/mountedRows(visible:viewportHeight:itemRow:keepsBottom:kept:)``).
  ///
  /// - Parameters:
  ///   - report: The report of the rows in view, or `nil` before the first
  ///     one.
  ///   - kept: The positions of the rows that the window mounted before.
  /// - Returns: The positions, in order.
  private func rows(for report: TranscriptViewport?, kept: [Int]) -> [Int] {
    let visible = report.map {
      geometry.index(ofPosition: $0.visible.lowerBound)..<geometry.index(ofPosition: $0.visible.upperBound)
    }
    let rows = geometry.rows.mountedRows(
      visible: visible, viewportHeight: report?.height ?? Self.fallbackViewportHeight,
      itemRow: itemPosition.map(geometry.index(ofPosition:)), keepsBottom: keepsBottom,
      kept: kept.map(geometry.index(ofPosition:)))
    return rows.map { $0 + geometry.firstPosition }
  }
}

/// The rows in view of the virtual stack of a thread at the last report of
/// its window (``TranscriptRowWindow``).
///
/// The value is not observable: the window writes it on each change of the
/// rows in view, and the stack reads it only when the heights change, so
/// that change of the rows in view does not evaluate the stack.
@MainActor final class TranscriptViewportRecord {
  /// The rows in view, or `nil` before the first report.
  var value: TranscriptViewport?

  /// Makes a record with no report.
  init() {}
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
