import EditorTheme
import SwiftUI

/// An EditorKit theme that draws one font role much larger than the default
/// faces, and the other two roles in their ``ThemeRoleDefaults`` faces.
///
/// A view that draws text in the enlarged role is larger with this theme than
/// with no theme, at each text style. A view that draws text in another role
/// is the same size. So a test tells which role a view reads
/// (``FontRoleExpectations``). The colors are the colors of `SystemTheme`, the
/// theme of an environment with no theme.
nonisolated struct EnlargedRoleTheme: EditorTheme.Theme {
  /// The face of the enlarged role: the system serif face at the size of the
  /// largest system text style, much larger than the `body` text style of the
  /// default faces.
  static let enlargedFace = FontFace.serif(sizedAs: .largeTitle)

  /// The font of the enlarged role at the `body` text style.
  static let enlargedFont = enlargedFace.font()

  /// The role that draws in ``enlargedFace``.
  let enlargedRole: FontRole

  /// The theme that gives the colors.
  private let base = SystemTheme()

  var editorForeground: Color { base.editorForeground }
  var selection: Color { base.selection }
  var statusBarBackground: Color { base.statusBarBackground }
  var tabBarBackground: Color { base.tabBarBackground }
  var uiFace: FontFace { face(enlargedIn: .ui, default: ThemeRoleDefaults.uiFace) }
  var displayFace: FontFace { face(enlargedIn: .display, default: ThemeRoleDefaults.displayFace) }
  var codeFace: FontFace { face(enlargedIn: .code, default: ThemeRoleDefaults.codeFace) }

  /// The attributes of a capture in `SystemTheme`.
  ///
  /// - Parameter key: The capture key.
  /// - Returns: The attributes of the capture.
  func attributes(for key: StyleKey) -> AttributeContainer {
    base.attributes(for: key)
  }

  /// The face of `role`: ``enlargedFace`` when `role` is ``enlargedRole``,
  /// and `defaultFace` otherwise.
  ///
  /// - Parameters:
  ///   - role: The role whose face to give.
  ///   - defaultFace: The ``ThemeRoleDefaults`` face of `role`.
  /// - Returns: The face of the role in this theme.
  private func face(enlargedIn role: FontRole, default defaultFace: FontFace) -> FontFace {
    role == enlargedRole ? Self.enlargedFace : defaultFace
  }
}
