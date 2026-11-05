@testable import AgentViewKit
import EditorStyle
import SwiftUI

/// The chip rows of the kit in a narrow column, for the review gallery: the
/// location chips of a tool call and the file chips of a diff, each in
/// EditorKit's `EditorChipRows`, with more chips than one row holds, so the
/// rows wrap.
@MainActor
enum ChipRowsGalleryFixtures {
  /// The folder of each sample location: short, so two chips share a row.
  static let folder = "/Board/"

  /// The folder of each sample file of the patch.
  static let patchFolder = "Board/"

  /// The names of the sample files: short names, so a row holds more than one
  /// chip, and one long name, which takes a row of its own.
  static let fileNames = [
    "Board.swift", "Card.swift", "Tag.swift", "BoardColumnDropDelegate.swift", "Column.swift", "README.md",
  ]

  /// The line of every other sample location.
  static let locationLine = 42

  /// The step between two sample locations that have a line: every other one.
  static let lineStep = 2

  /// The location chips of a tool call: one chip for each sample file, every
  /// other one with a line.
  static var locationChips: some View {
    ToolCallLocationChips(
      locations: fileNames.enumerated().map { index, name in
        ToolCallLocationChips.Location(
          path: folder + name, line: index.isMultiple(of: lineStep) ? locationLine : nil,
          identifier: "gallery-location-\(index)")
      })
  }

  /// A git patch that adds one line to each sample file.
  static var patch: String {
    fileNames.map { name in
      let path = patchFolder + name
      return """
        --- a/\(path)
        +++ b/\(path)
        @@ -1,1 +1,2 @@
         // \(name)
        +// Wraps in a narrow column.
        """
    }
    .joined(separator: "\n")
  }

  /// The location chips over the diff, with the space between two blocks of
  /// the tile.
  static var gallery: some View {
    VStack(alignment: .leading, spacing: EditorStyle.default.tile.margin) {
      locationChips
      DiffView(patch: patch)
    }
    .padding(EditorStyle.default.tile.margin)
  }

  /// The height of the image, in points.
  static let height: CGFloat = 520

  /// The size of the image: the narrow width of a card.
  static let size = CGSize(width: SnapshotFixtures.narrowWidth, height: height)
}
