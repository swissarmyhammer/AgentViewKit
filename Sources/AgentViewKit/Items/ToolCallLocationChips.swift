import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import SwiftUI

/// The locations of a tool call as a row of chips that wraps.
///
/// Each ACP location is an absolute file path, so each chip is the file of
/// its path. A tap on a chip selects the file for the inspector of the
/// environment, as a tap on an ``AttachmentView`` does: the inspector of the
/// host in the host mode of a thread view, otherwise the
/// ``InspectorSelection``. The chip is the scope of the file
/// (`agentAttachment:<id>`, AVK-11), so its context menu and the command
/// palette show the ``AgentAttachmentVerb`` commands for the file. While the
/// inspector shows the file, the chip sits on the shared selection surface.
/// The chip keeps its short label, because an ``AttachmentView`` would show
/// the whole file.
///
/// A chip is not a content tile, so it keeps the small padding of a chip.
/// ``ToolCallView`` shows the chips in its expanded body.
struct ToolCallLocationChips: View {
  /// The corners of a chip: the corners of an ``AttachmentChip``. The fill
  /// of the chip, its selection surface and the focus ring of its scope all
  /// have them.
  static let corners = AttachmentChip.corners

  /// The ACP locations to show.
  let locations: [FoundationModelsACP.ToolCallLocation]

  /// The row key of the entry, for the identifier of each chip.
  let id: String

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.attachmentSelect) private var selectForInspector

  var body: some View {
    ChipFlowLayout(spacing: editorStyle.spacing.xs) {
      ForEach(Array(locations.enumerated()), id: \.offset) { index, location in
        chip(location, index: index)
      }
    }
  }

  /// One chip: the file name, with the full path in the help tag.
  ///
  /// - Parameters:
  ///   - location: The ACP location to show.
  ///   - index: The position of the location in the locations of the entry.
  /// - Returns: The chip view.
  private func chip(_ location: FoundationModelsACP.ToolCallLocation, index: Int) -> some View {
    let path = location.path.rawValue
    let file = Attachment(url: URL(filePath: path))
    let fullText = FoundationModelsACP.ToolCallLocation.text(path: path, line: location.line)
    let shortText = FoundationModelsACP.ToolCallLocation.text(path: file.name, line: location.line)
    return Label(shortText, systemImage: SharedSymbol.document)
      .font(editorTheme.font(for: .ui, style: .caption))
      .lineLimit(1)
      .truncationMode(.middle)
      .padding(.horizontal, editorStyle.spacing.s)
      .padding(.vertical, editorStyle.spacing.xs)
      .background(.quaternary, in: EditorSurface.shape(radius: Self.corners.radius(in: editorStyle)))
      .help(fullText)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(fullText)
      .modifier(InspectorSelectable(file: file, corners: Self.corners) { selectForInspector(file) })
      .accessibilityIdentifier(ToolCallView.locationIdentifier(for: id, index: index))
      .agentAttachmentScope(file, focusRingCorners: Self.corners)
  }
}

#Preview("Location chip") {
  let path = PreviewFixtures.projectDirectory.appending(path: PreviewFixtures.codeSampleFilename).path
  ToolCallLocationChips(
    locations: [FoundationModelsACP.ToolCallLocation(path: AbsolutePath(rawValue: path))],
    id: "preview-locations")
}
