import AgentViewKitTestSupport
import SwiftUI
import Testing

/// The facts about Liquid Glass in a test process that the AVK-8a decision
/// uses (^dbbyg9w, D110 (f)).
///
/// The decision: a test of a glass view renders the view two times with
/// ``RenderedPixels``, one time with the setting off and one time with the
/// setting on, and expects different pixels. The test sets Reduce
/// Transparency with `_accessibilityReduceTransparency` and Increase
/// Contrast with `_colorSchemeContrast`. SwiftUI has no API for the Tinted
/// look of the system, so a kit environment value selects the look, and a
/// test compares `Glass` values and pixels. A person checks the real system
/// Tinted setting one time for each release.
///
/// Each render sets light mode, Reduce Transparency off and standard
/// contrast first, so that the settings of the computer do not change the
/// result. When a fact changes in a new SDK, a test here fails. Then do the
/// decision again.
@Suite @MainActor struct GlassRenderProbeTests {
  /// The size that the tests render at.
  static let size = CGSize(width: 40, height: 40)

  /// The distance from each edge of the render to the points near the
  /// corners in ``interiorPoints``. It is much more than the width of the
  /// rim of the glass, so the rim is not at these points.
  static let interiorInset: CGFloat = 10

  /// The points inside the glass of ``GlassOverBackdrop`` at ``size`` that
  /// the tests compare (``interiorPoints(of:inset:)``). The glass fills the
  /// render, so the rim of the glass is on the edge of the render, far from
  /// these points.
  static var interiorPoints: [CGPoint] {
    interiorPoints(of: size, inset: interiorInset)
  }

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

  /// The color that ``SettingProbe`` draws when the setting is on.
  static let settingOn = Color(red: 0.2, green: 0.8, blue: 0.2)

  /// The color that ``SettingProbe`` draws when the setting is off.
  static let settingOff = Color(red: 0.8, green: 0.6, blue: 0.1)

  /// The pixels of `view` in light mode, with only `setting` changed.
  ///
  /// - Parameters:
  ///   - view: The view to render.
  ///   - setting: The setting to change, or `nil` for no change.
  ///   - isOn: Whether `setting` is on.
  ///   - renderSize: The size to render at.
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels.
  static func pixels(
    of view: some View, with setting: GlassProbeSetting? = nil, on isOn: Bool = false,
    size renderSize: CGSize = size
  ) throws -> RenderedPixels {
    try #require(RenderedPixels(rendering: pinned(view, with: setting, on: isOn), size: renderSize))
  }

  /// Expects that `setting` changes the pixels of `view` at `points`.
  ///
  /// The function renders `view` one time with `setting` on and one time with
  /// it off (``pixels(of:with:on:size:)``). Then it expects that the two
  /// renders do not show the same colors at `points`. The function does not
  /// compare each pixel: the rim of a glass changes after its first renders
  /// in the process, so a difference at the rim does not show that the
  /// setting changes the glass.
  ///
  /// - Parameters:
  ///   - view: The view to render.
  ///   - setting: The setting to change.
  ///   - points: The points to compare, in points from the top leading
  ///     corner of the view. Keep the points far from the edge of a glass
  ///     (``RenderedPixels/isClose(to:at:tolerance:)``).
  ///   - renderSize: The size to render at.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An error when the renderer gives no pixels.
  static func expectDifferentPixels(
    of view: some View, with setting: GlassProbeSetting, at points: [CGPoint],
    size renderSize: CGSize = size, sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let on = try pixels(of: view, with: setting, on: true, size: renderSize)
    let off = try pixels(of: view, with: setting, on: false, size: renderSize)
    #expect(!on.isClose(to: off, at: points), sourceLocation: sourceLocation)
  }

  /// `view` in light mode, with only `setting` changed.
  ///
  /// - Parameters:
  ///   - view: The view to change.
  ///   - setting: The setting to change, or `nil` for no change.
  ///   - isOn: Whether `setting` is on.
  /// - Returns: The view with light mode, `setting`, and each other setting
  ///   off.
  static func pinned(
    _ view: some View, with setting: GlassProbeSetting? = nil, on isOn: Bool = false
  ) -> some View {
    // An environment value near the view replaces the same value farther
    // out. Thus the changed setting stays, and each other setting is off.
    let changed = setting.map { AnyView($0.apply(isOn, to: view)) } ?? AnyView(view)
    let pinned = GlassProbeSetting.allCases.reduce(changed) { pinned, each in
      AnyView(each.apply(false, to: pinned))
    }
    return pinned.environment(\.colorScheme, .light)
  }

  @Test(arguments: GlassProbeSetting.allCases)
  func theGlassFollowsTheSetting(_ setting: GlassProbeSetting) throws {
    try Self.expectDifferentPixels(
      of: GlassOverBackdrop(glass: .regular), with: setting, at: Self.interiorPoints)
  }

  @Test(arguments: GlassProbeSetting.allCases)
  func theSettingReachesAChildView(_ setting: GlassProbeSetting) throws {
    let pixels = try Self.pixels(of: SettingProbe(setting: setting), with: setting, on: true)
    #expect(pixels.contains(Self.settingOn))
    #expect(!pixels.contains(Self.settingOff))
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

/// An accessibility setting that a probe sets with an environment value.
///
/// The type is `nonisolated` because the arguments of a test use its cases.
nonisolated enum GlassProbeSetting: CaseIterable, Sendable {
  /// Reduce Transparency, with `_accessibilityReduceTransparency`.
  case reduceTransparency
  /// Increase Contrast, with `_colorSchemeContrast`.
  case increasedContrast

  /// Sets the setting on or off for `view` and each view in it.
  ///
  /// - Parameters:
  ///   - isOn: Whether the setting is on.
  ///   - view: The view to change.
  /// - Returns: The view with the setting.
  @ViewBuilder
  func apply(_ isOn: Bool, to view: some View) -> some View {
    switch self {
    case .reduceTransparency:
      view.environment(\._accessibilityReduceTransparency, isOn)
    case .increasedContrast:
      view.environment(\._colorSchemeContrast, isOn ? .increased : .standard)
    }
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

/// A view that draws one color when its setting is on in the environment,
/// and a different color when the setting is off.
struct SettingProbe: View {
  /// The setting to read.
  let setting: GlassProbeSetting

  @Environment(\.accessibilityReduceTransparency) private var reducesTransparency
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    isOn ? GlassRenderProbeTests.settingOn : GlassRenderProbeTests.settingOff
  }

  /// Whether the environment has the setting.
  private var isOn: Bool {
    switch setting {
    case .reduceTransparency: reducesTransparency
    case .increasedContrast: contrast == .increased
    }
  }
}
