import EditorCommands
import SwiftUI

/// The kinds of the focus segments of the agent command scopes.
///
/// The kind text is the contract between the kits, so a kit that names a
/// scope of AgentViewKit links only this library. The kind of the scope of a
/// tool call is here: each tool call card of an agent thread adds the
/// segment `agentToolCall:<toolCallId>`, and another kit, such as
/// SnapshotViewKit for "Roll Back to Before This", registers its commands
/// for that kind and reads the tool call id from the segment.
///
/// AgentViewKit adds the kinds of its other scopes, the thread, the message,
/// the permission request, the attachment and the bar control, in an
/// extension of this type, beside their subjects.
///
/// ```swift
/// requires: .enclosing(AgentScopeKind.toolCall)
/// ```
public nonisolated enum AgentScopeKind {
  /// The kind of the scope of a tool call card.
  public static let toolCall = "agentToolCall"

  /// The segment of the scope of a tool call card.
  ///
  /// The id is the ACP `toolCallId` of the call, and not the row key of its
  /// transcript entry, so that another kit can name the same tool call. For
  /// example, a checkpoint of SnapshotViewKit names its tool call by that id.
  ///
  /// - Parameter id: The ACP `toolCallId` text of the tool call.
  /// - Returns: The segment `agentToolCall:<toolCallId>`.
  public static func toolCall(_ id: String) -> FocusSegment {
    FocusSegment(kind: toolCall, id: id)
  }
}

#Preview("The segment of a tool call scope") {
  Text(verbatim: AgentScopeKind.toolCall(StylePreviewFixtures.toolCallID).description)
    .padding()
}
