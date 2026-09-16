import SwiftUI

/// A collapsible block with a title and a monospaced JSON text (plan.md §9 A2).
///
/// ``StructuredItemView`` and ``UnknownItemView`` use this view. The expanded
/// state is in the ``ExpandedBlocksStore`` of the environment, keyed by the
/// record id. When the environment has no store, the view uses a store of its
/// own.
struct JSONDisclosure: View {
  /// The identifier of the record. The store keys the state by this value.
  let id: String

  /// The title of the block.
  let title: String

  /// The JSON text that the expanded block shows.
  let json: String

  /// The accessibility identifier of the block.
  let identifier: String

  /// The store that the view uses when the environment has no store.
  @State private var ownStore: ExpandedBlocksStore

  @Environment(\.expandedBlocksStore) private var environmentStore
  @Environment(\.agentTheme) private var theme

  /// Makes the block.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - title: The title of the block.
  ///   - json: The JSON text to show.
  ///   - identifier: The accessibility identifier of the block.
  ///   - isExpanded: The start state when the environment has no store.
  init(id: String, title: String, json: String, identifier: String, isExpanded: Bool) {
    self.id = id
    self.title = title
    self.json = json
    self.identifier = identifier
    let store = ExpandedBlocksStore()
    if isExpanded {
      store.expand(id)
    }
    _ownStore = State(initialValue: store)
  }

  var body: some View {
    let store = environmentStore ?? ownStore
    let id = id
    DisclosureGroup(
      isExpanded: Binding(
        get: { store.isExpanded(id) },
        set: { isExpanded in
          if isExpanded {
            store.expand(id)
          } else {
            store.collapse(id)
          }
        }
      )
    ) {
      Text(json)
        .font(theme.codeFont)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, theme.spacing.xs)
    } label: {
      Text(title)
        .font(theme.codeFont)
        .lineLimit(1)
    }
    .accessibilityIdentifier(identifier)
  }
}
