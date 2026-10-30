import EditorTestSupport
import SwiftUI
import Testing

/// The facts about Liquid Glass in a real window that the AVK-8a decision
/// uses (^dbbyg9w, D110 (f)).
///
/// A test of a glass view shows the view in a real window on the screen,
/// captures it from the window server (EditorKit `CapturedImage`, `style.md`
/// rule 9), and compares the pixels. SwiftUI has no API for the Tinted look
/// of the system, so a kit environment value selects the look, and a test
/// compares `Glass` values and pixels. The tests capture the Light
/// appearance only: the system settings are not test looks (EditorKit
/// `style.md` rule 9).
///
/// When a fact changes in a new SDK, a test here fails. Then do the decision
/// again.
@Suite(.serialized, .hostedSerially) @MainActor struct GlassRenderProbeTests {
  /// The size that the tests capture at.
  static let size = CGSize(width: 40, height: 40)

  /// The center of a square capture, and one point near each corner, `inset`
  /// in from each edge of the capture.
  ///
  /// - Parameters:
  ///   - captureSize: The size of the square capture.
  ///   - inset: The distance from each edge of the capture to the points near
  ///     the corners.
  /// - Returns: The center first, then the points near the corners.
  static func interiorPoints(of captureSize: CGSize, inset: CGFloat) -> [CGPoint] {
    let far = captureSize.width - inset
    let center = captureSize.width / 2
    return [
      CGPoint(x: center, y: center),
      CGPoint(x: inset, y: inset), CGPoint(x: far, y: inset),
      CGPoint(x: inset, y: far), CGPoint(x: far, y: far),
    ]
  }

  /// The color under the glass. No other part of the probe draws it. It is
  /// `nonisolated` because the arguments of a test use it.
  nonisolated static let backdrop = Color(red: 0.9, green: 0.1, blue: 0.3)

  /// The tint of the tinted glass. No other part of the probe draws it. It
  /// is `nonisolated` because the arguments of a test use it.
  nonisolated static let tint = Color(red: 0.1, green: 0.3, blue: 0.9)

  /// The capture of `view` in a real window in the Light appearance.
  ///
  /// - Parameters:
  ///   - view: The view to show.
  ///   - captureSize: The size to show it at.
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func capture(of view: some View, size captureSize: CGSize = size) async throws -> CapturedImage {
    try await CapturedImage(showing: view, size: captureSize)
  }

  /// Whether the pixel of `image` at `point` shows ``backdrop``.
  ///
  /// - Parameters:
  ///   - image: The capture.
  ///   - point: A point of the view, in points from its top leading corner.
  /// - Returns: `true` when the pixel shows the backdrop.
  /// - Throws: `CapturedImageError.pixelsUnreadable` when the color has no
  ///   sRGB form.
  static func showsBackdrop(_ image: CapturedImage, at point: CGPoint) throws -> Bool {
    let pixel = CaptureGeometry.pixel(at: point)
    return try image.shows(CaptureGeometry.cgColor(of: backdrop), atX: pixel.x, y: pixel.y)
  }

  @Test func aTintedGlassDrawsDifferentPixelsFromAnUntintedGlass() async throws {
    let tinted = try await Self.capture(of: GlassOverBackdrop(glass: .regular.tint(Self.tint)))
    let untinted = try await Self.capture(of: GlassOverBackdrop(glass: .regular))
    #expect(tinted != untinted)
  }

  @Test func twoGlassesWithTheSameTintAreEqual() {
    #expect(Glass.regular.tint(Self.tint) == Glass.regular.tint(Self.tint))
  }

  @Test(arguments: [Glass.regular, .regular.tint(backdrop), .clear.tint(tint)])
  func aTintedGlassIsNotEqualToADifferentGlass(_ other: Glass) {
    #expect(Glass.regular.tint(Self.tint) != other)
  }
}

/// A glass that fills the view, over a backdrop of one unique color.
struct GlassOverBackdrop: View {
  /// The glass, or `nil` for the backdrop with no glass.
  let glass: Glass?

  var body: some View {
    ZStack {
      GlassRenderProbeTests.backdrop
      if let glass {
        Color.clear.glassEffect(glass, in: .rect)
      }
    }
  }
}
