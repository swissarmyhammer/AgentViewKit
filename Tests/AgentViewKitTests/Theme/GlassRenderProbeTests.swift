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
  /// - Returns: The pixels.
  /// - Throws: An error when the renderer gives no pixels.
  static func pixels(
    of view: some View, with setting: GlassProbeSetting? = nil, on isOn: Bool = false
  ) throws -> RenderedPixels {
    // An environment value near the view replaces the same value farther
    // out. Thus the changed setting stays, and each other setting is off.
    let changed = setting.map { AnyView($0.apply(isOn, to: view)) } ?? AnyView(view)
    let pinned = GlassProbeSetting.allCases.reduce(changed) { pinned, each in
      AnyView(each.apply(false, to: pinned))
    }
    return try #require(
      RenderedPixels(rendering: pinned.environment(\.colorScheme, .light), size: size))
  }

  @Test(arguments: GlassProbeSetting.allCases)
  func theGlassFollowsTheSetting(_ setting: GlassProbeSetting) throws {
    let glass = GlassOverBackdrop(glass: .regular)
    let on = try Self.pixels(of: glass, with: setting, on: true)
    let off = try Self.pixels(of: glass, with: setting, on: false)
    #expect(on != off)
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
  /// - Parameter view: The view to show.
  /// - Returns: The pixels.
  /// - Throws: An error when AppKit gives no pixels.
  static func cachedPixels(of view: some View) throws -> RenderedPixels {
    let harness = HostedViewHarness(view, size: GlassRenderProbeTests.size)
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
