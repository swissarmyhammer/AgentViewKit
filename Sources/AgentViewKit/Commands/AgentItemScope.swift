import EditorCommands
import EditorCommandsUI
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
/// that item.
///
/// The item scope is a target of the EditorKit navigation and jump (AVK-7d).
/// `.navVisible()` gives the area of the item to the scope, so the `nav.*`
/// commands of the host move between the items, and a jump label shows on
/// the item. An ``AgentItemFocusTarget`` behind the item takes the focus that
/// a move or a jump puts on the item. When `isJumpTarget` is `false`, for
/// example on a deck card that does not show whole, `.jumpTarget(.hidden)`
/// removes the item from the jump labels. The modifier applies the same
/// modifiers for each value of `isJumpTarget`, so a change of the value keeps
/// the identity and the state of the item.
///
/// With no enclosing agent command scope, the modifier does not change the
/// view.
struct AgentItemScope<Subject: Sendable>: ViewModifier {
  /// The segment of the item, such as `agentMessage:<rowKey>`.
  let segment: FocusSegment

  /// The live object of the item, such as its `TranscriptEntry`.
  let subject: Subject

  /// Tells if jump mode shows a label on the item.
  let isJumpTarget: Bool

  @Environment(\.agentCommandSystem) private var system

  func body(content: Content) -> some View {
    if let system {
      content
        .background(AgentItemFocusTarget())
        .jumpTarget(isJumpTarget ? JumpTargetOverride() : .hidden)
        .commandContextMenu(system)
        .commandScope(segment: segment, subject: subject)
        .navVisible()
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
  ///   - isJumpTarget: `false` to show no jump label on the item, for
  ///     example on a deck card that does not show whole.
  /// - Returns: A view in the scope of the item.
  func agentItemScope(_ segment: FocusSegment, subject: some Sendable, isJumpTarget: Bool = true) -> some View {
    modifier(AgentItemScope(segment: segment, subject: subject, isJumpTarget: isJumpTarget))
  }
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
