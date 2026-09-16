import SwiftUI

/// A collapsible block with a title and a monospaced JSON text (plan.md §9 A2).
///
/// ``StructuredItemView`` and ``UnknownItemView`` use this view. The expanded
/// state is in the ``ExpandedBlocksStore`` of the environment, keyed by the
/// record id. When the environment has no store, the view keeps the state
/// itself.
struct JSONDisclosure: View {
  /// The identifier of the record. The store keys the state by this value.
  let id: String

  /// The title of the block.
  let title: String

  /// The JSON text that the expanded block shows.
  let json: String

  /// The accessibility identifier of the block.
  let identifier: String

  /// The expanded state when the environment has no store.
  @State private var localExpanded: Bool

  @Environment(\.expandedBlocksStore) private var store
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
    _localExpanded = State(initialValue: isExpanded)
  }

  var body: some View {
    DisclosureGroup(isExpanded: expanded) {
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

  /// The binding of the expanded state: the store of the environment, or
  /// the local state when there is no store.
  private var expanded: Binding<Bool> {
    guard let store else { return $localExpanded }
    let id = id
    return Binding(
      get: { store.isExpanded(id) },
      set: { isExpanded in
        if isExpanded {
          store.expand(id)
        } else {
          store.collapse(id)
        }
      }
    )
  }
}
