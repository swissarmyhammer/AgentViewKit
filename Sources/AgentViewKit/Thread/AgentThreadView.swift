import SwiftUI

/// The view of a whole thread (plan.md §3.6, §8, §9 A).
///
/// The view shows one ``ItemRow`` for each item of the thread, in a lazy
/// stack. The body reads only ``AgentThread/items``, and each row reads only
/// its own record. Thus a patch to one record evaluates only the row of that
/// record.
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
  @Environment(\.agentTheme) private var theme

  /// Makes the view of a thread.
  ///
  /// - Parameter thread: The thread to show.
  public init(thread: AgentThread) {
    self.thread = thread
  }

  public var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: theme.spacing.m) {
        ForEach(thread.items, id: \.id) { item in
          ItemRow(item: item)
            .equatable()
        }
      }
      .padding(theme.rowPadding)
    }
    .environment(\.expandedBlocksStore, hostExpandedBlocks ?? ownExpandedBlocks)
    .attachmentInspector(selection: hostInspectorSelection ?? ownInspectorSelection)
  }
}
