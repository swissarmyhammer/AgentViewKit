import AgentViewKit
import EditorCommands
import EditorStyle
import EditorSwiftUI
import SwiftUI

/// A list whose rows show the icon of their source (TestudoApp D212) above
/// rows with a kit symbol, for the review gallery.
///
/// The first row has a symbol source, the second row has an image source from
/// the asset catalog of the gallery, and the last rows have a symbol of the
/// kit in the symbol column. The titles of all rows start at one x.
///
/// The file imports AgentViewKit with no `@testable`, so the icon compiles
/// from a host module.
@MainActor
enum SourceIconGalleryFixtures {
  /// A row of the gallery: its title and its icon.
  struct Row {
    /// The icon at the start of a row.
    enum Icon {
      /// The icon of a source, with the source name.
      case source(AgentRowSourceIcon.Source, name: String)
      /// A symbol of the kit.
      case kitSymbol(EditorSymbol)
    }

    /// The title of the row, which is also its id in the list.
    let title: String
    /// The icon of the row.
    let icon: Icon
  }

  /// The scope of the list.
  static let scope = AgentRowListScope(
    list: FocusSegment(kind: "sourceIconGalleryList"), rowKind: "sourceIconGalleryRow")

  /// The rows of the list: the two rows with a source icon above the rows
  /// with a kit symbol.
  static let rows = [
    Row(title: "Fix the build", icon: .source(.symbol(.tool(.execute)), name: "Claude Code")),
    Row(
      title: "Explain the error",
      icon: .source(.image(name: "SampleSourceIcon", bundle: .module), name: "Codex")),
    Row(title: "Read the parser", icon: .kitSymbol(.tool(.read))),
    Row(title: "Edit the tests", icon: .kitSymbol(.tool(.edit))),
  ]

  /// The list of the rows.
  static var gallery: some View {
    AgentRowList(rows, id: \.title, scope: scope) { row in
      Label {
        Text(row.title)
      } icon: {
        icon(of: row)
      }
    }
  }

  /// The icon of a row, in the symbol column.
  ///
  /// - Parameter row: The row.
  /// - Returns: The source icon, or the kit symbol in the symbol column, as
  ///   a row of the kit draws it.
  @ViewBuilder static func icon(of row: Row) -> some View {
    switch row.icon {
    case .source(let source, let name):
      AgentRowSourceIcon(source, name: name)
    case .kitSymbol(let symbol):
      EditorSymbolImage(symbol).symbolColumn()
    }
  }

  /// The height of the image, in points: room for the four rows.
  nonisolated static let height: CGFloat = 200

  /// The size of the image, in points.
  nonisolated static let size = CGSize(width: SnapshotFixtures.narrowWidth, height: height)
}
