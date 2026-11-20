import SwiftUI

/// The groups of the agent commands that a host can turn off (D105 (f)).
///
/// Each ``AgentCommandVerb`` and each ``AgentAttachmentVerb`` is in exactly
/// one group. A scope does not
/// register a verb of a group that is off. Thus the verb does not show in the
/// menus, the context menus or the command palette, and its keys resolve to
/// nothing. A host gives the groups to turn off with
/// ``SwiftUI/View/agentCommandGroups(off:)``.
///
/// | Group | Verbs |
/// | --- | --- |
/// | ``compose`` | Send Message, Focus Composer |
/// | ``control`` | Stop, Approve Request, Reject Request |
/// | ``navigate`` | Next Prompt, Previous Prompt, Next Request, Previous Request, Scroll to Bottom, Expand or Collapse All, Go to Parent Session, Open Child Session, Next Sibling Session, Previous Sibling Session, Jump to Session |
/// | ``clipboard`` | Copy Message, Copy Thread, Copy Code Block |
/// | ``export`` | Export as Markdown… |
/// | ``fork`` | Fork from Here |
/// | ``find`` | Find Next Hit, Find Previous Hit, Clear Search Hits |
/// | ``attachment`` | Open, Reveal in Finder, Share, Save, Inspect (``AgentAttachmentVerb``) |
/// | ``sideCard`` | Send to Chat, Open, Close (``SideCardVerb``) |
///
/// A scope of a read-only session (TestudoApp D208 (i)) does not register
/// the verbs of the groups that change the session (``changesSession``):
/// ``compose``, ``control`` and ``fork``.
/// While a thread view shows the unavailable message of the host, the verbs
/// that need the transcript (``AgentCommandVerb/needsTranscript``) are not
/// available: the verbs of ``clipboard``, ``export`` and ``find``, and the
/// verbs of ``navigate`` that act on the list.
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

  /// The verbs that copy the text of the thread to the pasteboard.
  case clipboard

  /// The verbs that save the thread to a file. These verbs do not use the
  /// pasteboard. Thus a host that turns off ``clipboard`` keeps them.
  case export

  /// The verbs that start a new session from the thread (D205). The host
  /// runs the fork, and the verb is in the registry only when the host gives
  /// its action (``SwiftUI/View/onForkFromHere(unavailableReason:_:)``).
  case fork

  /// The verbs that go through the search hits of the thread and remove
  /// them (TestudoApp D207 (f)). With the group off, Esc does not remove the
  /// hits.
  case find

  /// The verbs that act on an attached file (AVK-11). The scope of each
  /// attachment registers them, and not the scope of the thread.
  case attachment

  /// The verbs of a side card of `/btw` (D205). The scope of each
  /// ``SideQuestionCard`` registers them, and not the scope of the thread.
  case sideCard

  /// The id of the group, `agent.<group>`. It has the prefix of the command
  /// ids of the kit.
  public var id: String {
    AgentCommandVerb.idPrefix + rawValue
  }

  /// The thread verbs of the group, in the order of the verbs. The groups
  /// ``attachment`` and ``sideCard`` have no thread verb; see
  /// ``attachmentVerbs`` and ``sideCardVerbs``.
  public var verbs: [AgentCommandVerb] {
    AgentCommandVerb.allCases.filter { $0.group == self }
  }

  /// The attachment verbs of the group, in the order of the verbs. Only the
  /// group ``attachment`` has attachment verbs.
  public var attachmentVerbs: [AgentAttachmentVerb] {
    AgentAttachmentVerb.allCases.filter { $0.group == self }
  }

  /// The side card verbs of the group, in the order of the verbs. Only the
  /// group ``sideCard`` has side card verbs.
  public var sideCardVerbs: [SideCardVerb] {
    SideCardVerb.allCases.filter { $0.group == self }
  }

  /// Tells if the thread verbs of the group change the session, or act on
  /// the composer that changes it.
  ///
  /// The groups ``compose``, ``control`` and ``fork`` change the session. A
  /// thread scope of a read-only session (`SessionModel.isReadOnly`, the
  /// shared session of TestudoApp D208 (i)) does not register their verbs
  /// (``AgentCommandTarget/registers(_:)``). Thus no menu, context menu,
  /// palette row or key of the thread gives them. The other groups only
  /// read the thread, so the read-only scope keeps them.
  public var changesSession: Bool {
    switch self {
    case .compose, .control, .fork: true
    case .navigate, .clipboard, .export, .find, .attachment, .sideCard: false
    }
  }
}

nonisolated extension AgentCommandVerb {
  /// Tells if the verb needs the transcript: it reads the text of the
  /// session, or it acts on the list of the transcript.
  ///
  /// The verbs of the groups ``AgentCommandGroup/clipboard``,
  /// ``AgentCommandGroup/export`` and ``AgentCommandGroup/find`` read the
  /// text of the session. Next Prompt, Previous Prompt, Scroll to Bottom and
  /// Expand or Collapse All of ``AgentCommandGroup/navigate`` act on the
  /// list. While a thread view shows the unavailable message of the host
  /// (``SwiftUI/View/threadUnavailable(_:)``), no list shows, and these verbs
  /// are not available (``AgentCommandTarget/isSessionUnavailable``).
  ///
  /// The other verbs of ``AgentCommandGroup/navigate`` stay: Next Request
  /// and Previous Request act on the request deck, and Go to Parent Session,
  /// Open Child Session, Next Sibling Session, Previous Sibling Session and
  /// Jump to Session act on the session tree.
  public var needsTranscript: Bool {
    switch self {
    case .copyMessage, .copyThread, .copyCodeBlock, .exportMarkdown, .findNextHit, .findPreviousHit,
      .clearSearchHits, .jumpToNext, .jumpToPrevious, .scrollToBottom, .toggleExpandAll:
      true
    case .send, .focusComposer, .insertMention, .cancel, .approvePending, .rejectPending,
      .nextRequest, .previousRequest, .goToParent, .openChild, .nextSibling, .previousSibling,
      .jumpToSession, .forkFromHere:
      false
    }
  }

  /// The group of the verb.
  public var group: AgentCommandGroup {
    switch self {
    case .send, .focusComposer, .insertMention: .compose
    case .cancel, .approvePending, .rejectPending: .control
    case .jumpToNext, .jumpToPrevious, .nextRequest, .previousRequest, .scrollToBottom, .toggleExpandAll,
      .goToParent, .openChild, .nextSibling, .previousSibling, .jumpToSession:
      .navigate
    case .copyMessage, .copyThread, .copyCodeBlock: .clipboard
    case .exportMarkdown: .export
    case .forkFromHere: .fork
    case .findNextHit, .findPreviousHit, .clearSearchHits: .find
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
  /// The scope of ``SwiftUI/View/agentCommandScope(session:)``, the scope
  /// that an ``AgentThreadView`` applies and the scope of each attachment do
  /// not register the verbs of the groups. With ``AgentCommandGroup/attachment``
  /// off, the attachment views also show no action buttons. Apply the
  /// modifier outside the scope. A change of the groups takes effect at the
  /// next update of the scope.
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
