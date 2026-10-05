import FoundationModelsACPClient
import SwiftUI

/// The view of a whole thread (plan.md §3.6, §8, §9 A).
///
/// The view shows the thread in a ``ConversationView``: one ``ItemRow`` for
/// each item, in a lazy stack that follows the bottom. Each row reads only
/// its own record. Thus a patch to one record evaluates only the row of that
/// record.
///
/// Below the conversation, a ``PendingRequestsHost`` shows one card for each
/// pending permission request and elicitation request of the thread.
///
/// The host gives the ``AgentThreadActions`` in the initializer. There is no
/// default, because actions that do nothing are a quiet failure. The view
/// gives the actions to its subtree through
/// ``SwiftUI/EnvironmentValues/threadActions``, so each card and each control
/// in the thread calls the actions of the host. For a thread that no source
/// drives, pass ``LoggingThreadActions``.
///
/// To replace the view of an item kind, use a typed modifier such as
/// ``SwiftUI/View/toolCallView(_:)``.
///
/// The view gives an ``ExpandedBlocksStore`` to its rows. When the
/// environment has a store, the view uses that store.
///
/// A tap on an attachment in a row shows the file in a trailing inspector.
/// See ``SwiftUI/View/attachmentInspector(selection:)``. When the environment
/// has an ``InspectorSelection``, the view uses that selection.
///
/// The view registers the agent commands of its thread (``AgentCommandVerb``)
/// with the keys of ``AgentKeymap``. See
/// ``SwiftUI/View/agentCommandScope(thread:)``.
///
/// The view is accessible by default (plan.md §6, ``ThreadAccessibility``):
///
/// - It owns the namespace of the linked reading groups of its messages and
///   rows (``SwiftUI/View/accessibilityReadingScope()``).
/// - It tells the ``SwiftUI/EnvironmentValues/announcer`` when a turn
///   stops, when a tool call gets its result, and when a request needs the
///   user. A streaming chunk gives no announcement.
/// - It gives an ``AccessibilityFocusMover`` to its subtree
///   (``SwiftUI/View/accessibilityFocusScope()``), so that a new request
///   card takes the VoiceOver focus.
///
/// ``init(session:actions:)`` shows the transcript of a `SessionModel`
/// (update.md §4.2, §4.7). The conversation keys each row on
/// `TranscriptEntry.id`, and each item view reads its own entry object, so a
/// streamed chunk draws only the row of its entry. The pending requests, the
/// announcements and the agent commands read an ``AgentThread``, so a view of
/// a session model does not show them.
public struct AgentThreadView: View {
  /// The model that the view shows.
  private enum Source {
    /// An ``AgentThread``.
    case thread(AgentThread)

    /// A `SessionModel`.
    case session(SessionModel)
  }

  /// The model to show.
  private let source: Source

  /// The actions that the views of the thread call.
  let actions: any AgentThreadActions

  /// The store that the view makes when the environment has none.
  @State private var ownExpandedBlocks = ExpandedBlocksStore()

  /// The inspector selection that the view makes when the environment has
  /// none.
  @State private var ownInspectorSelection = InspectorSelection()

  /// The scroll anchors of the list. The agent commands use them to jump
  /// and to scroll.
  @State private var anchors = ScrollAnchorManager()

  @Environment(\.expandedBlocksStore) private var hostExpandedBlocks
  @Environment(\.inspectorSelection) private var hostInspectorSelection

  /// Makes the view of a thread.
  ///
  /// - Parameters:
  ///   - thread: The thread to show.
  ///   - actions: The actions that the views of the thread call. A thread
  ///     that no source drives takes ``LoggingThreadActions``.
  @available(
    *, deprecated,
    message: "Use init(session:actions:). The removal of the ACP adapter removes this initializer."
  )
  public init(thread: AgentThread, actions: any AgentThreadActions) {
    self.source = .thread(thread)
    self.actions = actions
  }

  /// Makes the view of the transcript of a session model.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - actions: The actions that the views of the thread call.
  public init(session: SessionModel, actions: any AgentThreadActions) {
    self.source = .session(session)
    self.actions = actions
  }

  public var body: some View {
    content
      // The agent command scope reads neither scope, so it can be inside
      // them.
      .accessibilityReadingScope()
      .accessibilityFocusScope()
      .environment(\.expandedBlocksStore, hostExpandedBlocks ?? ownExpandedBlocks)
      .attachmentInspector(selection: hostInspectorSelection ?? ownInspectorSelection)
      // The actions are the outermost value, so that each modifier above, and
      // the agent command scope, reads the actions of the initializer.
      .threadActions(actions)
  }

  /// The conversation of the model, with the parts that read the model.
  @ViewBuilder private var content: some View {
    switch source {
    case .thread(let thread):
      VStack(spacing: 0) {
        ConversationView(thread: thread, anchors: anchors)
        PendingRequestsHost(thread: thread)
      }
      .background { ThreadAnnouncementObserver(thread: thread) }
      .agentCommandScope(thread: thread, anchors: anchors)
    case .session(let session):
      ConversationView(session: session, anchors: anchors)
    }
  }
}
