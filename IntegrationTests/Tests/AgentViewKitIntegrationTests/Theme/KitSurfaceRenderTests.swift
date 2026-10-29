@testable import AgentViewKit
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

/// Checks the two surfaces that the kit takes from the EditorKit
/// `EditorStyle` target, as a real window shows them: the floating glass of a
/// floating control (D110, `.floatingGlass()`), and the edge of content with
/// no fill (D113, `.inlineEdge(radius:)` with no `.inlineFill(_:)`).
///
/// The tests use the method of ^dbbyg9w (``GlassRenderProbeTests``): each
/// test shows a view in a real window in the Light appearance, captures the
/// window from the window server, and reads the pixels, or compares them
/// with the pixels of a different view.
@Suite(.serialized, .hostedSerially) @MainActor struct KitSurfaceRenderTests {
  /// The size that the tests capture at.
  static let size = CGSize(width: 80, height: 80)

  /// The space between the edge of the window and the edge of the surface.
  static let surfaceInset: CGFloat = 10

  /// The points inside the surface that the tests read: the center, and one
  /// point near each corner, one large radius in from each edge of the
  /// surface. The corner curve and the separator stroke are not at these
  /// points.
  static var insidePoints: [CGPoint] {
    GlassRenderProbeTests.interiorPoints(
      of: size, inset: surfaceInset + EditorStyle.default.radii.l)
  }

  /// The center of the window.
  static var centerPoint: CGPoint {
    CGPoint(x: size.width / 2, y: size.height / 2)
  }

  /// The points on the edge of the surface that the tests read: the middle
  /// of each side. The separator stroke is on the edge, so it covers these
  /// points. The corner curve is not at these points.
  static var edgePoints: [CGPoint] {
    let near = surfaceInset
    let far = size.width - surfaceInset
    let center = size.width / 2
    return [
      CGPoint(x: center, y: near), CGPoint(x: center, y: far),
      CGPoint(x: near, y: center), CGPoint(x: far, y: center),
    ]
  }

  /// The capture of `view` at ``size``, in the Light appearance.
  ///
  /// - Parameter view: The view to show.
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func capture(of view: some View) async throws -> CapturedImage {
    try await GlassRenderProbeTests.capture(of: view, size: size)
  }

  /// Whether `image` and `other` hold the same pixel at `point`.
  ///
  /// - Parameters:
  ///   - image: One capture.
  ///   - other: A capture of the same size.
  ///   - point: A point of the view, in points from its top leading corner.
  /// - Returns: `true` when the two pixels are equal.
  /// - Throws: A `CapturedImageError` when the point is outside an image.
  static func samePixel(in image: CapturedImage, and other: CapturedImage, at point: CGPoint) throws -> Bool {
    let pixel = CaptureGeometry.pixel(at: point)
    let region = CGRect(x: pixel.x, y: pixel.y, width: 1, height: 1)
    return try image.cropped(to: region) == other.cropped(to: region)
  }

  /// A content edge of a card over the backdrop: the large radius of the
  /// default style, with no fill.
  static var contentEdge: some View {
    OverBackdrop { Color.clear.inlineEdge(radius: EditorStyle.default.radii.l) }
  }

  @Test func theBackdropShowsAtEachPointWhenTheViewHasNoSurface() async throws {
    let image = try await Self.capture(of: OverBackdrop { Color.clear })
    for point in Self.insidePoints {
      #expect(try GlassRenderProbeTests.showsBackdrop(image, at: point), "\(point)")
    }
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
  /// - Returns: The view to show.
  static func glass(_ variant: Glass) -> some View {
    glassOverBackdrop {
      Color.clear.glassEffect(variant, in: EditorSurface.shape(radius: EditorStyle.default.radii.l))
    }
  }

  /// `glass` over the backdrop, with no backdrop around it, in a
  /// `GlassEffectContainer`.
  ///
  /// - Parameter glass: The view with the glass.
  /// - Returns: The view to show.
  static func glassOverBackdrop(@ViewBuilder _ glass: () -> some View) -> some View {
    OverBackdrop(inset: 0) {
      GlassEffectContainer { glass() }
    }
  }

  /// The floating glass is always `.regular` glass. The system applies the
  /// Clear look and the Tinted look, so no token of the style selects the
  /// glass variant (D113 answer 3).
  ///
  /// The window server draws one glass the same way each time, so the
  /// capture of the floating glass holds the pixels of a `.regular` glass in
  /// the same shape, each pixel of the rim included.
  /// ``aClearGlassIsDifferentFromTheFloatingGlassInsideTheEdge()`` shows that
  /// the comparison finds a different glass.
  @Test func theFloatingGlassIsTheRegularGlass() async throws {
    let floating = try await Self.capture(of: Self.floatingGlass)
    let regular = try await Self.capture(of: Self.glass(.regular))

    #expect(floating == regular)
  }

  /// The comparison of ``theFloatingGlassIsTheRegularGlass()`` finds a glass
  /// that is not the floating glass: a `.clear` glass in the same shape, which
  /// differs from it at a point far from the edge of the glass.
  @Test func aClearGlassIsDifferentFromTheFloatingGlassInsideTheEdge() async throws {
    let clear = try await Self.capture(of: Self.glass(.clear))
    let floating = try await Self.capture(of: Self.floatingGlass)

    #expect(clear != floating)
    #expect(try Self.insidePoints.contains { try !Self.samePixel(in: clear, and: floating, at: $0) })
  }

  @Test func theContentEdgeShowsTheBackdropAtItsCenter() async throws {
    let image = try await Self.capture(of: Self.contentEdge)
    #expect(try GlassRenderProbeTests.showsBackdrop(image, at: Self.centerPoint))
  }

  @Test func theContentEdgeDrawsAStrokeOnItsEdge() async throws {
    let image = try await Self.capture(of: Self.contentEdge)
    let strokedPoints = try Self.edgePoints.filter { try !GlassRenderProbeTests.showsBackdrop(image, at: $0) }
    #expect(!strokedPoints.isEmpty)
  }
}

/// A view over the backdrop of ``GlassRenderProbeTests``, with `inset` of
/// backdrop around it.
struct OverBackdrop<Surface: View>: View {
  /// The space between the edge of the window and the edge of ``surface``.
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
