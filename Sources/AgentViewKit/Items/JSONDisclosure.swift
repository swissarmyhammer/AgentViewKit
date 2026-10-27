import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import SwiftUI

/// A collapsible block with a title and a monospaced JSON text (plan.md §9 A2).
///
/// ``UnknownItemView`` uses this view. The expanded state is in the
/// ``ExpandedBlocksStore`` of the environment, keyed by the record id. When
/// the environment has no store, the view uses a store of its own.
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
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

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
      store.expand(id: id)
    }
    _ownStore = State(initialValue: store)
  }

  var body: some View {
    let store = environmentStore ?? ownStore
    let id = id
    DisclosureGroup(
      isExpanded: Binding(
        get: { store.isExpanded(id: id) },
        set: { isExpanded in
          if isExpanded {
            store.expand(id: id)
          } else {
            store.collapse(id: id)
          }
        }
      )
    ) {
      Text(json)
        .font(editorTheme.codeFont)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, editorStyle.tile.gap)
    } label: {
      Text(title)
        .font(editorTheme.uiFont)
        .lineLimit(1)
    }
    .contentTile()
    .accessibilityIdentifier(identifier)
  }
}

// MARK: - Previews

/// A JSON value of the previews, in a block that starts open or closed.
private struct JSONDisclosureSample: View {
  /// The identifier of the record and the accessibility identifier of the
  /// block.
  private static let identifier = "preview-json"

  /// The JSON value that the block shows.
  let json: JSONValue

  /// Whether the block starts open.
  let isExpanded: Bool

  var body: some View {
    JSONDisclosure(
      id: Self.identifier, title: PreviewFixtures.reviewSummaryKind, json: json.prettyPrinted,
      identifier: Self.identifier, isExpanded: isExpanded
    )
    .frame(width: PreviewFixtures.narrowWidth)
    .padding()
  }
}

#Preview("Small JSON, closed") {
  JSONDisclosureSample(json: PreviewFixtures.smallJSON, isExpanded: false)
}

#Preview("Small JSON, open") {
  JSONDisclosureSample(json: PreviewFixtures.smallJSON, isExpanded: true)
}

#Preview("Deep JSON with long values, closed") {
  JSONDisclosureSample(json: PreviewFixtures.deepJSON, isExpanded: false)
}

#Preview("Deep JSON with long values, open") {
  ScrollView {
    JSONDisclosureSample(json: PreviewFixtures.deepJSON, isExpanded: true)
  }
}
