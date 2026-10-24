import EditorTheme
import SwiftUI

/// An EditorKit theme that draws one font role much larger than the default
/// fonts, and the other two roles in their ``ThemeRoleDefaults`` fonts.
///
/// A view that draws text in the enlarged role is larger with this theme than
/// with no theme. A view that draws text in another role is the same size. So
/// a test tells which role a view reads (``FontRoleExpectations``). The
/// colors are the colors of `SystemTheme`, the theme of an environment with no
/// theme.
nonisolated struct EnlargedRoleTheme: EditorTheme.Theme {
  /// The text style of the enlarged role: the largest system text style, much
  /// larger than the `body` text style of the default fonts.
  static let enlargedTextStyle = Font.TextStyle.largeTitle

  /// The font of the enlarged role: the system serif font at
  /// ``enlargedTextStyle``.
  static let enlargedFont = Font.system(enlargedTextStyle, design: .serif)

  /// The role that draws in ``enlargedFont``.
  let enlargedRole: FontRole

  /// The theme that gives the colors.
  private let base = SystemTheme()

  var editorForeground: Color { base.editorForeground }
  var selection: Color { base.selection }
  var statusBarBackground: Color { base.statusBarBackground }
  var tabBarBackground: Color { base.tabBarBackground }
  var uiFont: Font { font(enlargedIn: .ui, default: ThemeRoleDefaults.uiFont) }
  var displayFont: Font { font(enlargedIn: .display, default: ThemeRoleDefaults.displayFont) }
  var codeFont: Font { font(enlargedIn: .code, default: ThemeRoleDefaults.codeFont) }

  /// The attributes of a capture in `SystemTheme`.
  ///
  /// - Parameter key: The capture key.
  /// - Returns: The attributes of the capture.
  func attributes(for key: StyleKey) -> AttributeContainer {
    base.attributes(for: key)
  }

  /// The font of `role`: ``enlargedFont`` when `role` is ``enlargedRole``,
  /// and `defaultFont` otherwise.
  ///
  /// - Parameters:
  ///   - role: The role whose font to give.
  ///   - defaultFont: The ``ThemeRoleDefaults`` font of `role`.
  /// - Returns: The font of the role in this theme.
  private func font(enlargedIn role: FontRole, default defaultFont: Font) -> Font {
    role == enlargedRole ? Self.enlargedFont : defaultFont
  }
}
