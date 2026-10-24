@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorStyle
import SwiftUI
import Testing

/// Checks the two surfaces that the kit takes from the EditorKit
/// `EditorStyle` target, as the kit renders them: the floating glass of a
/// floating control (D110, `.floatingGlass()`), and the edge of content with
/// no fill (D113, `.inlineEdge(radius:)` with no `.inlineFill(_:)`).
///
/// The render tests use the method of ^dbbyg9w (``GlassRenderProbeTests``):
/// each test renders a view two times, one time with a setting off and one
/// time with the setting on, and compares the pixels.
@Suite @MainActor struct KitSurfaceRenderTests {
  /// The size that the tests render at.
  static let size = CGSize(width: 80, height: 80)

  /// The space between the edge of the render and the edge of the surface.
  static let surfaceInset: CGFloat = 10

  /// The points inside the surface that the render tests read: the center,
  /// and one point near each corner, one large radius in from each edge of
  /// the surface. The corner curve and the separator stroke are not at these
  /// points.
  static var insidePoints: [CGPoint] {
    GlassRenderProbeTests.interiorPoints(
      of: size, inset: surfaceInset + EditorStyle.default.radii.l)
  }

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

  /// A content edge of a card over the backdrop: the large radius of the
  /// default style, with no fill.
  static var contentEdge: some View {
    OverBackdrop { Color.clear.inlineEdge(radius: EditorStyle.default.radii.l) }
  }

  @Test func theBackdropShowsAtEachPointWhenTheViewHasNoSurface() throws {
    let pixels = try Self.pixels(of: OverBackdrop { Color.clear })
    for point in Self.insidePoints {
      #expect(pixels.contains(GlassRenderProbeTests.backdrop, at: point))
    }
  }

  @Test func theContentEdgeHasNoGlassThatFollowsReduceTransparency() throws {
    let edge = Self.contentEdge
    let on = try Self.pixels(of: edge, reducesTransparency: true)
    let off = try Self.pixels(of: edge, reducesTransparency: false)
    #expect(on.isClose(to: off))
  }

  /// The floating glass of the kit over the backdrop, with no backdrop
  /// around it, in a `GlassEffectContainer`.
  static var floatingGlass: some View {
    glassOverBackdrop { Color.clear.floatingGlass() }
  }

  /// A glass of `variant` in the shape of the floating glass, over the
  /// backdrop in the same layout as ``floatingGlass``.
  ///
  /// - Parameter variant: The glass, for example `.regular` or `.clear`.
  /// - Returns: The view to render.
  static func glass(_ variant: Glass) -> some View {
    glassOverBackdrop {
      Color.clear.glassEffect(variant, in: EditorSurface.shape(radius: EditorStyle.default.radii.l))
    }
  }

  /// `glass` over the backdrop, with no backdrop around it, in a
  /// `GlassEffectContainer`.
  ///
  /// - Parameter glass: The view with the glass.
  /// - Returns: The view to render.
  static func glassOverBackdrop(@ViewBuilder _ glass: () -> some View) -> some View {
    OverBackdrop(inset: 0) {
      GlassEffectContainer { glass() }
    }
  }

  /// The distance from the edge of the floating glass in which its rim
  /// changes after its first renders in the process
  /// (``RenderedPixels/isClose(to:at:tolerance:)``).
  static let rimWidth: CGFloat = 2

  /// Each pixel of the floating glass that is more than ``rimWidth`` from
  /// its edge. The region is the shape of the glass, inset by ``rimWidth``.
  /// Its corners have the radius of the glass, so each point of a corner is
  /// at least ``rimWidth`` from the corner of the glass.
  static var insideTheRim: Path {
    EditorSurface.fallbackShape(radius: EditorStyle.default.radii.l)
      .path(in: CGRect(origin: .zero, size: size).insetBy(dx: rimWidth, dy: rimWidth))
  }

  /// The largest change of one byte between two renders of one glass, in
  /// levels, more than ``rimWidth`` from its edge: one level
  /// (``RenderedPixels/isClose(to:at:tolerance:)``), and half a level more.
  /// The half level keeps a one-level change in the tolerance when the
  /// division of a byte to a component from 0 to 1 rounds.
  static let insideTheRimLevels = 1.5

  /// The number of levels from 0 to 1 in one color component of a byte.
  static let levelsInAComponent = 255.0

  /// The tolerance of the comparison in ``insideTheRim``: ``insideTheRimLevels``
  /// as a part of a component from 0 to 1.
  static var insideTheRimTolerance: Double {
    insideTheRimLevels / levelsInAComponent
  }

  /// The test compares the two renders only at ``insidePoints``, which are
  /// far from the edge of the glass. The rim of a rounded glass changes after
  /// its first renders in the process, at a render that is not the same in
  /// each run (``RenderedPixels/isClose(to:at:tolerance:)``). Thus two full
  /// renders can be different when Reduce Transparency has no effect on the
  /// glass.
  @Test func theFloatingGlassFollowsReduceTransparency() throws {
    try GlassRenderProbeTests.expectDifferentPixels(
      of: Self.floatingGlass, with: .reduceTransparency, at: Self.insidePoints, size: Self.size)
  }

  /// The floating glass is always `.regular` glass. The system applies the
  /// Clear look and the Tinted look, so no token of the style selects the
  /// glass variant (D113 answer 3).
  ///
  /// The test compares the two renders only at ``insidePoints``, which are
  /// far from the edge of the glass. The rim of a rounded glass changes after
  /// its first renders in the process, at a render that is not the same in
  /// each run (``RenderedPixels/isClose(to:at:tolerance:)``).
  /// ``aClearGlassIsDifferentFromTheFloatingGlassInsideTheEdge()`` shows that
  /// these points find a different glass.
  @Test func theFloatingGlassIsTheRegularGlassInsideTheEdge() throws {
    let (floating, regular) = try Self.floatingAndRegularGlassPixels()
    #expect(floating.isClose(to: regular, at: Self.insidePoints))
  }

  /// The same check as ``theFloatingGlassIsTheRegularGlassInsideTheEdge()``
  /// at each pixel of ``insideTheRim``, not only at ``insidePoints``. The
  /// pixels in ``rimWidth`` of the edge are not compared, because the rim
  /// changes after the first renders in the process.
  @Test func eachPixelOfTheFloatingGlassInsideTheRimIsTheRegularGlass() throws {
    let (floating, regular) = try Self.floatingAndRegularGlassPixels()
    #expect(
      floating.isClose(to: regular, within: Self.insideTheRim, tolerance: Self.insideTheRimTolerance))
  }

  /// The two comparisons of the regular-glass tests find a glass that is not
  /// the floating glass: a `.clear` glass in the same shape.
  @Test func aClearGlassIsDifferentFromTheFloatingGlassInsideTheEdge() throws {
    let clear = try Self.pixels(of: Self.glass(.clear))
    let floating = try Self.pixels(of: Self.floatingGlass)
    #expect(!clear.isClose(to: floating, at: Self.insidePoints))
    #expect(
      !clear.isClose(to: floating, within: Self.insideTheRim, tolerance: Self.insideTheRimTolerance))
  }

  /// The pixels of the floating glass, and the pixels of a `.regular` glass
  /// in the same shape.
  ///
  /// - Returns: The two renders, in that order.
  /// - Throws: An error when the renderer gives no pixels.
  static func floatingAndRegularGlassPixels() throws
    -> (floating: RenderedPixels, regular: RenderedPixels)
  {
    let floating = try pixels(of: floatingGlass)
    let regular = try pixels(of: glass(.regular))
    return (floating, regular)
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

/// A view over the backdrop of ``GlassRenderProbeTests``, with `inset` of
/// backdrop around it.
struct OverBackdrop<Surface: View>: View {
  /// The space between the edge of the render and the edge of ``surface``.
  var inset: CGFloat = KitSurfaceRenderTests.surfaceInset

  /// The view over the backdrop, for example a clear view with a content
  /// edge or a floating glass.
  @ViewBuilder let surface: Surface

  var body: some View {
    ZStack {
      GlassRenderProbeTests.backdrop
      surface.padding(inset)
    }
  }
}
