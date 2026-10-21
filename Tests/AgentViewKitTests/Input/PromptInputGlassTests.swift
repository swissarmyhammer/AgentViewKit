@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks that the field surface of ``PromptInputView``
/// (``PromptFieldSurface``) is on the floating glass of the kit (D110 (c)).
///
/// The test uses the method of ^dbbyg9w (``GlassRenderProbeTests``): it
/// renders the surface two times with ``RenderedPixels``, one time with
/// Reduce Transparency off and one time with it on, and compares the pixels.
///
/// The test renders the surface alone, and not the full composer. The
/// composer is a paste target, so it is focusable, and `ImageRenderer` does
/// not draw a focusable view (``ContentEdgeHostedProbe``). The cache of a
/// window shows no glass (``GlassRenderProbeHostedTests``). Thus no render
/// can show the glass of the full composer, and the hosted frame test in
/// ``PromptInputViewHostedTests`` checks that the accessory is outside the
/// field.
///
/// The test renders the surface at the size of ``AgentSurfacesTests``, and
/// compares the two renders only at ``AgentSurfacesTests/insidePoints``,
/// which are far from the edge of the glass. The rim of a rounded glass
/// changes after its first renders in the process, at a render that is not
/// the same in each run (``RenderedPixels/isClose(to:at:tolerance:)``).
@Suite @MainActor struct PromptInputGlassTests {
  @Test func theFieldSurfaceFollowsReduceTransparency() throws {
    let surface = FieldSurfaceOverBackdrop()
    let on = try AgentSurfacesTests.pixels(of: surface, reducesTransparency: true)
    let off = try AgentSurfacesTests.pixels(of: surface, reducesTransparency: false)
    #expect(!on.isClose(to: off, at: AgentSurfacesTests.insidePoints))
  }
}

/// A clear field on ``PromptFieldSurface`` that fills the view, over the
/// backdrop of ``GlassRenderProbeTests``, in a `GlassEffectContainer`.
struct FieldSurfaceOverBackdrop: View {
  var body: some View {
    ZStack {
      GlassRenderProbeTests.backdrop
      GlassEffectContainer {
        Color.clear.modifier(PromptFieldSurface())
      }
    }
  }
}
