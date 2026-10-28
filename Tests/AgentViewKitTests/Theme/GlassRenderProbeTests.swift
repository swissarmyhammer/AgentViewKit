import AgentViewKitTestSupport
import SwiftUI
import Testing

/// The facts about Liquid Glass in a test process that the AVK-8a decision
/// uses (^dbbyg9w, D110 (f)).
///
/// A test of a glass view renders the view with ``RenderedPixels`` and
/// compares the pixels. SwiftUI has no API for the Tinted look of the
/// system, so a kit environment value selects the look, and a test compares
/// `Glass` values and pixels. The tests render in light mode only: the
/// system settings are not test variants (EditorKit `style.md` rule 9).
///
/// Each render sets light mode first, so that the appearance of the computer
/// does not change the result. When a fact changes in a new SDK, a test here
/// fails. Then do the decision again.
@Suite @MainActor struct GlassRenderProbeTests {
  /// The size that the tests render at.
  static let size = CGSize(width: 40, height: 40)

  /// The center of a square render, and one point near each corner, `inset`
  /// in from each edge of the render.
  ///
  /// - Parameters:
  ///   - renderSize: The size of the square render.
  ///   - inset: The distance from each edge of the render to the points near
  ///     the corners.
  /// - Returns: The center first, then the points near the corners.
  static func interiorPoints(of renderSize: CGSize, inset: CGFloat) -> [CGPoint] {
    let far = renderSize.width - inset
    let center = renderSize.width / 2
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

  /// The pixels of `view` in light mode.
  ///
  /// - Parameters:
  ///   - view: The view to render.
  ///   - renderSize: The size to render at.
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels.
  static func pixels(of view: some View, size renderSize: CGSize = size) throws -> RenderedPixels {
    try #require(RenderedPixels(rendering: pinned(view), size: renderSize))
  }

  /// `view` in light mode.
  ///
  /// - Parameter view: The view to change.
  /// - Returns: The view with light mode.
  static func pinned(_ view: some View) -> some View {
    view.environment(\.colorScheme, .light)
  }

  @Test func aTintedGlassDrawsDifferentPixelsFromAnUntintedGlass() throws {
    let tinted = try Self.pixels(of: GlassOverBackdrop(glass: .regular.tint(Self.tint)))
    let untinted = try Self.pixels(of: GlassOverBackdrop(glass: .regular))
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

/// The facts about Liquid Glass in a window of the test process.
@Suite(.serialized, .hostedSerially) @MainActor struct GlassRenderProbeHostedTests {
  @Test func theCachedDisplayOfAWindowShowsNoGlass() throws {
    let withGlass = try Self.cachedPixels(of: GlassOverBackdrop(glass: .regular))
    let withoutGlass = try Self.cachedPixels(of: GlassOverBackdrop(glass: nil))
    #expect(withGlass == withoutGlass)
  }

  /// The pixels that AppKit caches for `view` in an off-screen window.
  ///
  /// - Parameters:
  ///   - view: The view to show.
  ///   - windowSize: The size of the content of the window.
  /// - Returns: The pixels.
  /// - Throws: An error when AppKit gives no pixels.
  static func cachedPixels(
    of view: some View, size windowSize: CGSize = GlassRenderProbeTests.size
  ) throws -> RenderedPixels {
    let harness = HostedViewHarness(view, size: windowSize)
    defer { harness.close() }
    return try #require(RenderedPixels(cachingDisplayOf: harness.hostingView))
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
