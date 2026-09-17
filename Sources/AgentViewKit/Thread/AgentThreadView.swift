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
  /// - Parameter thread: The thread to show.
  public init(thread: AgentThread) {
    self.thread = thread
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
  }
}
