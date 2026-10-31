import EditorTheme
import SwiftUI

/// One section of an ``AgentRowList``: a title and the items of its rows.
///
/// The list shows the title as a header above the rows, and shows no header for
/// a section with no items. A header is no row: the arrow keys, the jump labels
/// and the mouse pass it by.
public struct AgentRowSection<Item>: Identifiable {
  /// The id of the section, which keeps its identity in the lazy stack of the
  /// list while its title or its items change. Each section of a list has its
  /// own id.
  public let id: String

  /// The title of the header, already localized.
  public let title: String

  /// The items of the rows, in list order.
  public let items: [Item]

  /// Makes a section.
  ///
  /// - Parameters:
  ///   - id: The id of the section. Each section of a list has its own id.
  ///   - title: The title of the header, already localized.
  ///   - items: The items of the rows, in list order.
  public init(id: String, title: String, items: [Item]) {
    self.id = id
    self.title = title
    self.items = items
  }
}

extension AgentRowSection: Sendable where Item: Sendable {}

/// The identity of one entry of the lazy stack of an ``AgentRowList``.
///
/// A row and a section may have the same id, so each kind has its own case. The
/// id of a row holds no section, so a row keeps its identity when it moves to
/// another section, as a session does when it is pinned.
enum AgentRowEntryID: Hashable {
  /// The header of the section with this id.
  case header(String)

  /// The row with this id.
  case row(String)
}

/// One entry of the lazy stack of an ``AgentRowList``: a header or a row.
enum AgentRowListEntry<Item>: Identifiable {
  /// The header of a section.
  case header(sectionID: String, title: String)

  /// The row of an item.
  case row(id: String, item: Item)

  var id: AgentRowEntryID {
    switch self {
    case .header(let sectionID, _): .header(sectionID)
    case .row(let id, _): .row(id)
    }
  }

  /// The id and the item of a row, or `nil` for a header.
  var row: (id: String, item: Item)? {
    switch self {
    case .header: nil
    case .row(let id, let item): (id, item)
    }
  }

  /// The header that stands right above a row.
  ///
  /// - Parameters:
  ///   - rowID: The id of a row.
  ///   - entries: The entries of the list.
  /// - Returns: The identity of the header above the first row of a section,
  ///   or `nil` for any other row.
  static func headerID(above rowID: String, in entries: [Self]) -> AgentRowEntryID? {
    guard let index = entries.firstIndex(where: { $0.row?.id == rowID }), index > entries.startIndex else {
      return nil
    }
    let previous = entries[index - 1]
    return previous.row == nil ? previous.id : nil
  }

  /// The entries of a list with no headers.
  ///
  /// - Parameters:
  ///   - items: The items of the rows, in list order.
  ///   - id: The id of an item.
  /// - Returns: One row for each item.
  static func rows(of items: [Item], id: KeyPath<Item, String>) -> [Self] {
    items.map { .row(id: $0[keyPath: id], item: $0) }
  }

  /// The entries of a list of sections: each section with items gives its
  /// header and its rows.
  ///
  /// - Parameters:
  ///   - sections: The sections, in list order.
  ///   - id: The id of an item.
  /// - Returns: The entries, in list order.
  static func entries(of sections: [AgentRowSection<Item>], id: KeyPath<Item, String>) -> [Self] {
    sections.filter { !$0.items.isEmpty }.flatMap { section in
      [.header(sectionID: section.id, title: section.title)] + rows(of: section.items, id: id)
    }
  }
}

/// The header of a section of an ``AgentRowList``: the semibold subheadline of
/// the `ui` font role, as the header of a sidebar section is (EditorKit
/// `style.md`, "Fonts").
///
/// The header is bare (rule 10): the list gives it its place. It has no command
/// scope and no focusable view, so no key, jump or click reaches it.
struct AgentRowSectionHeader: View {
  /// The title of the section.
  let title: String

  /// The accessibility identifier of the header.
  let identifier: String

  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    Text(title)
      .font(editorTheme.font(for: .ui, style: .subheadline).weight(.semibold))
      .foregroundStyle(.secondary)
      .accessibilityAddTraits(.isHeader)
      .accessibilityIdentifier(identifier)
  }

  /// The accessibility identifier of the header of a section.
  ///
  /// - Parameter sectionID: The id of the section.
  /// - Returns: The identifier.
  static func identifier(for sectionID: String) -> String {
    "agentRowSection.\(sectionID)"
  }
}
