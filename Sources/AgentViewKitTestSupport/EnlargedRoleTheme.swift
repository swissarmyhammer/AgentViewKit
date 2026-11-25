import EditorTheme
import SwiftUI

/// An EditorKit theme that draws one font role much larger than the default
/// faces, and the other two roles in their ``ThemeRoleDefaults`` faces.
///
/// A view that draws text in the enlarged role is larger with this theme than
/// with no theme, at each text style. A view that draws text in another role
/// is the same size. So a test tells which role a view reads
/// (`FontRoleExpectations` of the integration tests), and a test of a
/// control sees the theme on the control. The colors are the colors of
/// `SystemTheme`, the theme of an environment with no theme.
public nonisolated struct EnlargedRoleTheme: EditorTheme.Theme {
  /// The face of the enlarged role: the system serif face at the size of the
  /// largest system text style, much larger than the `body` text style of the
  /// default faces.
  public static let enlargedFace = FontFace.serif(sizedAs: .largeTitle)

  /// The font of the enlarged role at the `body` text style.
  public static let enlargedFont = enlargedFace.font()

  /// The role that draws in ``enlargedFace``.
  public let enlargedRole: FontRole

  /// Makes a theme that enlarges `enlargedRole`.
  ///
  /// - Parameter enlargedRole: The role that draws in ``enlargedFace``.
  public init(enlargedRole: FontRole) {
    self.enlargedRole = enlargedRole
  }

  /// The theme that gives the colors.
  private let base = SystemTheme()

  /// The text color of `SystemTheme`.
  public var editorForeground: Color { base.editorForeground }
  /// The selection color of `SystemTheme`.
  public var selection: Color { base.selection }
  /// The status bar background of `SystemTheme`.
  public var statusBarBackground: Color { base.statusBarBackground }
  /// The tab bar background of `SystemTheme`.
  public var tabBarBackground: Color { base.tabBarBackground }
  /// The face of the `ui` role: ``enlargedFace`` when `ui` is the enlarged
  /// role, else the default face of the role.
  public var uiFace: FontFace { face(enlargedIn: .ui, default: ThemeRoleDefaults.uiFace) }
  /// The face of the `display` role: ``enlargedFace`` when `display` is the
  /// enlarged role, else the default face of the role.
  public var displayFace: FontFace { face(enlargedIn: .display, default: ThemeRoleDefaults.displayFace) }
  /// The face of the `code` role: ``enlargedFace`` when `code` is the
  /// enlarged role, else the default face of the role.
  public var codeFace: FontFace { face(enlargedIn: .code, default: ThemeRoleDefaults.codeFace) }

  /// The attributes of a capture in `SystemTheme`.
  ///
  /// - Parameter key: The capture key.
  /// - Returns: The attributes of the capture.
  public func attributes(for key: StyleKey) -> AttributeContainer {
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
