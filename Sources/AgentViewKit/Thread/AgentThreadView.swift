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
public struct AgentThreadView: View {
  /// The thread to show.
  let thread: AgentThread

  /// The store that the view makes when the environment has none.
  @State private var ownExpandedBlocks = ExpandedBlocksStore()

  /// The inspector selection that the view makes when the environment has
  /// none.
  @State private var ownInspectorSelection = InspectorSelection()

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
      ConversationView(thread: thread)
      PendingRequestsHost(thread: thread)
    }
    .environment(\.expandedBlocksStore, hostExpandedBlocks ?? ownExpandedBlocks)
    .attachmentInspector(selection: hostInspectorSelection ?? ownInspectorSelection)
  }
}
