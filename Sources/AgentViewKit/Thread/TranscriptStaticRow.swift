import EditorCommands
import FoundationModelsACPClient
import SwiftUI

/// The things that keep a row of a thread in its real form while the rows
/// move (``TranscriptStaticRow``).
///
/// A row that the user works with stays real, so that the work does not
/// stop when the list moves: the row that holds the keyboard focus, the row
/// under the mouse, the row that holds the text selection of the thread,
/// and the row of the entry that streams.
struct TranscriptRowHolds: Equatable {
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

  /// Whether one of the holds keeps the row real.
  var keepsRealRow: Bool {
    hasFocus || isHovered || hasSelection || streams
  }
}

/// The form of one row of a thread: real, or static (card ^9ync5h3).
enum TranscriptRowForm {
  /// Tells if a row shows its static form.
  ///
  /// A row is static only while the rows move, while nothing holds it real,
  /// and while the height provider knows its height. A row with no known
  /// height shows its real form, so the change of form never moves it.
  ///
  /// - Parameters:
  ///   - rowsMove: Whether the rows of the thread move
  ///     (``TranscriptRowMotion``).
  ///   - holds: The holds of the row.
  ///   - knowsHeight: Whether the height provider knows the height of the
  ///     row.
  /// - Returns: `true` when the row shows its static form.
  static func isStatic(rowsMove: Bool, holds: TranscriptRowHolds, knowsHeight: Bool) -> Bool {
    rowsMove && !holds.keepsRealRow && knowsHeight
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
  /// The id of the entry of the row.
  let id: TranscriptEntry.ID

  /// Whether the row shows its static form (``TranscriptRowForm``).
  let isStatic: Bool

  /// The heights of the static rows of the thread, or `nil` outside a
  /// thread. They record the size of the real row, and they are the height
  /// provider of the static form.
  let heights: TranscriptStaticRowHeights?

  func body(content: Content) -> some View {
    TranscriptStaticRowFrame(staticHeight: staticHeight) {
      content.environment(\.transcriptRowIsStatic, isStatic)
    }
    .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
      recordRealSize(size)
    }
  }

  /// The height of the static form at a width, or `nil` in the real form.
  private var staticHeight: TranscriptStaticRowFrame.Height? {
    guard isStatic, let heights else { return nil }
    let id = id
    return { width in heights.height(of: id, width: width) }
  }

  /// Records the size of the real row. The size of the static form is the
  /// recorded size, so the modifier records nothing in that form.
  ///
  /// - Parameter size: The new size of the row.
  private func recordRealSize(_ size: CGSize) {
    guard !isStatic else { return }
    heights?.record(size, for: id)
  }
}

/// The frame of one row: the height of the provider at the width of the row
/// in the static form, and the size of the content otherwise.
///
/// The layout is the same type in each form, so a change of form keeps the
/// identity of the row.
struct TranscriptStaticRowFrame: Layout {
  /// The height of the static form of the row at a width, from the height
  /// provider, or `nil` when the provider knows no height at that width.
  typealias Height = @MainActor (CGFloat) -> CGFloat?

  /// The height of the static form, or `nil` in the real form.
  let staticHeight: Height?

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let content = subviews.first?.sizeThatFits(proposal) ?? .zero
    let width = proposal.width ?? content.width
    // SwiftUI lays out its views on the main actor.
    let height = MainActor.assumeIsolated { staticHeight?(width) }
    guard let height else { return content }
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for subview in subviews {
      subview.place(
        at: bounds.origin, anchor: .topLeading,
        proposal: ProposedViewSize(width: bounds.width, height: proposal.height))
    }
  }
}

extension EnvironmentValues {
  /// Whether the row of the view shows its static form
  /// (``TranscriptStaticRow``).
  ///
  /// An EditorKit text area of a row reads it (``StaticEditorSlot``), and
  /// shows its text in SwiftUI `Text` while the value is `true`. Outside a
  /// thread row, it is `false`.
  @Entry var transcriptRowIsStatic = false
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
