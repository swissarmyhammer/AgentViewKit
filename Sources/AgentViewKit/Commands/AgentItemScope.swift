import EditorCommands
import EditorCommandsUI
import FoundationModelsACPClient
import SwiftUI

/// The focus scope of one item of a thread: a message row or a permission
/// request card (AVK-1).
///
/// The modifier adds the segment of the item to the path of the enclosing
/// ``AgentCommandScope``, and attaches the EditorKit context menu of that
/// path. The context menu shows the agent commands whose
/// ``AgentCommandVerb/itemKind`` is the kind of the item, and the commands
/// that a host registers for the item. A command of the context menu runs at
/// the path of the item, so it acts on that item.
///
/// With no enclosing agent command scope, the modifier does not change the
/// view.
struct AgentItemScope: ViewModifier {
  /// The segment of the item, such as `agentMessage:<rowKey>`.
  let segment: FocusSegment

  @Environment(\.agentCommandSystem) private var system

  func body(content: Content) -> some View {
    if let system {
      content
        .commandContextMenu(system)
        .commandScope(segment: segment)
    } else {
      content
    }
  }
}

extension View {
  /// Puts this view in the focus scope of one item of a thread, with the
  /// context menu of that scope.
  ///
  /// - Parameter segment: The segment of the item.
  /// - Returns: A view in the scope of the item.
  func agentItemScope(_ segment: FocusSegment) -> some View {
    modifier(AgentItemScope(segment: segment))
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
