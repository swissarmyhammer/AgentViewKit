import EditorStyle
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The quick-open list of Jump to Session: the descendants and the ancestors
/// of the shown session, filtered by name, each with its path, such as
/// "Agent › Reviewer › Linter".
///
/// The list reads the path entries that the model gives (``SessionModel``
/// `ancestors` and `descendants`) and keeps no copy of the tree. The field
/// filters as the user types. Return chooses the first entry that matches,
/// and a click chooses a row. The list shows each entry at any level of the
/// tree.
struct SessionJumpList: View {
  /// The accessibility identifier of the filter field.
  static let fieldIdentifier = "session-jump-field"

  /// The accessibility identifier of the row of a session.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The identifier.
  static func rowIdentifier(for id: SessionId) -> String { "session-jump-row-" + id.rawValue }

  /// The least width of the list.
  static let minimumWidth: CGFloat = 360

  /// The least height of the list.
  static let minimumHeight: CGFloat = 240

  /// The name of the agent, the first name of each path, or `nil`.
  let agent: String?

  /// The entries to choose from.
  let entries: [SessionPathEntry]

  /// Called with the id of the chosen session.
  let choose: (SessionId) -> Void

  @State private var query = ""
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.locale) private var locale

  /// The text of the path of an entry: the agent, then the titles of the
  /// path, joined by the visible path pattern of the catalog
  /// (``ChainText/visiblePath(_:locale:)``).
  ///
  /// - Parameters:
  ///   - entry: The path entry.
  ///   - agent: The name of the agent, or `nil`.
  ///   - locale: The locale of the text.
  /// - Returns: Text such as "Agent › Reviewer › Linter".
  static func pathText(of entry: SessionPathEntry, agent: String?, locale: Locale = .autoupdatingCurrent) -> String {
    ChainText.visiblePath((agent.map { [$0] } ?? []) + entry.path, locale: locale)
  }

  /// The entries that match a query.
  ///
  /// Each word of the query must be in the path of the entry. The comparison
  /// ignores case. A blank query matches each entry.
  ///
  /// - Parameters:
  ///   - entries: The entries to filter.
  ///   - query: The text of the filter field.
  ///   - agent: The name of the agent, the first name of each shown path.
  ///   - locale: The locale of the shown paths.
  /// - Returns: The matching entries, in their order.
  static func filter(
    _ entries: [SessionPathEntry], query: String, agent: String? = nil, locale: Locale = .autoupdatingCurrent
  ) -> [SessionPathEntry] {
    let words = query.lowercased().split(whereSeparator: \.isWhitespace)
    guard !words.isEmpty else { return entries }
    return entries.filter { entry in
      let path = pathText(of: entry, agent: agent, locale: locale).lowercased()
      return words.allSatisfy { path.contains($0) }
    }
  }

  var body: some View {
    let shown = Self.filter(entries, query: query, agent: agent, locale: locale)
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      TextField(String(localized: "Jump to session", bundle: .module), text: $query)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier(Self.fieldIdentifier)
        .onSubmit {
          if let first = shown.first { choose(first.sessionId) }
        }
      List(shown) { entry in
        Button {
          choose(entry.sessionId)
        } label: {
          VStack(alignment: .leading) {
            Text(Self.pathText(of: entry, agent: agent, locale: locale))
            Text(SessionStateText.choiceLabel(for: entry, locale: locale))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Self.rowIdentifier(for: entry.sessionId))
      }
    }
    .padding(editorStyle.spacing.m)
    .frame(minWidth: Self.minimumWidth, minHeight: Self.minimumHeight)
  }
}
