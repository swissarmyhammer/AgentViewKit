@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks that the field of ``PromptInputView`` is on the floating glass of
/// the kit (D110 (c)).
///
/// The test uses the method of ^dbbyg9w (``GlassRenderProbeTests``): it
/// renders the full composer two times with ``RenderedPixels``, one time with
/// Reduce Transparency off and one time with it on, and compares the pixels.
///
/// The editor of the composer can take the VoiceOver focus, so
/// `ImageRenderer` does not draw it (``ContentEdgeHostedProbe``). But the
/// renderer draws the field glass around the editor. The field fills the
/// composer above the accessory row, so the center of the render is in the
/// field glass. The test compares the two renders only at ``fieldPoint``,
/// which is far from the edge of the glass. The rim of a rounded glass
/// changes after its first renders in the process, at a render that is not
/// the same in each run (``RenderedPixels/isClose(to:at:tolerance:)``).
@Suite @MainActor struct PromptInputGlassTests {
  /// The size of each render.
  static let size = CGSize(width: 320, height: 200)

  /// The center of the render. The point is in the field glass, far from
  /// each edge of the glass and from the accessory row.
  static var fieldPoint: CGPoint {
    CGPoint(x: size.width / 2, y: size.height / 2)
  }

  /// The composer over the backdrop of ``GlassRenderProbeTests``.
  static var composerOverBackdrop: some View {
    ZStack {
      GlassRenderProbeTests.backdrop
      PromptInputView(text: .constant(AttributedString())) {}
    }
  }

  @Test func theFieldOfTheComposerFollowsReduceTransparency() throws {
    let composer = Self.composerOverBackdrop
    let on = try GlassRenderProbeTests.pixels(
      of: composer, with: .reduceTransparency, on: true, size: Self.size)
    let off = try GlassRenderProbeTests.pixels(
      of: composer, with: .reduceTransparency, on: false, size: Self.size)
    #expect(!on.isClose(to: off, at: [Self.fieldPoint]))
  }
}
