@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// Checks that the panel of ``ArtifactView`` has no fill and no glass, and
/// that the separator stroke of the content edge marks its edge (D113). The
/// panel is content in the thread.
///
/// The tests use the edge check of ``ContentEdgeHostedProbe``. They show
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

  @Test func theBackdropShowsInsideTheEdgeOfThePanel() throws {
    try ContentEdgeHostedProbe.expectBackdropShowsInsideTheEdge(of: Self.panel, size: Self.size)
  }
}
