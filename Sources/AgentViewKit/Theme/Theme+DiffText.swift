import EditorTheme
import SwiftUI

/// The colors of the added and removed line counts of a diff, from the diff
/// colors of the EditorKit theme.
///
/// The theme has the diff colors as row bands only: `diffAddedBackground`
/// and `diffRemovedBackground` are translucent, so that the text on a band
/// stays legible. A count is text, so it uses the same color at full
/// opacity. The EditorKit diff view draws its change bars the same way. The
/// counts and the bands then always agree, and the kit keeps no diff color of
/// its own.
nonisolated extension EditorTheme.Theme {
  /// The color of the count of added lines: `diffAddedBackground` at full
  /// opacity.
  ///
  /// - Parameter environment: The environment that the color resolves in.
  /// - Returns: The opaque color.
  func diffAddedText(in environment: EnvironmentValues) -> Color {
    OpaqueColor.make(diffAddedBackground, in: environment)
  }

  /// The color of the count of removed lines: `diffRemovedBackground` at
  /// full opacity.
  ///
  /// - Parameter environment: The environment that the color resolves in.
  /// - Returns: The opaque color.
  func diffRemovedText(in environment: EnvironmentValues) -> Color {
    OpaqueColor.make(diffRemovedBackground, in: environment)
  }
}

/// Makes a translucent theme color opaque.
private nonisolated enum OpaqueColor {
  /// The opacity of an opaque color.
  static let fullOpacity: Float = 1

  /// `color`, resolved in `environment`, at full opacity.
  ///
  /// - Parameters:
  ///   - color: The color, which can be translucent and dynamic.
  ///   - environment: The environment that the color resolves in, for its
  ///     appearance and its contrast.
  /// - Returns: The opaque color.
  static func make(_ color: Color, in environment: EnvironmentValues) -> Color {
    var resolved = color.resolve(in: environment)
    resolved.opacity = fullOpacity
    return Color(resolved)
  }
}
