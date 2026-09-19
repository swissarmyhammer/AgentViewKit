import SwiftUI

/// The view of a whole thread (plan.md §3.6, §8, §9 A).
///
/// The view shows the thread in a ``ConversationView``: one ``ItemRow`` for
/// each item, in a lazy stack that follows the bottom. Each row reads only
/// its own record. Thus a patch to one record evaluates only the row of that
/// record.
///
/// Below the conversation, a ``PendingRequestsHost`` shows one card for each
/// pending permission, elicitation, and authorization request of the thread.
///
/// The host gives the ``AgentThreadActions`` in the initializer. There is no
/// default, because actions that do nothing are a quiet failure. The view
/// gives the actions to its subtree through
/// ``SwiftUI/EnvironmentValues/threadActions``, so each card and each control
/// in the thread calls the actions of the host. For a thread that no source
/// drives, pass ``LoggingThreadActions``.
///
/// To replace the view of an item kind, use a typed modifier such as
/// ``SwiftUI/View/toolCallView(_:)``. To replace the view of a schema name,
/// use ``SwiftUI/View/structuredItem(_:_:)``.
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
public struct AgentThreadView: View {
  /// The thread to show.
  let thread: AgentThread

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
  public init(thread: AgentThread, actions: any AgentThreadActions) {
    self.thread = thread
    self.actions = actions
  }

  public var body: some View {
    VStack(spacing: 0) {
      ConversationView(thread: thread, anchors: anchors)
      PendingRequestsHost(thread: thread)
    }
    .background { ThreadAnnouncementObserver(thread: thread) }
    .accessibilityReadingScope()
    .accessibilityFocusScope()
    .agentCommandScope(thread: thread, anchors: anchors)
    .environment(\.expandedBlocksStore, hostExpandedBlocks ?? ownExpandedBlocks)
    .attachmentInspector(selection: hostInspectorSelection ?? ownInspectorSelection)
    // The actions are the outermost value, so that each modifier above, and
    // the agent command scope, reads the actions of the initializer.
    .threadActions(actions)
  }
}
