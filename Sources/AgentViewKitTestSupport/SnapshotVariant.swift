import AppKit
import SwiftUI
import Testing

/// One look of a view in a snapshot image (AVK-13): light, dark, Reduce
/// Transparency, or Increase Contrast.
///
/// ``pinned(_:)`` sets each setting that changes the look of a view, so that
/// the settings of the computer do not change the image. The dark variant
/// sets the dark color scheme. The Reduce Transparency and Increase Contrast
/// variants use the light color scheme and the private environment keys
/// that the glass tests use (`GlassRenderProbeTests`). Each variant reduces
/// motion and turns off the animations, so that a view shows its final
/// state, and uses one locale and one time zone, so that a date shows the
/// same text on each computer.
///
/// The type is `nonisolated` because the arguments of a test use its cases.
public nonisolated enum SnapshotVariant: String, CaseIterable, Sendable, CustomTestStringConvertible {
  /// The light color scheme with standard settings.
  case light

  /// The dark color scheme with standard settings.
  case dark

  /// The light color scheme with Reduce Transparency on.
  case reduceTransparency = "reduce-transparency"

  /// The light color scheme with Increase Contrast on.
  case increaseContrast = "increase-contrast"

  /// The time zone of each variant.
  public static let timeZone = TimeZone.gmt

  /// The locale of each variant.
  public static let locale = Locale(identifier: "en_US_POSIX")

  /// The calendar of each variant.
  private static let calendar = Calendar(identifier: .gregorian)

  public var testDescription: String { rawValue }

  /// The name of the image of `view` in this variant, such as
  /// `thread-dark`.
  ///
  /// - Parameter view: The name of the view.
  /// - Returns: `<view>-<variant>`.
  public func name(of view: String) -> String {
    "\(view)-\(rawValue)"
  }

  /// The color scheme of the variant.
  public var colorScheme: ColorScheme {
    self == .dark ? .dark : .light
  }

  /// The name of the AppKit appearance of a window that shows the variant.
  public var appearanceName: NSAppearance.Name {
    self == .dark ? .darkAqua : .aqua
  }

  /// Whether the variant reduces transparency.
  public var reducesTransparency: Bool {
    self == .reduceTransparency
  }

  /// The contrast of the variant.
  public var contrast: ColorSchemeContrast {
    self == .increaseContrast ? .increased : .standard
  }

  /// `view` in the center of the full image, over the window background, with
  /// each setting of the variant.
  ///
  /// The background fills the full image, also around a view that is
  /// smaller than the image, so that each pixel of the image is opaque.
  ///
  /// - Parameter view: The view to show.
  /// - Returns: The view with the settings of the variant.
  @MainActor
  public func pinned(_ view: some View) -> some View {
    view
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(nsColor: .windowBackgroundColor))
      .environment(\.colorScheme, colorScheme)
      .environment(\._accessibilityReduceTransparency, reducesTransparency)
      .environment(\._colorSchemeContrast, contrast)
      .environment(\._accessibilityReduceMotion, true)
      .environment(\.locale, Self.locale)
      .environment(\.timeZone, Self.timeZone)
      .environment(\.calendar, Self.calendar)
      .transaction { $0.disablesAnimations = true }
  }
}
