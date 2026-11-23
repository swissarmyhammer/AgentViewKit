import EditorStyle
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

  /// The secondary text of the header, already localized, such as the
  /// progress of a read ("Reading 1,240 of 4,427"), or `nil` for no text.
  public let detail: String?

  /// Makes a section.
  ///
  /// - Parameters:
  ///   - id: The id of the section. Each section of a list has its own id.
  ///   - title: The title of the header, already localized.
  ///   - items: The items of the rows, in list order.
  ///   - detail: The secondary text of the header, already localized, or
  ///     `nil` for no text.
  public init(id: String, title: String, items: [Item], detail: String? = nil) {
    self.id = id
    self.title = title
    self.items = items
    self.detail = detail
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
  /// The header of a section, with the secondary text of the section or
  /// `nil`.
  case header(sectionID: String, title: String, detail: String?)

  /// The row of an item.
  case row(id: String, item: Item)

  var id: AgentRowEntryID {
    switch self {
    case .header(let sectionID, _, _): .header(sectionID)
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
      [.header(sectionID: section.id, title: section.title, detail: section.detail)] + rows(of: section.items, id: id)
    }
  }
}

/// The header of a section of an ``AgentRowList``: the semibold subheadline of
/// the `ui` font role, as the header of a sidebar section is (EditorKit
/// `style.md`, "Fonts").
///
/// A section with a detail shows the detail after the title, in the regular
/// subheadline of the `ui` font role, with digits of one width, so the numbers
/// of a progress do not move while they change. When the title and the detail
/// do not fit on one line, the detail moves below the title. The title and the
/// detail each keep one line and truncate at the tail only when the width
/// cannot hold them alone, so the header never makes the list wider. A section
/// with no detail shows the title alone.
///
/// VoiceOver reads the header as one heading: "<title>, <detail>", or the
/// title alone.
///
/// The header is bare (rule 10): the list gives it its place. It has no command
/// scope and no focusable view, so no key, jump or click reaches it.
struct AgentRowSectionHeader: View {
  /// The title of the section.
  let title: String

  /// The secondary text of the section, or `nil` for no text.
  let detail: String?

  /// The accessibility identifier of the header.
  let identifier: String

  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    content
      .foregroundStyle(.secondary)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      .accessibilityIdentifier(identifier)
  }

  /// The title, and the detail on the same line or below the title.
  @ViewBuilder private var content: some View {
    if let detail {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: editorStyle.spacing.xs) {
          titleText
          detailText(detail)
        }
        VStack(alignment: .leading, spacing: .zero) {
          titleText
          detailText(detail)
        }
      }
    } else {
      titleText
    }
  }

  /// The title, on one line, with the higher layout priority.
  private var titleText: some View {
    Text(title)
      .font(editorTheme.font(for: .ui, style: .subheadline).weight(.semibold))
      .lineLimit(1)
      .layoutPriority(1)
  }

  /// The detail, on one line, which truncates at its tail.
  ///
  /// - Parameter detail: The secondary text of the section.
  /// - Returns: The text.
  private func detailText(_ detail: String) -> some View {
    Text(detail)
      .font(editorTheme.font(for: .ui, style: .subheadline))
      .monospacedDigit()
      .lineLimit(1)
      .truncationMode(.tail)
  }

  /// The accessibility identifier of the header of a section.
  ///
  /// - Parameter sectionID: The id of the section.
  /// - Returns: The identifier.
  static func identifier(for sectionID: String) -> String {
    "agentRowSection.\(sectionID)"
  }
}
