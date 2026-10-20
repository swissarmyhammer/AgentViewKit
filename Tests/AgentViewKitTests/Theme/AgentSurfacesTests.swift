@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks the two shared surfaces of D110: ``SwiftUI/View/agentContentSurface()``
/// for content, and ``SwiftUI/View/agentFloatingGlass()`` for a floating
/// control.
///
/// The render tests use the method of ^dbbyg9w (``GlassRenderProbeTests``):
/// each test renders a view two times, one time with a setting off and one
/// time with the setting on, and compares the pixels.
@Suite @MainActor struct AgentSurfacesTests {
  /// The size that the tests render at.
  static let size = CGSize(width: 80, height: 80)

  /// The space between the edge of the render and the edge of the surface.
  static let surfaceInset: CGFloat = 10

  /// A large radius that is different from the large radius of
  /// ``AgentTheme/default``.
  static let otherLargeRadius: CGFloat = 24

  /// The rectangle that the shape tests make a path in.
  static let pathRect = CGRect(x: 0, y: 0, width: 100, height: 60)

  /// The points inside the surface that the render tests read: the center,
  /// and one point near each corner, one large radius in from each edge of
  /// the surface. The corner curve and the separator stroke are not at these
  /// points.
  static var insidePoints: [CGPoint] {
    let near = surfaceInset + AgentTheme.default.radii.l
    let far = size.width - near
    let center = size.width / 2
    return [
      CGPoint(x: center, y: center),
      CGPoint(x: near, y: near), CGPoint(x: far, y: near),
      CGPoint(x: near, y: far), CGPoint(x: far, y: far),
    ]
  }

  /// The pixels of `view` at ``size``, in light mode, with only Reduce
  /// Transparency changed.
  ///
  /// - Parameters:
  ///   - view: The view to render.
  ///   - reducesTransparency: Whether Reduce Transparency is on.
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels.
  static func pixels(of view: some View, reducesTransparency: Bool = false) throws
    -> RenderedPixels
  {
    try GlassRenderProbeTests.pixels(
      of: view, with: .reduceTransparency, on: reducesTransparency, size: size)
  }

  @Test func theBackdropShowsAtEachPointWhenTheViewHasNoSurface() throws {
    let pixels = try Self.pixels(of: ContentSurfaceOverBackdrop(hasSurface: false))
    for point in Self.insidePoints {
      #expect(pixels.contains(GlassRenderProbeTests.backdrop, at: point))
    }
  }

  @Test func theContentSurfaceHidesTheBackdropAtEachPointInsideIt() throws {
    let pixels = try Self.pixels(of: ContentSurfaceOverBackdrop(hasSurface: true))
    for point in Self.insidePoints {
      #expect(!pixels.contains(GlassRenderProbeTests.backdrop, at: point))
    }
  }

  @Test func theContentSurfaceHasNoGlassThatFollowsReduceTransparency() throws {
    let surface = ContentSurfaceOverBackdrop(hasSurface: true)
    let on = try Self.pixels(of: surface, reducesTransparency: true)
    let off = try Self.pixels(of: surface, reducesTransparency: false)
    #expect(on == off)
  }

  @Test func theFloatingGlassFollowsReduceTransparency() throws {
    let glass = FloatingGlassOverBackdrop()
    let on = try Self.pixels(of: glass, reducesTransparency: true)
    let off = try Self.pixels(of: glass, reducesTransparency: false)
    #expect(on != off)
  }

  @Test func theShapeHasConcentricCornersWithTheLargeRadiusAsTheMinimum() {
    let theme = AgentTheme.default
    let shape = AgentSurface.shape(for: theme)
    let concentric = ConcentricRectangle(
      corners: .concentric(minimum: .fixed(theme.radii.l)), isUniform: true)
    let fixed = ConcentricRectangle(corners: .fixed(theme.radii.l), isUniform: true)
    #expect(shape.animatableData == concentric.animatableData)
    #expect(shape.animatableData != fixed.animatableData)
  }

  @Test func theShapeWithNoContainerUsesTheLargeRadiusOfTheTheme() {
    let theme = AgentTheme.default
    let path = AgentSurface.shape(for: theme).path(in: Self.pathRect)
    let expected = RoundedRectangle(cornerRadius: theme.radii.l, style: .continuous)
    #expect(path == expected.path(in: Self.pathRect))
  }

  @Test func aThemeWithADifferentLargeRadiusGivesADifferentFallbackRadius() {
    var theme = AgentTheme.default
    theme.radii.l = Self.otherLargeRadius
    let path = AgentSurface.shape(for: theme).path(in: Self.pathRect)
    let defaultPath = AgentSurface.shape(for: .default).path(in: Self.pathRect)
    let expected = RoundedRectangle(cornerRadius: Self.otherLargeRadius, style: .continuous)
    #expect(path == expected.path(in: Self.pathRect))
    #expect(path != defaultPath)
  }
}

/// A content surface inside the backdrop of ``GlassRenderProbeTests``, with
/// ``AgentSurfacesTests/surfaceInset`` of backdrop around it.
struct ContentSurfaceOverBackdrop: View {
  /// Whether the view has the surface. When it is `false`, the view shows
  /// only the backdrop.
  let hasSurface: Bool

  var body: some View {
    ZStack {
      GlassRenderProbeTests.backdrop
      if hasSurface {
        Color.clear
          .agentContentSurface()
          .padding(AgentSurfacesTests.surfaceInset)
      }
    }
  }
}

/// A floating glass that fills the view, over the backdrop of
/// ``GlassRenderProbeTests``, in a `GlassEffectContainer`.
struct FloatingGlassOverBackdrop: View {
  var body: some View {
    ZStack {
      GlassRenderProbeTests.backdrop
      GlassEffectContainer {
        Color.clear.agentFloatingGlass()
      }
    }
  }
}
