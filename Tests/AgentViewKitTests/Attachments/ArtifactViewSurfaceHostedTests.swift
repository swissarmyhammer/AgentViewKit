@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// Checks that the panel of ``ArtifactView`` has no fill and no glass, and
/// that the separator stroke of the content edge marks its edge (D113). The
/// panel is content in the thread.
///
/// The tests use the edge check of ``ContentSurfaceHostedProbe``. They show
/// an artifact with inline text, because an artifact with a URL needs a file
/// on the disk.
@Suite(.serialized, .hostedSerially) @MainActor struct ArtifactViewSurfaceHostedTests {
  /// The size of the window. The panel fills the width and is shorter than
  /// the height.
  static let size = CGSize(width: 360, height: 200)

  /// The panel of an artifact with a title and inline text.
  static var panel: ArtifactView {
    ArtifactView(
      artifact: ArtifactPayload(
        id: "tests-artifact", title: "Notes", type: UTType.plainText.identifier,
        inlineText: "Step one"))
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsInsideTheEdgeOfThePanel(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsInsideTheEdge(
      of: Self.panel, reducesTransparency: reducesTransparency, size: Self.size)
  }
}
