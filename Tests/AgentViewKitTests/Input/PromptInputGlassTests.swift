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
/// not draw a focusable view (``ContentSurfaceHostedProbe``). The cache of a
/// window shows no glass (``GlassRenderProbeHostedTests``). Thus no render
/// can show the glass of the full composer, and the hosted frame test in
/// ``PromptInputViewHostedTests`` checks that the accessory is outside the
/// field.
@Suite @MainActor struct PromptInputGlassTests {
  @Test func theFieldSurfaceFollowsReduceTransparency() throws {
    let surface = FieldSurfaceOverBackdrop()
    let on = try GlassRenderProbeTests.pixels(of: surface, with: .reduceTransparency, on: true)
    let off = try GlassRenderProbeTests.pixels(of: surface, with: .reduceTransparency, on: false)
    #expect(on != off)
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
