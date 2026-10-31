import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The factor that scales a fixed bound of a view with the theme font (^dcs0pbj).
///
/// A height or a width of a view around text is named in points at the default theme font. The
/// view multiplies it by this factor, the way `@ScaledMetric` scales a metric with a text style:
/// the size of the font of a role, at the `body` text style, over ``defaultPointSize``. So a
/// bound stays where it is at the default font, and keeps its size in lines and characters under
/// a theme with another font, or at another Dynamic Type size. It needs no token of the theme.
@propertyWrapper
struct ThemeFontScale: DynamicProperty {
  /// The size of the `body` text style at the default theme font, in points.
  static let defaultPointSize: CGFloat = 13

  /// The font role of the text that the bound is around.
  let role: FontRole

  @Environment(\.editorTheme) private var theme
  @Environment(\.fontResolutionContext) private var context

  /// Makes the factor of a font role.
  ///
  /// - Parameter role: The font role of the text that the bound is around.
  init(_ role: FontRole) {
    self.role = role
  }

  /// The factor of the theme and the font context of the view.
  var wrappedValue: CGFloat {
    Self.scale(of: role, in: theme, context: context)
  }

  /// The factor of a font role.
  ///
  /// - Parameters:
  ///   - role: The font role.
  ///   - theme: The EditorKit theme.
  ///   - context: The font resolution context of the view.
  /// - Returns: The size of the font over ``defaultPointSize``: 1 at the default theme font.
  static func scale(of role: FontRole, in theme: any EditorTheme.Theme, context: Font.Context) -> CGFloat {
    theme.font(for: role).resolve(in: context).pointSize / defaultPointSize
  }
}
