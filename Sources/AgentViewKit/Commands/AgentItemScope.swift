import EditorCommands
import EditorCommandsUI
import EditorStyle
import FoundationModelsACPClient
import SwiftUI

/// The focus scope of one item of a thread: a message row or a permission
/// request card (AVK-1), or a tool call card (AVK-7c).
///
/// The modifier adds the segment of the item to the path of the enclosing
/// ``AgentCommandScope``, gives the live object of the item as the subject of
/// that segment, and attaches the EditorKit context menu of that path. The
/// context menu shows the agent commands whose
/// ``AgentCommandVerb/itemKind`` is the kind of the item, and the commands
/// that a host registers for the item. A command of the context menu runs at
/// the path of the item, and reads the item with `@FromTarget`, so it acts on
/// that item. A command that is not available at the item does not show in
/// the context menu (``ContextMenuUnavailablePolicy/agentItem``).
///
/// The item scope is a target of the EditorKit navigation and jump (AVK-7d),
/// as each EditorKit command scope is. The scope has the area of the item, so
/// the `nav.*` commands of the host move between the items, and a jump label
/// shows on the item. The item has no focusable view of its own, so the
/// EditorKit beacon of the scope takes the focus that a move or a jump puts
/// on the item, and draws the system focus ring over the item.
/// `.scopeFocusRing(cornerRadius:)` gives the ring the corners of the surface
/// of the item (``SurfaceCorners``): by default the corners of a card
/// of the kit (``SurfaceCorners/card``). A `.focusEffectDisabled()` above
/// the item turns the ring off. When `isTargetable` is
/// `false`, for example on a deck card that does not show whole,
/// `.targetable(false)` removes the item from the jump labels and from the
/// navigation snapshot, so no jump and no move lands on it. The modifier
/// applies the same modifiers for each value of `isTargetable`, so a change
/// of the value keeps the identity and the state of the item.
///
/// With no enclosing agent command scope, the modifier does not change the
/// view.
struct AgentItemScope<Subject: Sendable>: ViewModifier {
  /// The segment of the item, such as `agentMessage:<rowKey>`.
  let segment: FocusSegment

  /// The live object of the item, such as its `TranscriptEntry`.
  let subject: Subject

  /// Tells if a jump or a `nav.*` move can land on the item.
  let isTargetable: Bool

  /// The corners of the focus ring that the beacon of the scope draws.
  let focusRingCorners: SurfaceCorners

  @Environment(\.agentCommandSystem) private var system
  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    if let system {
      content
        .commandContextMenu(system, unavailable: .agentItem)
        .commandScope(segment: segment, subject: subject)
        .targetable(isTargetable)
        .scopeFocusRing(cornerRadius: focusRingCorners.radius(in: editorStyle))
    } else {
      content
    }
  }
}

extension View {
  /// Puts this view in the focus scope of one item of a thread, with the
  /// context menu of that scope.
  ///
  /// - Parameters:
  ///   - segment: The segment of the item.
  ///   - subject: The live object of the item. A command reads it with
  ///     `@FromTarget(kind: segment.kind)`.
  ///   - isTargetable: `false` to keep each jump and each `nav.*` move off
  ///     the item, for example on a deck card that does not show whole.
  ///   - focusRingCorners: The corners of the surface of the item, which the
  ///     focus ring of the scope follows. The default is the corners of a
  ///     card.
  /// - Returns: A view in the scope of the item.
  func agentItemScope(
    _ segment: FocusSegment, subject: some Sendable, isTargetable: Bool = true,
    focusRingCorners: SurfaceCorners = .card
  ) -> some View {
    modifier(
      AgentItemScope(
        segment: segment, subject: subject, isTargetable: isTargetable, focusRingCorners: focusRingCorners))
  }
}

extension ContextMenuUnavailablePolicy {
  /// The policy of the context menu of an item of a thread
  /// (``AgentItemScope``): a command that is not available at the item does
  /// not show in the context menu (AVK-9). The main menu still shows that
  /// command, disabled.
  static let agentItem: ContextMenuUnavailablePolicy = .hide
}

extension AgentCommandTarget {
  /// The Markdown of the message that a ``AgentCommandVerb/copyMessage``
  /// payload names: the content form of `ThreadExporter.markdown(for:)`, as
  /// the Copy button of ``MessageActions`` writes it.
  ///
  /// - Parameters:
  ///   - payload: The payload of the dispatch, or `nil`.
  ///   - session: The session model of the scope.
  /// - Returns: The Markdown, or `nil` when the payload names no message
  ///   entry of the transcript.
  func messageMarkdown(payload: CommandPayload?, in session: SessionModel) -> String? {
    let transcript = session.transcript
    guard let key = AgentCommandPayload.string(AgentCommandPayload.messageKey, in: payload),
      let position = transcript.position(ofRowKey: key)
    else { return nil }
    switch transcript[position] {
    case .userMessage(let entry): return ThreadExporter.markdown(for: entry.content)
    case .agentMessage(let entry): return ThreadExporter.markdown(for: entry.content)
    default: return nil
    }
  }
}

extension EnvironmentValues {
  /// The command system of the nearest ``AgentCommandScope``, or `nil`.
  ///
  /// This is the ambient system, or the private system of the scope when no
  /// ancestor installs one. ``AgentItemScope`` builds its context menu from
  /// it.
  @Entry var agentCommandSystem: CommandSystem? = nil
}
