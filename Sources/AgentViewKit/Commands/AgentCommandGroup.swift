import SwiftUI

/// The groups of the agent commands that a host can turn off (D105 (f)).
///
/// Each ``AgentCommandVerb`` is in exactly one group. A scope does not
/// register a verb of a group that is off. Thus the verb does not show in the
/// menus, the context menus or the command palette, and its keys resolve to
/// nothing. A host gives the groups to turn off with
/// ``SwiftUI/View/agentCommandGroups(off:)``.
///
/// | Group | Verbs |
/// | --- | --- |
/// | ``compose`` | Send Message, Focus Composer |
/// | ``control`` | Stop, Approve Request, Reject Request |
/// | ``navigate`` | Next Prompt, Previous Prompt, Next Request, Previous Request, Scroll to Bottom, Expand or Collapse All |
/// | ``clipboard`` | Copy Message, Copy Thread |
///
/// KanbanViewKit and SnapshotViewKit use the same shape. A group with the same
/// job in two kits has the same last word in its ``id``, for example
/// `navigate` and `clipboard`.
public nonisolated enum AgentCommandGroup: String, CaseIterable, Sendable {
  /// The verbs that write and send a prompt.
  case compose

  /// The verbs that stop the agent and answer its requests.
  case control

  /// The verbs that move in the thread and in the requests, and that expand
  /// its items.
  case navigate

  /// The verbs that copy text.
  case clipboard

  /// The id of the group, `agent.<group>`. It has the prefix of the command
  /// ids of the kit.
  public var id: String {
    AgentCommandVerb.idPrefix + rawValue
  }

  /// The verbs of the group, in the order of the verbs.
  public var verbs: [AgentCommandVerb] {
    AgentCommandVerb.allCases.filter { $0.group == self }
  }
}

nonisolated extension AgentCommandVerb {
  /// The group of the verb.
  public var group: AgentCommandGroup {
    switch self {
    case .send, .focusComposer: .compose
    case .cancel, .approvePending, .rejectPending: .control
    case .jumpToNext, .jumpToPrevious, .nextRequest, .previousRequest, .scrollToBottom, .toggleExpandAll:
      .navigate
    case .copyMessage, .copyThread: .clipboard
    }
  }
}

extension EnvironmentValues {
  /// The groups of the agent commands that the scopes in this view do not
  /// register. The value is empty until a view sets it with
  /// ``SwiftUI/View/agentCommandGroups(off:)``.
  @Entry var agentCommandGroupsOff: Set<AgentCommandGroup> = []
}

extension View {
  /// Turns off groups of the agent commands for each agent command scope in
  /// this view (D105 (f)).
  ///
  /// The scope of ``SwiftUI/View/agentCommandScope(session:)`` and the scope
  /// that an ``AgentThreadView`` applies do not register the verbs of the
  /// groups. Apply the modifier outside the scope. A change of the groups
  /// takes effect at the next update of the scope.
  ///
  /// ```swift
  /// AgentThreadView(session: session)
  ///   .agentCommandGroups(off: [.clipboard])
  /// ```
  ///
  /// - Parameter groups: The groups to turn off.
  /// - Returns: A view that gives `groups` to the scopes in it.
  public func agentCommandGroups(off groups: Set<AgentCommandGroup>) -> some View {
    environment(\.agentCommandGroupsOff, groups)
  }
}
