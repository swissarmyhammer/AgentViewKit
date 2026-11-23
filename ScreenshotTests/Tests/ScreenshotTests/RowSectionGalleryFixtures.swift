@testable import AgentViewKit
import EditorCommands
import SwiftUI

/// A list of sections for the review gallery (TestudoApp D212): a section
/// with no detail, and the section "Other Agents" with the progress of a read
/// in its header, at the normal width and at a narrow width.
///
/// At the normal width the detail stands after the title. At the narrow width
/// the title and the detail do not fit on one line, so the detail moves below
/// the title.
@MainActor
enum RowSectionGalleryFixtures {
  /// The scope of the list.
  static let scope = AgentRowListScope(
    list: FocusSegment(kind: "rowSectionGalleryList"), rowKind: "rowSectionGalleryRow")

  /// The sections of the list: a section with no detail above the section
  /// with the progress of a read.
  static let sections = [
    AgentRowSection(id: "recent", title: "Recent", items: ["Fix the build", "Explain the error"]),
    AgentRowSection(
      id: "other", title: "Other Agents", items: ["Review the diff", "Run the tests again"],
      detail: "Reading 1,240 of 4,427"),
  ]

  /// The list of the sections.
  static var gallery: some View {
    AgentRowList(sections: sections, id: \.self, scope: scope) { title in
      Text(title)
    }
  }

  /// The width of a narrow column, in points: too narrow for the title and
  /// the detail on one line.
  nonisolated static let narrowWidth: CGFloat = 180

  /// The height of each image, in points.
  nonisolated static let height: CGFloat = 240

  /// The size of the image at the normal width.
  nonisolated static let size = CGSize(width: SnapshotFixtures.narrowWidth, height: height)

  /// The size of the image at the narrow width.
  nonisolated static let narrowSize = CGSize(width: narrowWidth, height: height)
}
