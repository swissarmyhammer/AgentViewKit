@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// The shared method of the tests that check that a view of the kit is on
/// the content surface (``SwiftUI/View/agentContentSurface()``), and not on
/// glass (D110 (b)).
///
/// A test shows the view over the backdrop of ``GlassRenderProbeTests`` in
/// an off-screen window, and reads the pixels with ``RenderedPixels``. It
/// does this one time with Reduce Transparency off and one time with it on
/// (the method of ^dbbyg9w).
///
/// The method reads the cache of the window, and not an `ImageRenderer`
/// render, because `ImageRenderer` does not draw a focusable view. The cache
/// of a window shows no glass (``GlassRenderProbeHostedTests``). Thus a view
/// on glass shows the backdrop, and only an opaque surface hides it.
enum ContentSurfaceHostedProbe {
  /// The two values of Reduce Transparency that each test shows the view
  /// with. It is `nonisolated` because the arguments of a test use it.
  nonisolated static let reduceTransparencyValues = [false, true]

  /// The pixels of `view` with the backdrop, in light mode, with only
  /// Reduce Transparency changed.
  ///
  /// - Parameters:
  ///   - view: The view on the surface.
  ///   - placement: Where the backdrop is.
  ///   - reducesTransparency: Whether Reduce Transparency is on.
  ///   - windowSize: The size of the content of the window.
  /// - Returns: The pixels.
  /// - Throws: An error when AppKit gives no pixels.
  static func pixels(
    of view: some View, backdrop placement: BackdropPlacement, reducesTransparency: Bool,
    size windowSize: CGSize
  ) throws -> RenderedPixels {
    let surface = SurfaceWithBackdrop(content: view, placement: placement)
    return try GlassRenderProbeHostedTests.cachedPixels(
      of: GlassRenderProbeTests.pinned(surface, with: .reduceTransparency, on: reducesTransparency),
      size: windowSize)
  }

  /// Checks that the backdrop shows only when it is in front of `view`.
  ///
  /// With the backdrop in front, the window must show the color of the
  /// backdrop. This is the control: it shows that the render can find the
  /// color. With the backdrop behind, no pixel of the color must show. Thus
  /// `view` is on an opaque surface, and not on glass.
  ///
  /// - Parameters:
  ///   - view: The view on the surface.
  ///   - placement: Where the backdrop is.
  ///   - reducesTransparency: Whether Reduce Transparency is on.
  ///   - windowSize: The size of the content of the window.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An error when AppKit gives no pixels.
  static func expectBackdropShowsOnlyInFront(
    of view: some View, backdrop placement: BackdropPlacement, reducesTransparency: Bool,
    size windowSize: CGSize, sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let rendered = try pixels(
      of: view, backdrop: placement, reducesTransparency: reducesTransparency, size: windowSize)
    let backdropShows = rendered.contains(GlassRenderProbeTests.backdrop)
    #expect(backdropShows == (placement == .inFront), "\(placement)", sourceLocation: sourceLocation)
  }
}

/// Where ``SurfaceWithBackdrop`` puts its backdrop.
enum BackdropPlacement {
  /// The backdrop is behind the view. Only a view that lets the backdrop
  /// through shows its color.
  case behind
  /// The backdrop is in front of the view. The window always shows its
  /// color.
  case inFront
}

/// A view with the backdrop of ``GlassRenderProbeTests`` in its frame.
///
/// The backdrop is inset by the large radius of the theme from each edge of
/// the view. Thus it is not in the corners, where the rounded shape of the
/// surface does not cover the frame. The backdrop is only at points that the
/// surface covers.
struct SurfaceWithBackdrop<Content: View>: View {
  /// The view on the surface.
  let content: Content

  /// Where the backdrop is.
  let placement: BackdropPlacement

  @Environment(\.agentTheme) private var theme

  var body: some View {
    switch placement {
    case .behind:
      content.background { backdrop }
    case .inFront:
      content.overlay { backdrop }
    }
  }

  /// The backdrop, inset by the large radius of the theme.
  private var backdrop: some View {
    GlassRenderProbeTests.backdrop.padding(theme.radii.l)
  }
}
