import CoreGraphics
import Testing

@testable import AgentViewKitStyle

/// Checks the value of the inspector form, with no view.
@Suite @MainActor struct InspectorFormTests {
  /// The height of an inspector preview that EditorKit `style.md` names.
  static let previewHeight: CGFloat = 240

  @Test func thePreviewHasTheHeightOfTheStyleGuide() {
    #expect(InspectorPreviewFrame.height == Self.previewHeight)
  }
}
