import EditorStyle
import EditorSwiftUI
import SwiftUI

/// The locations of a tool call as a row of chips that wraps.
///
/// Each location is a file path, so each chip is the EditorKit `PathChip` of
/// its path: the document symbol, the name of the file with the line when
/// there is one, and the folder of the path, with the full path in its help
/// tag. The row is a compound view of the kit around the chip of EditorKit,
/// which keeps the look of a chip.
///
/// A press on a chip changes the files of the inspector of the environment,
/// as a press on an ``AttachmentView`` does (a click selects, a Command-click
/// adds or takes out, a Shift-click extends): the inspector of the host in
/// the host mode of a thread view, otherwise the ``InspectorSelection``.
/// While the
/// inspector shows the file, the chip sits on the shared selection surface,
/// in the corners of the chip (`SurfaceCorners.pathChip`). The chip is the
/// scope of the file (`agentAttachment:<id>`, AVK-11), so its context menu
/// and the command palette show the ``AgentAttachmentVerb`` commands for the
/// file. The chip keeps its short label, because an ``AttachmentView`` would
/// show the whole file.
struct ToolCallLocationChips: View {
  /// One location of a tool call: a file path, and the line in the file when
  /// the source gives one.
  struct Location: Hashable, Sendable, Identifiable {
    /// The path of the file.
    let path: String

    /// The line in the file, or `nil` when the source gave none.
    let line: Int?

    /// The accessibility identifier of the chip of the location. It is the
    /// identity of the chip, so it stays the same when the call hides
    /// another location.
    let identifier: String

    /// The identity of the location: the identifier of its chip.
    var id: String { identifier }
  }

  /// The locations to show, in order.
  let locations: [Location]

  @Environment(\.editorStyle) private var editorStyle

  /// A chip for each location, in a flow layout that wraps the chips to the next line.
  var body: some View {
    EditorChipRows(spacing: editorStyle.spacing.xs) {
      ForEach(locations) { location in
        LocationChip(location: location)
      }
    }
  }
}

/// The chip of one location, with the inspector and the scope of its file.
/// The chip reads the inspector action of the environment, so it is a view.
private struct LocationChip: View {
  /// The location of the chip.
  let location: ToolCallLocationChips.Location

  @Environment(\.attachmentSelect) private var selectForInspector

  /// The EditorKit `PathChip` of the path and the line, with the identifier
  /// of the location as its accessibility identifier.
  var body: some View {
    let file = Attachment(url: URL(filePath: location.path))
    PathChip(location.path, line: location.line)
      .accessibilityIdentifier(location.identifier)
      .modifier(
        InspectorSelectable(file: file, corners: .pathChip) { selectForInspector(file, change: $0) })
      .agentAttachmentScope(file, focusRingCorners: .pathChip)
  }
}

#Preview("Location chips") {
  let path = PreviewFixtures.projectDirectory.appending(path: PreviewFixtures.codeSampleFilename).path
  ToolCallLocationChips(locations: [
    ToolCallLocationChips.Location(path: path, line: nil, identifier: "preview-location-0")
  ])
  .padding()
}
