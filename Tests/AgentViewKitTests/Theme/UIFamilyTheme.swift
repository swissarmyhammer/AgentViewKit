import EditorTheme
import SwiftUI

/// An EditorKit theme whose `ui` face names a font family, as a theme that a
/// host imports from a Zed `ui_font_family` does.
///
/// The face has no fixed size, so each text style keeps its system size and
/// only the family changes. A chrome text in the `ui` role at any text style
/// draws in ``family``, and a test tells that from the width of the text. The
/// colors and the other faces are the ones of `SystemTheme`.
nonisolated struct UIFamilyTheme: EditorTheme.Theme {
  /// The family of the `ui` face: a family that each macOS install has, with
  /// glyph widths that are not the widths of the system font.
  static let family = "Helvetica Neue"

  /// The theme that gives the colors.
  private let base = SystemTheme()

  var editorForeground: Color { base.editorForeground }
  var selection: Color { base.selection }
  var statusBarBackground: Color { base.statusBarBackground }
  var tabBarBackground: Color { base.tabBarBackground }
  var uiFace: FontFace { FontFace(family: Self.family) }

  /// The attributes of a capture in `SystemTheme`.
  ///
  /// - Parameter key: The capture key.
  /// - Returns: The attributes of the capture.
  func attributes(for key: StyleKey) -> AttributeContainer {
    base.attributes(for: key)
  }
}
