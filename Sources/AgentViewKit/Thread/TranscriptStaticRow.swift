import EditorCommands
import EditorSwiftUI
import FoundationModelsACPClient
import SwiftUI
import os

/// The things that keep a row of a thread in its real form while the rows
/// move (``TranscriptStaticRow``).
///
/// A row that was real at rest before the rows started to move stays real
/// for the whole motion: the list does not swap the editors of the rows in
/// view at the start of a flick, and it does not mount them again at its
/// end. Only a row that comes into the list during the motion shows its
/// static form. A row that the user works with also stays real, so that
/// the work does not stop when the list moves: the row that holds the
/// keyboard focus, the row under the mouse, the row that holds the text
/// selection of the thread, and the row of the entry that streams.
///
/// The mouse keeps only a row that does not wait in the
/// ``TranscriptRowMountQueue`` (``keepsRealRow(waitsToMount:)``). At the
/// end of a live motion, the rows take the hit test again, and SwiftUI
/// tells the row under a still mouse that the mouse is on it. That row
/// then keeps its static form at rest, as each other row of the motion
/// does, so a hover mounts no editor. A press of the mouse on the static
/// text of a waiting row makes the row real at once (``StaticEditorSlot``).
///
/// A find hit that marks words in the text of a waiting row
/// (``isSearchTarget``) ends the wait at rest only: the static form shows
/// no find mark in its text, and the editor does. While the rows move,
/// the row stays static.
struct TranscriptRowHolds: Equatable {
  /// Whether the row was shown at rest, in its real form, before the rows
  /// started to move.
  var wasRealAtRest = false

  /// Whether the keyboard focus is in a command scope of the row.
  var hasFocus = false

  /// Whether the mouse is on the row.
  var isHovered = false

  /// Whether a text area of the row holds the selection of the thread.
  var hasSelection = false

  /// Whether the entry of the row streams: it is the last entry, and the
  /// agent runs.
  var streams = false

  /// Whether a find hit marks words in the text of the row
  /// (``isSearchTarget(_:)``).
  var isSearchTarget = false

  /// Tells if a find hit marks words in the text of a row: the hit has
  /// terms. A hit with no terms marks the whole entry with a background,
  /// which the static form shows.
  ///
  /// - Parameter mark: The search mark of the row, or `nil` for a row with
  ///   no hit.
  /// - Returns: `true` when the row has a hit with terms.
  static func isSearchTarget(_ mark: TranscriptSearchMark?) -> Bool {
    mark.map { !$0.marksWholeEntry } ?? false
  }

  /// Tells if the keyboard focus is in the item scope of a row.
  ///
  /// - Parameters:
  ///   - segment: The segment of the item scope of the row
  ///     (``FoundationModelsACPClient/TranscriptEntry/itemScopeSegment``),
  ///     or `nil` for a row with no item scope.
  ///   - focusedPath: The path of the focused command scope of the window,
  ///     or `nil`.
  /// - Returns: `true` when the focused path goes through the item scope.
  static func hasFocus(itemScope segment: FocusSegment?, focusedPath: FocusPath?) -> Bool {
    guard let segment, let focusedPath else { return false }
    return focusedPath.segments.contains(segment)
  }

  /// Tells if one of the holds keeps the row real.
  ///
  /// - Parameter waitsToMount: Whether the row waits for an interaction in the
  ///   ``TranscriptRowMountQueue`` (``TranscriptRowMount/waits``). The
  ///   mouse does not keep a waiting row real.
  /// - Returns: `true` when a hold keeps the row real.
  func keepsRealRow(waitsToMount: Bool) -> Bool {
    wasRealAtRest || hasFocus || (isHovered && !waitsToMount) || hasSelection || streams
  }
}

/// The form of one row of a thread: real, or static (card ^9ync5h3).
enum TranscriptRowForm {
  /// Tells if a row shows its static form.
  ///
  /// A row is static only while the rows move or while the row waits for
  /// an interaction in the ``TranscriptRowMountQueue`` (card ^7625j1b),
  /// while nothing holds it real (a row that was real at rest before the
  /// motion holds itself, and the mouse does not hold a waiting row:
  /// ``TranscriptRowHolds/keepsRealRow(waitsToMount:)``), and while the
  /// height provider knows its height. A row with no known height shows
  /// its real form, so the change of form never moves it. At rest, a find
  /// hit that marks words in the text of the row ends its wait
  /// (``TranscriptRowHolds/isSearchTarget``).
  ///
  /// - Parameters:
  ///   - rowsMove: Whether the rows of the thread move
  ///     (``TranscriptRowMotion``).
  ///   - waitsToMount: Whether the row waits for an interaction in the
  ///     queue (``TranscriptRowMount/waits``).
  ///   - holds: The holds of the row.
  ///   - knowsHeight: Whether the height provider knows the height of the
  ///     row.
  /// - Returns: `true` when the row shows its static form.
  static func isStatic(rowsMove: Bool, waitsToMount: Bool, holds: TranscriptRowHolds, knowsHeight: Bool) -> Bool {
    let waitsAtRest = waitsToMount && !holds.isSearchTarget
    return (rowsMove || waitsAtRest) && !holds.keepsRealRow(waitsToMount: waitsToMount) && knowsHeight
  }

  /// Tells the form of the EditorKit text areas of a row
  /// (``StaticEditorSlot``).
  ///
  /// A row that is not static (``isStatic(rowsMove:waitsToMount:holds:knowsHeight:)``)
  /// shows each editor. A static row shows each still view while the rows
  /// move. A static row at rest waits in the ``TranscriptRowMountQueue``:
  /// each of its slots shows its still view until an interaction.
  ///
  /// - Parameters:
  ///   - rowsMove: Whether the rows of the thread move
  ///     (``TranscriptRowMotion``).
  ///   - waitsToMount: Whether the row waits for an interaction in the
  ///     queue (``TranscriptRowMount/waits``).
  ///   - holds: The holds of the row.
  ///   - knowsHeight: Whether the height provider knows the height of the
  ///     row.
  /// - Returns: The form of the slots of the row.
  static func slotForm(
    rowsMove: Bool, waitsToMount: Bool, holds: TranscriptRowHolds, knowsHeight: Bool
  ) -> TranscriptSlotForm {
    guard isStatic(rowsMove: rowsMove, waitsToMount: waitsToMount, holds: holds, knowsHeight: knowsHeight) else {
      return .real
    }
    return rowsMove ? .still : .waiting
  }
}

/// The form of the EditorKit text areas of one row of a thread
/// (``StaticEditorSlot``, card ^7625j1b).
enum TranscriptSlotForm: Equatable {
  /// The row shows its real form: each slot shows its editor.
  case real

  /// The rows move, and the row shows its static form: each slot shows its
  /// still view.
  case still

  /// The row waits at rest in the ``TranscriptRowMountQueue`` for an
  /// interaction, and keeps its static form: each slot shows its still
  /// view, and a press on it makes the row real.
  case waiting

  /// Whether a slot in this form shows its still view.
  var showsStill: Bool {
    self != .real
  }
}

/// Gives one row of a thread its static form or its real form (card
/// ^9ync5h3, spike ^fa3j934).
///
/// The cost of a row in a moving list is the EditorKit editor that mounts
/// in it. In the static form, each EditorKit text area of the row shows its
/// text in SwiftUI `Text` (``StaticEditorSlot``): the same text, with the
/// same font and the same rows. Each other view of the row stays: the same
/// header, padding, tiles and chrome, and the same command scopes. Thus the
/// row looks the same, and a change of form keeps the state of each view of
/// the row. A code block, a terminal and a diff lose only their syntax
/// colors and their ANSI colors.
///
/// The static form has the height of the provider
/// (``TranscriptRowHeightProvider``) at the width of the row. When the
/// provider knows no height at that width, such as after a resize while the
/// rows move, the row takes the height of its content. In the real form,
/// the modifier records the size of the row in
/// ``TranscriptMeasuredRowHeights``.
///
/// A static row whose height cache has the layout tree of the row, its
/// exact height, a picture of each text part and a chrome line for each
/// chrome view (``TranscriptFlatRowPlan``) shows its flat form: one
/// ``TranscriptFlatRow`` of the pictures of the row in place of each view
/// of the real row, so the row builds and measures no view of its real row
/// while it is static. A row with a footer of its message, with a find hit,
/// or with a status of its MCP server keeps the views of its real row in
/// its static form: the flat form draws none of these. A row that holds the
/// views of its real row already, such as a row that the list made at rest
/// past the edge of the view, keeps them in its static form too
/// (``TranscriptRowRealViews``), so a change of form builds no new view.
struct TranscriptStaticRow: ViewModifier {
  /// The start of the ``BodyEvaluationCounter`` key of each row.
  static let counterKeyPrefix = "static-row-"

  /// The entry of the row.
  let entry: TranscriptEntry

  /// The form of the editor slots of the row
  /// (``TranscriptRowForm/slotForm(rowsMove:waitsToMount:holds:knowsHeight:)``).
  /// Each form that is not ``TranscriptSlotForm/real`` is the static form
  /// of the row.
  let slotForm: TranscriptSlotForm

  /// The heights of the static rows of the thread, or `nil` outside a
  /// thread. They record the size of the real row, and they are the height
  /// provider of the static form.
  let heights: TranscriptStaticRowHeights?

  /// Whether the row built the views of its real row. The modifier notes
  /// each body that shows them, and a row that built them never shows its
  /// flat form.
  let realViews: TranscriptRowRealViews

  /// The action when the modifier records the first size of the row: the
  /// thread then knows the height of a row that it did not know before
  /// (card ^7625j1b).
  var onFirstHeight: @MainActor () -> Void = {}

  /// The ``BodyEvaluationCounter`` key of the row of `id`.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `static-row-<id>`.
  static func counterKey(for id: String) -> String {
    BodyEvaluationKey.make(prefix: counterKeyPrefix, id: id)
  }

  @Environment(\.messageFooter) private var footer
  @Environment(\.transcriptSearch) private var search
  @Environment(\.toolCallConnectionState) private var connectionState
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.displayScale) private var displayScale

  func body(content: Content) -> some View {
    #if DEBUG
      BodyEvaluationCounter.note(Self.counterKey(for: id.rowKey))
    #endif
    let flatPlan = realViews.areBuilt ? nil : flatPlan
    if flatPlan == nil {
      realViews.areBuilt = true
    }
    return TranscriptStaticRowFrame(id: id, staticHeight: staticHeight) {
      if let flatPlan, let heights {
        TranscriptFlatRow(rowKey: id.rowKey, plan: flatPlan, chrome: heights.chrome, message: MessageEntry(entry))
          .environment(\.transcriptSlotForm, slotForm)
      } else {
        content
          .environment(\.transcriptSlotForm, slotForm)
          .environment(\.transcriptRowPictures, heights.map { TranscriptRowPictures(heights: $0, rowKey: id.rowKey) })
      }
    }
    .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
      recordRealSize(size)
    }
  }

  /// The id of the entry of the row.
  private var id: TranscriptEntry.ID {
    entry.id
  }

  /// Whether the row shows its static form: the frame of the row has the
  /// height of the provider.
  private var isStatic: Bool {
    slotForm != .real
  }

  /// The plan of the flat form of the row, or `nil` for a real row and for
  /// a static row that keeps the views of its real row.
  ///
  /// Only a static row reads the find hits and the pictures, so a new
  /// search or a new picture evaluates no real row.
  private var flatPlan: TranscriptFlatRowPlan? {
    guard isStatic, let heights, showsOnlyFlatChrome else { return nil }
    return heights.flatPlan(of: id, appearance: TranscriptTextAppearance(colorScheme: colorScheme, scale: displayScale))
  }

  /// Whether the real row shows no view that the flat form does not draw:
  /// no custom footer of a message (the flat form draws the footer of the
  /// message actions, card ^grwk69d), no find hit, and no status of the MCP
  /// server of a tool call.
  private var showsOnlyFlatChrome: Bool {
    guard search?.mark(forRowKey: id.rowKey) == nil else { return false }
    switch entry {
    case .userMessage, .agentMessage: return footer?.kind != .custom
    case .toolCall(let call): return connectionState?(call) == nil
    case .thought, .terminal, .plan, .unknown, .error, .compaction, .sessionMessage: return true
    }
  }

  /// The height of the static form at a width, or `nil` in the real form.
  private var staticHeight: TranscriptStaticRowFrame.Height? {
    guard isStatic, let heights else { return nil }
    let id = id
    return { width in heights.height(of: id, width: width) }
  }

  /// Records the size of the real row. The size of the static form is the
  /// recorded size, so the modifier records nothing in that form. The first
  /// record of a row whose height the thread did not know calls
  /// ``onFirstHeight``.
  ///
  /// - Parameter size: The new size of the row.
  private func recordRealSize(_ size: CGSize) {
    guard !isStatic, let heights else { return }
    let isFirstHeight = !heights.knowsHeight(of: id)
    heights.record(size, for: id)
    if isFirstHeight {
      onFirstHeight()
    }
  }
}

/// Whether one row of a thread built the views of its real row (card
/// ^9ync5h3).
///
/// ``TranscriptStaticRow`` notes it in each body that shows the views of the
/// real row: in the real form, and in a static form that is not the flat
/// form, such as the static form of a row with no picture yet. A row that
/// built them keeps them in each later static form, and never shows its
/// flat form: a change to the flat form would drop views that are built,
/// and build a new view in the step that shows the row. A row that the
/// list made at rest past the edge of the view, which is real, thus keeps
/// its views when a flick brings it into view. The value is not observable,
/// so a note evaluates no body.
final class TranscriptRowRealViews {
  /// Whether the row built the views of its real row.
  var areBuilt = false
}

/// The frame of one row: the height of the provider at the width of the row
/// in the static form, and the size of the content otherwise.
///
/// The layout is the same type in each form, so a change of form keeps the
/// identity of the row.
struct TranscriptStaticRowFrame: Layout {
  /// The start of the ``BodyEvaluationCounter`` key of the layouts of each
  /// row.
  static let counterKeyPrefix = "static-row-frame-"

  /// The log of a frame that has no content.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "TranscriptStaticRowFrame")

  /// The id of the entry of the row.
  let id: TranscriptEntry.ID

  /// The height of the static form of the row at a width, from the height
  /// provider, or `nil` when the provider knows no height at that width.
  typealias Height = @MainActor (CGFloat) -> CGFloat?

  /// The height of the static form, or `nil` in the real form.
  let staticHeight: Height?

  /// The ``BodyEvaluationCounter`` key of the size computations of the row
  /// of `id`.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `static-row-frame-<id>`.
  @MainActor static func counterKey(for id: String) -> String {
    BodyEvaluationKey.make(prefix: counterKeyPrefix, id: id)
  }

  /// The size of the row.
  ///
  /// A static row with a proposed width and a known height at that width
  /// has that size, and the frame does not measure the content: each size
  /// query of the content lays out the text of the row again, and the lazy
  /// stack of a thread asks each row for its size many times in each frame
  /// of a flick. The frame measures the content only for a real row, for a
  /// proposal with no width, or when the provider knows no height at the
  /// width.
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    #if DEBUG
      MainActor.assumeIsolated { BodyEvaluationCounter.note(Self.counterKey(for: id.rowKey)) }
    #endif
    guard let first = subviews.first else {
      assertionFailure("static row frame has no content")
      Self.logger.error("static row frame has no content; the zero size stands")
      return .zero
    }
    if let width = proposal.width, let height = height(at: width) {
      return CGSize(width: width, height: height)
    }
    let content = first.sizeThatFits(proposal)
    let width = proposal.width ?? content.width
    guard let height = height(at: width) else { return content }
    return CGSize(width: width, height: height)
  }

  /// The height of the static form at `width`, or `nil` in the real form or
  /// when the provider knows no height at that width.
  ///
  /// - Parameter width: The width of the row.
  /// - Returns: The height, in points.
  private func height(at width: CGFloat) -> CGFloat? {
    // SwiftUI lays out its views on the main actor.
    MainActor.assumeIsolated { staticHeight?(width) }
  }

  /// Places the content at the top leading corner of the row.
  ///
  /// A static row with a known height at the width of the row proposes
  /// that exact size to its content: the size that ``sizeThatFits(proposal:subviews:cache:)``
  /// gave. Thus the content gets one proposal on each frame, and SwiftUI
  /// keeps the measure of each text of the content. Each other row
  /// proposes the width of the row and the height of the proposal.
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let height = height(at: bounds.width) ?? proposal.height
    for subview in subviews {
      subview.place(
        at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: height))
    }
  }

  /// No horizontal guide of its own: the row has the default guides.
  ///
  /// The default guides of `Layout` place the content and ask it for its
  /// guides. The scroll view of a thread asks for the guides of the rows
  /// (`.defaultScrollAnchor(.bottom, for: .alignment)`), so that query
  /// would lay out the content of each row again.
  func explicitAlignment(
    of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    nil
  }

  /// No vertical guide of its own: the row has the default guides, for
  /// the reason of the horizontal guide.
  func explicitAlignment(
    of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    nil
  }
}

extension EnvironmentValues {
  /// The form of the EditorKit text areas of the row of the view
  /// (``TranscriptStaticRow``).
  ///
  /// An EditorKit text area of a row reads it (``StaticEditorSlot``), and
  /// shows its text in SwiftUI `Text` in place of its editor while the form
  /// tells it to (``TranscriptSlotForm/showsStill``). Outside a
  /// thread row, it is ``TranscriptSlotForm/real``.
  @Entry var transcriptSlotForm = TranscriptSlotForm.real

  /// The wait of the row of the view in the ``TranscriptRowMountQueue``, or
  /// `nil` outside a thread row.
  ///
  /// Each EditorKit text area of the row ends the wait of the row when the
  /// user interacts with its still view (``StaticEditorSlot``).
  /// ``TranscriptRowElement`` sets it for its row.
  @Entry var transcriptRowMount: TranscriptRowMount? = nil

  /// The pictures of the static text of the row of the view, or `nil`
  /// outside a thread row (card ^9ync5h3).
  ///
  /// A Markdown text area of the row reads it (``StaticEditorSlot``), and
  /// shows the picture of its text in its static form when the cache of the
  /// thread has it. ``TranscriptStaticRow`` sets it for its row.
  @Entry var transcriptRowPictures: TranscriptRowPictures? = nil
}

/// The pictures of the static text of one row of a thread, from the height
/// cache of the thread (card ^9ync5h3).
nonisolated struct TranscriptRowPictures: Equatable, Sendable {
  /// The heights of the static rows of the thread.
  let heights: TranscriptStaticRowHeights

  /// The row key of the entry of the row.
  let rowKey: String

  /// The picture of a text part of the row.
  ///
  /// - Parameters:
  ///   - part: The text part of a text area of the row.
  ///   - appearance: The appearance of the text area.
  /// - Returns: The picture, or `nil` when the cache has no picture of the
  ///   part in the appearance.
  @MainActor func picture(of part: TranscriptTextPart, appearance: TranscriptTextAppearance) -> EditorStaticRendering? {
    heights.picture(of: part, inRow: rowKey, appearance: appearance)
  }

  /// Tells if two values give the pictures of the same row.
  ///
  /// - Parameters:
  ///   - lhs: A value.
  ///   - rhs: A value.
  /// - Returns: `true` when both read the same heights for the same row.
  static func == (lhs: TranscriptRowPictures, rhs: TranscriptRowPictures) -> Bool {
    lhs.heights === rhs.heights && lhs.rowKey == rhs.rowKey
  }
}

extension TranscriptEntry {
  /// The segment of the item scope of the row of the entry, or `nil` for an
  /// entry whose row has no item scope.
  ///
  /// A message and a tool call each have an item scope
  /// (``TranscriptMessageView``, ``ToolCallView``). The row reads the
  /// focused command path, and holds its real form while the path has this
  /// segment (``TranscriptRowHolds/hasFocus``).
  var itemScopeSegment: FocusSegment? {
    switch self {
    case .userMessage, .agentMessage: AgentScopeKind.message(rowKey: rowKey)
    case .toolCall(let call): AgentScopeKind.toolCall(call.toolCallId.rawValue)
    case .thought, .terminal, .plan, .unknown, .error, .compaction, .sessionMessage: nil
    }
  }
}
