import AgentViewKitTestSupport
import AppKit
import ImageIO
import SwiftUI
import Testing

/// Tests for ``SnapshotVariant`` and the two render paths of ``ViewSnapshot``
/// (AVK-13).
@Suite @MainActor struct SnapshotVariantTests {
  /// The size of each render.
  static let size = CGSize(width: 40, height: 20)

  /// The color that ``SettingReader`` draws when its setting is on.
  static let on = Color(red: 0.2, green: 0.8, blue: 0.2)

  /// The color that ``SettingReader`` draws when its setting is off.
  static let off = Color(red: 0.8, green: 0.6, blue: 0.1)

  /// Whether the render of `variant` shows the setting that `isOn` reads.
  ///
  /// - Parameters:
  ///   - variant: The variant to render.
  ///   - isOn: The read of the setting from the environment.
  /// - Returns: `true` when the render shows ``on``.
  /// - Throws: An issue when the render gives no pixels, or shows neither
  ///   color.
  static func showsTheSetting(
    of variant: SnapshotVariant, _ isOn: @escaping (EnvironmentValues) -> Bool
  ) throws -> Bool {
    let pixels = try #require(
      ViewSnapshot.renderedPixels(of: SettingReader(isOn: isOn), size: size, variant: variant))
    let showsOn = pixels.contains(on)
    #expect(showsOn != pixels.contains(off))
    return showsOn
  }

  @Test(arguments: SnapshotVariant.allCases)
  func onlyTheDarkVariantHasTheDarkColorScheme(variant: SnapshotVariant) throws {
    #expect(try Self.showsTheSetting(of: variant) { $0.colorScheme == .dark } == (variant == .dark))
  }

  @Test(arguments: SnapshotVariant.allCases)
  func onlyTheReduceTransparencyVariantReducesTransparency(variant: SnapshotVariant) throws {
    let reduces = try Self.showsTheSetting(of: variant) { $0.accessibilityReduceTransparency }
    #expect(reduces == (variant == .reduceTransparency))
  }

  @Test(arguments: SnapshotVariant.allCases)
  func onlyTheIncreaseContrastVariantIncreasesTheContrast(variant: SnapshotVariant) throws {
    let increases = try Self.showsTheSetting(of: variant) { $0.colorSchemeContrast == .increased }
    #expect(increases == (variant == .increaseContrast))
  }

  @Test(arguments: SnapshotVariant.allCases)
  func eachVariantReducesMotion(variant: SnapshotVariant) throws {
    #expect(try Self.showsTheSetting(of: variant) { $0.accessibilityReduceMotion })
  }

  @Test(arguments: SnapshotVariant.allCases)
  func eachVariantUsesOneTimeZone(variant: SnapshotVariant) throws {
    #expect(try Self.showsTheSetting(of: variant) { $0.timeZone == SnapshotVariant.timeZone })
  }

  @Test(arguments: SnapshotVariant.allCases)
  func eachVariantUsesOneLocale(variant: SnapshotVariant) throws {
    #expect(try Self.showsTheSetting(of: variant) { $0.locale == SnapshotVariant.locale })
  }

  @Test func theNameOfAnImageEndsWithTheVariant() {
    #expect(SnapshotVariant.increaseContrast.name(of: "thread") == "thread-increase-contrast")
  }

  /// The side of a view that is smaller than ``size``, in points.
  static let smallSide: CGFloat = 4

  /// The top leading corner of a render, far from a small view in its
  /// center.
  static let corner = CGPoint(x: 1, y: 1)

  @Test(arguments: SnapshotVariant.allCases)
  func theBackgroundFillsTheImageAroundASmallView(variant: SnapshotVariant) throws {
    let small = Self.on.frame(width: Self.smallSide, height: Self.smallSide)
    let smallPixels = try #require(ViewSnapshot.renderedPixels(of: small, size: Self.size, variant: variant))
    let backgroundPixels = try #require(ViewSnapshot.renderedPixels(of: Color.clear, size: Self.size, variant: variant))

    #expect(smallPixels.isClose(to: backgroundPixels, at: [Self.corner]))
  }

  @Test func theRenderedLightAndDarkBackgroundsAreDifferent() throws {
    let light = try #require(ViewSnapshot.renderedPixels(of: Color.clear, size: Self.size, variant: .light))
    let dark = try #require(ViewSnapshot.renderedPixels(of: Color.clear, size: Self.size, variant: .dark))

    #expect(!light.isClose(to: dark))
  }
}

/// Tests for the window path of ``ViewSnapshot`` (AVK-13).
@Suite(.serialized, .hostedSerially) @MainActor struct ViewSnapshotHostedTests {
  @Test(arguments: SnapshotVariant.allCases)
  func onlyTheDarkVariantGivesAppKitViewsTheDarkAppearance(variant: SnapshotVariant) async throws {
    let pixels = try #require(
      await ViewSnapshot.hostedPixels(of: AppearanceReader(), size: SnapshotVariantTests.size, variant: variant))

    #expect(pixels.contains(SnapshotVariantTests.on) == (variant == .dark))
    #expect(pixels.contains(SnapshotVariantTests.off) == (variant != .dark))
  }

  @Test func theHostedImageHasTwoPixelsForEachPoint() async throws {
    let pixels = try #require(
      await ViewSnapshot.hostedPixels(of: Color.clear, size: SnapshotVariantTests.size, variant: .light))

    let size = try RenderedPixelsPNGTests.pixelSize(of: #require(pixels.pngData()))

    #expect(size.width == SnapshotVariantTests.size.width * RenderedPixels.renderScale)
    #expect(size.height == SnapshotVariantTests.size.height * RenderedPixels.renderScale)
  }

  @Test func theHostedImageShowsTheChangeOfTheSettleWork() async throws {
    let flag = SettleFlag()

    let pixels = try #require(
      await ViewSnapshot.hostedPixels(of: FlagReader(flag: flag), size: SnapshotVariantTests.size, variant: .light) {
        flag.isSet = true
      })

    #expect(pixels.contains(SnapshotVariantTests.on))
  }

  @Test func theHostedBackgroundFillsTheImageAroundASmallView() async throws {
    let size = SnapshotVariantTests.size
    let side = SnapshotVariantTests.smallSide
    let small = SnapshotVariantTests.on.frame(width: side, height: side)
    let smallPixels = try #require(await ViewSnapshot.hostedPixels(of: small, size: size, variant: .light))
    let backgroundPixels = try #require(await ViewSnapshot.hostedPixels(of: Color.clear, size: size, variant: .light))

    #expect(smallPixels.isClose(to: backgroundPixels, at: [SnapshotVariantTests.corner]))
  }

  @Test func theHostedLightAndDarkBackgroundsAreDifferent() async throws {
    let size = SnapshotVariantTests.size
    let light = try #require(await ViewSnapshot.hostedPixels(of: Color.clear, size: size, variant: .light))
    let dark = try #require(await ViewSnapshot.hostedPixels(of: Color.clear, size: size, variant: .dark))

    #expect(!light.isClose(to: dark))
  }

  /// An AppKit view of a type that the call hides draws nothing: the image
  /// is the image of the background alone.
  @Test func theHostedImageShowsNoViewOfAHiddenType() async throws {
    let size = SnapshotVariantTests.size
    let hidden = try #require(
      await ViewSnapshot.hostedPixels(
        of: AppearanceReader(), size: size, variant: .light, hiding: [AppearanceFillView.self]))
    let backgroundPixels = try #require(await ViewSnapshot.hostedPixels(of: Color.clear, size: size, variant: .light))

    #expect(!hidden.contains(SnapshotVariantTests.off))
    #expect(hidden.isClose(to: backgroundPixels))
  }
}

/// A view that draws ``SnapshotVariantTests/on`` when its setting is on in
/// the environment, and ``SnapshotVariantTests/off`` when it is off.
private struct SettingReader: View {
  /// The read of the setting from the environment.
  let isOn: (EnvironmentValues) -> Bool

  @Environment(\.self) private var environment

  var body: some View {
    isOn(environment) ? SnapshotVariantTests.on : SnapshotVariantTests.off
  }
}

/// An AppKit view that fills itself with ``SnapshotVariantTests/on`` when its
/// appearance is dark, and with ``SnapshotVariantTests/off`` when it is
/// light.
private struct AppearanceReader: NSViewRepresentable {
  func makeNSView(context: Context) -> AppearanceFillView { AppearanceFillView() }

  func updateNSView(_ view: AppearanceFillView, context: Context) {}
}

/// The AppKit view of ``AppearanceReader``.
private final class AppearanceFillView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    NSColor(isDark ? SnapshotVariantTests.on : SnapshotVariantTests.off).setFill()
    bounds.fill()
  }
}

/// A value that the settle work of a test sets.
@Observable private final class SettleFlag {
  /// Whether the settle work ran.
  var isSet = false
}

/// A view that draws ``SnapshotVariantTests/on`` when its flag is set.
private struct FlagReader: View {
  /// The flag to read.
  let flag: SettleFlag

  var body: some View {
    flag.isSet ? SnapshotVariantTests.on : SnapshotVariantTests.off
  }
}
