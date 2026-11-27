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
/// then waits for its turns in the queue, as each other row of the motion
/// does, so it does not make each of its editors real in that frame. A
/// press of the mouse on the static text of a waiting row makes the row
/// real at once (``StaticEditorSlot``).
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
  /// - Parameter waitsToMount: Whether the row waits for its turn in the
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
  /// its turn in the ``TranscriptRowMountQueue`` (card ^7625j1b), while
  /// nothing holds it real (a row that was real at rest before the motion
  /// holds itself, and the mouse does not hold a waiting row:
  /// ``TranscriptRowHolds/keepsRealRow(waitsToMount:)``), and while the
  /// height provider knows its height. A row
  /// with no known height shows its real form, so the change of form never
  /// moves it.
  ///
  /// - Parameters:
  ///   - rowsMove: Whether the rows of the thread move
  ///     (``TranscriptRowMotion``).
  ///   - waitsToMount: Whether the row waits for its turn in the queue
  ///     (``TranscriptRowMount/waits``).
  ///   - holds: The holds of the row.
  ///   - knowsHeight: Whether the height provider knows the height of the
  ///     row.
  /// - Returns: `true` when the row shows its static form.
  static func isStatic(rowsMove: Bool, waitsToMount: Bool, holds: TranscriptRowHolds, knowsHeight: Bool) -> Bool {
    (rowsMove || waitsToMount) && !holds.keepsRealRow(waitsToMount: waitsToMount) && knowsHeight
  }

  /// Tells the form of the EditorKit text areas of a row
  /// (``StaticEditorSlot``).
  ///
  /// A row that is not static (``isStatic(rowsMove:waitsToMount:holds:knowsHeight:)``)
  /// shows each editor. A static row shows each still view while the rows
  /// move. A static row at rest waits in the ``TranscriptRowMountQueue``:
  /// each of its slots shows its editor after its own turn.
  ///
  /// - Parameters:
  ///   - rowsMove: Whether the rows of the thread move
  ///     (``TranscriptRowMotion``).
  ///   - waitsToMount: Whether the row waits for its turn in the queue
  ///     (``TranscriptRowMount/waits``).
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
    return rowsMove ? .still : .inTurn
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

  /// The row waits at rest in the ``TranscriptRowMountQueue``, and keeps
  /// the frame of its static form: each slot shows its still view until
  /// its own turn (``TranscriptSlotMount``), and its editor after.
  case inTurn

  /// Tells if a slot in this form shows its still view.
  ///
  /// The slot reads whether it waits only in ``inTurn``, so the turn of a
  /// slot evaluates no slot in a different form.
  ///
  /// - Parameter slotWaits: Whether the slot waits for its turn
  ///   (``TranscriptSlotMount/waits``).
  /// - Returns: `true` when the slot shows its still view.
  func showsStill(slotWaits: @autoclosure () -> Bool) -> Bool {
    switch self {
    case .real: false
    case .still: true
    case .inTurn: slotWaits()
    }
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
struct TranscriptStaticRow: ViewModifier {
  /// The start of the ``BodyEvaluationCounter`` key of each row.
  static let counterKeyPrefix = "static-row-"

  /// The id of the entry of the row.
  let id: TranscriptEntry.ID

  /// The form of the editor slots of the row
  /// (``TranscriptRowForm/slotForm(rowsMove:waitsToMount:holds:knowsHeight:)``).
  /// Each form that is not ``TranscriptSlotForm/real`` is the static form
  /// of the row, also while some slots of a row that takes turns are real.
  let slotForm: TranscriptSlotForm

  /// The heights of the static rows of the thread, or `nil` outside a
  /// thread. They record the size of the real row, and they are the height
  /// provider of the static form.
  let heights: TranscriptStaticRowHeights?

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

  func body(content: Content) -> some View {
    #if DEBUG
      BodyEvaluationCounter.note(Self.counterKey(for: id.rowKey))
    #endif
    return TranscriptStaticRowFrame(id: id, staticHeight: staticHeight) {
      content
        .environment(\.transcriptSlotForm, slotForm)
        .environment(\.transcriptRowPictures, heights.map { TranscriptRowPictures(heights: $0, rowKey: id.rowKey) })
    }
    .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
      recordRealSize(size)
    }
  }

  /// Whether the row shows its static form: the frame of the row has the
  /// height of the provider.
  private var isStatic: Bool {
    slotForm != .real
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

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for subview in subviews {
      subview.place(
        at: bounds.origin, anchor: .topLeading,
        proposal: ProposedViewSize(width: bounds.width, height: proposal.height))
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
  /// tells it to (``TranscriptSlotForm/showsStill(slotWaits:)``). Outside a
  /// thread row, it is ``TranscriptSlotForm/real``.
  @Entry var transcriptSlotForm = TranscriptSlotForm.real

  /// The turn of the row of the view in the ``TranscriptRowMountQueue``, or
  /// `nil` outside a thread row.
  ///
  /// Each EditorKit text area of the row adds its own turn to it
  /// (``StaticEditorSlot``). ``TranscriptRowElement`` sets it for its row.
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

  /// The picture of a Markdown text of the row.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown text of a text area of the row.
  ///   - appearance: The appearance of the text area.
  /// - Returns: The picture, or `nil` when the cache has no picture of the
  ///   text in the appearance.
  @MainActor func picture(of markdown: String, appearance: TranscriptTextAppearance) -> EditorStaticRendering? {
    heights.picture(of: markdown, inRow: rowKey, appearance: appearance)
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
