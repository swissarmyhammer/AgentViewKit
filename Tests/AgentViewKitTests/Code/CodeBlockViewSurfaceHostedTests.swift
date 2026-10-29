@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks that a ``CodeBlockView`` has no fill, and that the separator stroke
/// of the content edge marks its edge (D113).
///
/// The tests use the edge check of ``ContentEdgeHostedProbe``. The check
/// reads the cache of the window, which draws the EditorKit editor. The
/// editor draws no background of its own, so the backdrop shows inside the
/// edge in the rows of the code and of the header. The header row has no
/// fill (D113). `EditorThemeViewsTests` checks the separator line under it.
@Suite(.serialized, .hostedSerially) @MainActor struct CodeBlockViewSurfaceHostedTests {
  /// The size of the window. The block fills the width and is shorter than
  /// the height.
  static let size = CGSize(width: 320, height: 160)

  /// The code block that the tests show.
  static var block: CodeBlockView {
    CodeBlockView(code: "let x = 1\nprint(x)", language: "swift")
  }

  @Test func theBackdropShowsInsideTheEdgeOfTheCodeBlock() async throws {
    try await ContentEdgeHostedProbe.expectBackdropShowsInsideTheEdge(of: Self.block, size: Self.size)
  }
}
