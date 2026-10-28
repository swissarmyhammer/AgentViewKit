import SwiftUI

/// The style of each location chip of a ``ToolCallView``: the inspector and
/// the scope of the file of the chip.
///
/// A tap on a chip selects the file for the inspector of the environment, as
/// a tap on an ``AttachmentView`` does: the inspector of the host in the host
/// mode of a thread view, otherwise the ``InspectorSelection``. While the
/// inspector shows the file, the chip sits on the shared selection surface.
/// The chip is the scope of the file (`agentAttachment:<id>`, AVK-11), so its
/// context menu and the command palette show the ``AgentAttachmentVerb``
/// commands for the file. The chip keeps its short label, because an
/// ``AttachmentView`` would show the whole file.
///
/// ``ToolCallView`` sets this style where it shows the chips, with
/// ``SwiftUI/View/toolCallLocationChipStyle(_:)``.
struct AgentLocationChipStyle: ToolCallLocationChipStyle {
  /// Gives the chip the inspector and the scope of its file.
  ///
  /// - Parameter configuration: The location and its chip.
  /// - Returns: The chip of the file.
  func makeBody(configuration: ToolCallLocationChipConfiguration) -> some View {
    AgentLocationChip(configuration: configuration)
  }
}

/// A location chip with the inspector and the scope of its file. The chip
/// reads the inspector action of the environment, so it is a view.
private struct AgentLocationChip: View {
  /// The location and its chip.
  let configuration: ToolCallLocationChipConfiguration

  @Environment(\.attachmentSelect) private var selectForInspector

  var body: some View {
    let file = Attachment(url: URL(filePath: configuration.location.path))
    configuration.chip
      .modifier(
        InspectorSelectable(file: file, corners: ToolCallLocationChips.corners) { selectForInspector(file) })
      .agentAttachmentScope(file, focusRingCorners: ToolCallLocationChips.corners)
  }
}

#Preview("Location chips with the kit style") {
  let path = PreviewFixtures.projectDirectory.appending(path: PreviewFixtures.codeSampleFilename).path
  ToolCallLocationChips(locations: [
    ToolCallLocationChips.Location(path: path, line: nil, identifier: "preview-location-0")
  ])
  .toolCallLocationChipStyle(AgentLocationChipStyle())
  .padding()
}
