@testable import AgentViewKit
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

/// The shared method of the tests that check the edge of a view of the kit
/// in content.
/// ``expectBackdropShowsInsideTheEdge(of:size:sourceLocation:)`` checks that
/// the view has no fill, and that the separator stroke of the content edge
/// (`.inlineEdge(radius:)`) marks its edge (D113).
///
/// A test shows the view over the backdrop of ``GlassRenderProbeTests`` in a
/// real window on the screen, in the Light appearance, and reads the capture
/// of the window from the window server (the method of ^dbbyg9w). The window
/// server draws each view as the app shows it: the AppKit views, such as the
/// EditorKit editor of a code block, the views that can take the VoiceOver
/// focus, such as each card of ``RequestDeck``, and Liquid Glass. A view on
/// glass has no separator stroke, so the edge check finds no edge.
/// `GlassPlacementTests` reads the source, and keeps the glass in the files
/// that can use it.
enum ContentEdgeHostedProbe {
  /// The distance from the leading edge of the window to the point that the
  /// edge check reads on the separator stroke, in points.
  ///
  /// The view fills the width of the window, so its edge is at the leading
  /// edge of the window. The stroke is one point wide and is centered on the
  /// edge, so it covers the first half point. The point is in the first pixel
  /// of a capture.
  static let strokeOffset: CGFloat = 0.25

  /// The distance from the leading edge of the window to the point that the
  /// edge check reads inside the view, in points.
  ///
  /// The point is one point inside the separator stroke, so the stroke does
  /// not touch its pixel. The padding of the view is wider, so no content of
  /// the view is at the point.
  static let insideOffset: CGFloat = 1.5

  /// The distance between two rows that the edge check reads, in points: one
  /// pixel of a capture.
  static var rowStep: CGFloat { 1 / CaptureGeometry.scale }

  /// The capture of `view` with the backdrop, in the Light appearance.
  ///
  /// - Parameters:
  ///   - view: The view to show over the backdrop.
  ///   - placement: Where the backdrop is.
  ///   - windowSize: The size of the content of the window.
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func capture(
    of view: some View, backdrop placement: BackdropPlacement, size windowSize: CGSize
  ) async throws -> CapturedImage {
    try await GlassRenderProbeTests.capture(
      of: SurfaceWithBackdrop(content: view, placement: placement), size: windowSize)
  }

  /// Checks that `view` has no fill, and that a separator stroke marks its
  /// leading edge (D113).
  ///
  /// The backdrop fills the frame of `view`, behind it. The check reads the
  /// rows of the window. It expects one row at least where the point on the
  /// edge does not show the backdrop, and the point inside the edge shows
  /// it. Only a stroke on the edge of a view with no fill gives such a row:
  ///
  /// - A fill hides the backdrop at the point inside the edge.
  /// - With no stroke, the backdrop shows at the point on the edge.
  /// - Above and below the view, the window shows no backdrop at either
  ///   point.
  ///
  /// - Parameters:
  ///   - view: The view with the content edge. It must fill the width of the
  ///     window.
  ///   - windowSize: The size of the content of the window.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func expectBackdropShowsInsideTheEdge(
    of view: some View, size windowSize: CGSize, sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    let image = try await capture(of: view, backdrop: .behindToTheEdge, size: windowSize)
    let rows = stride(from: 0, to: windowSize.height, by: rowStep)
    let edgeShows = try rows.contains { row in
      try showsTheEdge(in: image, atRow: row)
    }
    #expect(edgeShows, "No row shows the edge with the backdrop inside it", sourceLocation: sourceLocation)
  }

  /// Whether the row at `row` of `image` shows a separator stroke on the
  /// leading edge of a view with no fill, over the backdrop of
  /// ``GlassRenderProbeTests``.
  ///
  /// - Parameters:
  ///   - image: The capture of a view over the backdrop.
  ///   - row: The distance of the row from the top of the window, in points.
  /// - Returns: `true` when the point on the edge does not show the backdrop,
  ///   and the point inside the edge shows it.
  /// - Throws: `CapturedImageError.pixelsUnreadable` when the color has no
  ///   sRGB form.
  private static func showsTheEdge(in image: CapturedImage, atRow row: CGFloat) throws -> Bool {
    let onTheEdge = CGPoint(x: strokeOffset, y: row)
    let insideTheEdge = CGPoint(x: insideOffset, y: row)
    return try !GlassRenderProbeTests.showsBackdrop(image, at: onTheEdge)
      && GlassRenderProbeTests.showsBackdrop(image, at: insideTheEdge)
  }
}

/// Where ``SurfaceWithBackdrop`` puts its backdrop.
enum BackdropPlacement {
  /// The backdrop is behind the view. Only a view that lets the backdrop
  /// through shows its color.
  case behind
  /// The backdrop is behind the view and fills its full frame, with no
  /// inset. A view with no fill shows it, and a stroke on the edge of the
  /// view covers it.
  case behindToTheEdge
}

/// A view with the backdrop of ``GlassRenderProbeTests`` in its frame.
///
/// For ``BackdropPlacement/behind``, the backdrop is inset by the large
/// radius of the style from each edge of the view. Thus it is not in the
/// corners, where the rounded shape of the view does not cover the frame.
/// The backdrop is only at points that the view covers. For
/// ``BackdropPlacement/behindToTheEdge``, the backdrop has no inset.
struct SurfaceWithBackdrop<Content: View>: View {
  /// The view to show over the backdrop.
  let content: Content

  /// Where the backdrop is.
  let placement: BackdropPlacement

  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    switch placement {
    case .behind:
      content.background { backdrop }
    case .behindToTheEdge:
      content.background { GlassRenderProbeTests.backdrop }
    }
  }

  /// The backdrop, inset by the large radius of the style.
  private var backdrop: some View {
    GlassRenderProbeTests.backdrop.padding(editorStyle.radii.l)
  }
}
