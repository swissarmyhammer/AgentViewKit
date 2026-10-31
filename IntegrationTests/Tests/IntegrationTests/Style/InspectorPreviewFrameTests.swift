import AgentViewKitStyle
import SwiftUI
import Testing

/// Checks the frame of an inspector preview through its public API.
@Suite @MainActor struct InspectorPreviewFrameTests {
  /// The height of an inspector preview that EditorKit `style.md` names.
  static let previewHeight: CGFloat = 240

  @Test func thePreviewTakesTheFixedHeight() {
    let size = StyleViewHost.fittingSize(of: Text(verbatim: "Preview").inspectorPreviewFrame())

    #expect(size.height == Self.previewHeight)
  }
}
