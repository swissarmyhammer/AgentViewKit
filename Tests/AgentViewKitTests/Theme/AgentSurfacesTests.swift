@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks the two shared surfaces of D110: ``SwiftUI/View/agentContentSurface(radius:)``
/// for content, and ``SwiftUI/View/agentFloatingGlass()`` for a floating
/// control. Also checks the edge of content with no fill of D113:
/// ``SwiftUI/View/agentContentEdge(radius:)``.
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

  /// The radii of ``AgentTheme/default`` that are smaller than its large
  /// radius: the small and the medium radius. The views of the kit use these
  /// radii with ``AgentSurface/shape(radius:)``.
  nonisolated static let smallerRadii = [AgentTheme.default.radii.s, AgentTheme.default.radii.m]

  /// A fill with no dynamic part that is not the backdrop of
  /// ``GlassRenderProbeTests`` and not the standard background.
  nonisolated static let surfaceFill = Color(red: 0.2, green: 0.6, blue: 0.3)

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

  /// Each radius token of ``AgentTheme/default``: the small, the medium and
  /// the large radius.
  nonisolated static let radiusTokens = smallerRadii + [AgentTheme.default.radii.l]

  /// The center of the render.
  static var centerPoint: CGPoint {
    CGPoint(x: size.width / 2, y: size.height / 2)
  }

  /// The points on the edge of the surface that the render tests read: the
  /// middle of each side. The separator stroke is on the edge, so it covers
  /// these points. The corner curve is not at these points.
  static var edgePoints: [CGPoint] {
    let near = surfaceInset
    let far = size.width - surfaceInset
    let center = size.width / 2
    return [
      CGPoint(x: center, y: near), CGPoint(x: center, y: far),
      CGPoint(x: near, y: center), CGPoint(x: far, y: center),
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

  /// A content surface with its standard fill over the backdrop.
  static var contentSurface: some View {
    OverBackdrop { Color.clear.agentContentSurface() }
  }

  /// A content edge over the backdrop.
  static var contentEdge: some View {
    OverBackdrop { Color.clear.agentContentEdge() }
  }

  @Test func theBackdropShowsAtEachPointWhenTheViewHasNoSurface() throws {
    let pixels = try Self.pixels(of: OverBackdrop { Color.clear })
    for point in Self.insidePoints {
      #expect(pixels.contains(GlassRenderProbeTests.backdrop, at: point))
    }
  }

  @Test func theContentSurfaceHidesTheBackdropAtEachPointInsideIt() throws {
    let pixels = try Self.pixels(of: Self.contentSurface)
    for point in Self.insidePoints {
      #expect(!pixels.contains(GlassRenderProbeTests.backdrop, at: point))
    }
  }

  @Test func theContentSurfaceHasNoGlassThatFollowsReduceTransparency() throws {
    let surface = Self.contentSurface
    let on = try Self.pixels(of: surface, reducesTransparency: true)
    let off = try Self.pixels(of: surface, reducesTransparency: false)
    #expect(on.isClose(to: off))
  }

  /// The floating glass of the kit over the backdrop, with no backdrop
  /// around it, in a `GlassEffectContainer`.
  ///
  /// - Parameter theme: The tokens that the glass gets from the environment.
  /// - Returns: The view to render.
  static func floatingGlass(in theme: AgentTheme = .default) -> some View {
    OverBackdrop(inset: 0) {
      GlassEffectContainer { Color.clear.agentFloatingGlass() }
    }
    .agentTheme(theme)
  }

  @Test func theFloatingGlassFollowsReduceTransparency() throws {
    let glass = Self.floatingGlass()
    let on = try Self.pixels(of: glass, reducesTransparency: true)
    let off = try Self.pixels(of: glass, reducesTransparency: false)
    #expect(on != off)
  }

  /// The floating glass is always `.regular` glass. The system applies the
  /// Clear look, so no material level of the theme changes the glass (D113).
  @Test(arguments: AgentTheme.MaterialLevel.allCases)
  func theFloatingGlassIsTheSameForEachMaterialLevel(level: AgentTheme.MaterialLevel) throws {
    var theme = AgentTheme.default
    theme.materialLevel = level
    let glass = try Self.pixels(of: Self.floatingGlass(in: theme))
    let regular = try Self.pixels(of: Self.floatingGlass())
    #expect(glass == regular)
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

  @Test(arguments: smallerRadii)
  func theShapeOfARadiusHasConcentricCornersWithThatRadiusAsTheMinimum(radius: CGFloat) {
    let shape = AgentSurface.shape(radius: radius)
    let concentric = ConcentricRectangle(
      corners: .concentric(minimum: .fixed(radius)), isUniform: true)
    let fixed = ConcentricRectangle(corners: .fixed(radius), isUniform: true)
    #expect(shape.animatableData == concentric.animatableData)
    #expect(shape.animatableData != fixed.animatableData)
  }

  @Test(arguments: smallerRadii)
  func theShapeOfARadiusWithNoContainerUsesThatRadius(radius: CGFloat) {
    let path = AgentSurface.shape(radius: radius).path(in: Self.pathRect)
    let largePath = AgentSurface.shape(for: .default).path(in: Self.pathRect)
    let expected = RoundedRectangle(cornerRadius: radius, style: .continuous)
    #expect(path == expected.path(in: Self.pathRect))
    #expect(path != largePath)
  }

  /// The content surface and the content edge use one expected path: the
  /// path of ``AgentSurface/shape(radius:)`` with the same radius.
  @Test(arguments: ContentShapeModifier.allCases, radiusTokens)
  func theContentModifierOfARadiusUsesTheShapeOfThatRadius(
    modifier: ContentShapeModifier, radius: CGFloat
  ) {
    let path = modifier.shape(radius: radius, in: .default).path(in: Self.pathRect)
    #expect(path == AgentSurface.shape(radius: radius).path(in: Self.pathRect))
  }

  /// The content surface and the content edge use one expected path: the
  /// path of ``AgentSurface/shape(for:)`` of a theme with a different large
  /// radius.
  @Test(arguments: ContentShapeModifier.allCases)
  func theContentModifierWithNoRadiusUsesTheLargeRadiusOfTheTheme(
    modifier: ContentShapeModifier
  ) {
    var theme = AgentTheme.default
    theme.radii.l = Self.otherLargeRadius
    let path = modifier.shape(radius: nil, in: theme).path(in: Self.pathRect)
    #expect(path == AgentSurface.shape(for: theme).path(in: Self.pathRect))
  }

  @Test func theContentSurfaceShowsItsFillAtEachPointInsideIt() throws {
    let pixels = try Self.pixels(
      of: OverBackdrop { Color.clear.agentContentSurface(Self.surfaceFill) })
    for point in Self.insidePoints {
      #expect(pixels.contains(Self.surfaceFill, at: point))
    }
  }

  @Test func theContentEdgeShowsTheBackdropAtItsCenter() throws {
    let pixels = try Self.pixels(of: Self.contentEdge)
    #expect(pixels.contains(GlassRenderProbeTests.backdrop, at: Self.centerPoint))
  }

  @Test func theContentEdgeDrawsAStrokeOnItsEdge() throws {
    let pixels = try Self.pixels(of: Self.contentEdge)
    let strokedPoints = Self.edgePoints.filter { !pixels.contains(GlassRenderProbeTests.backdrop, at: $0) }
    #expect(!strokedPoints.isEmpty)
  }
}

/// The content modifiers that have a shape: the content surface and the
/// content edge. The shape tests use each one, so that one test gives the
/// expected path for both.
enum ContentShapeModifier: CaseIterable, Sendable {
  /// ``AgentContentSurface``, with the standard fill.
  case surface

  /// ``AgentContentEdge``.
  case edge

  /// The shape that the modifier gives.
  ///
  /// - Parameters:
  ///   - radius: The radius token of the corners, or `nil` for the large
  ///     radius of `theme`.
  ///   - theme: The tokens that give the large radius.
  /// - Returns: The shape.
  @MainActor func shape(radius: CGFloat?, in theme: AgentTheme) -> ConcentricRectangle {
    switch self {
    case .surface:
      AgentContentSurface(fill: AnyShapeStyle(.background.secondary), radius: radius)
        .shape(in: theme)
    case .edge:
      AgentContentEdge(radius: radius).shape(in: theme)
    }
  }
}

/// A view over the backdrop of ``GlassRenderProbeTests``, with `inset` of
/// backdrop around it.
struct OverBackdrop<Surface: View>: View {
  /// The space between the edge of the render and the edge of ``surface``.
  var inset: CGFloat = AgentSurfacesTests.surfaceInset

  /// The view over the backdrop, for example a clear view with a content
  /// surface or a content edge.
  @ViewBuilder let surface: Surface

  var body: some View {
    ZStack {
      GlassRenderProbeTests.backdrop
      surface.padding(inset)
    }
  }
}
