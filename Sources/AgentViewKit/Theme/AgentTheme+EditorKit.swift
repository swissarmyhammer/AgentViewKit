import AppKit
import EditorTheme
import SwiftUI

nonisolated extension AgentTheme {
  /// The system colors that ``editorTheme`` gives to EditorKit.
  ///
  /// Each color is a dynamic AppKit color, so the editor follows the light
  /// or dark appearance of the window.
  public enum EditorSystemColors: Sendable {
    /// The background of the text area.
    public static let background = Color(nsColor: .textBackgroundColor)
    /// The default color of the text.
    public static let foreground = Color(nsColor: .textColor)
    /// The color of the selected text.
    public static let selection = Color(nsColor: .selectedTextBackgroundColor)
    /// The background of the gutter.
    public static let gutterBackground = Color(nsColor: .controlBackgroundColor)
    /// The background of the status bar and the tab bar.
    public static let barBackground = Color(nsColor: .windowBackgroundColor)
  }

  /// An EditorKit theme that agrees with this theme (plan.md §4.1).
  ///
  /// The bridge maps ``accent`` to `tokenTint`, ``codeFont`` to the font of
  /// each capture, and the ``EditorSystemColors`` to the editor colors. A
  /// view that hosts EditorKit applies the value with `.editorTheme(_:)`.
  public var editorTheme: any EditorTheme.Theme {
    AgentEditorTheme(accent: accent, codeFont: codeFont)
  }
}

/// The EditorKit theme that ``AgentTheme/editorTheme`` makes.
///
/// Each capture has the same color and font. The kit does not color code by
/// capture until research R12 sets a palette.
nonisolated struct AgentEditorTheme: EditorTheme.Theme {
  /// The tint of the native token chips.
  let tokenTint: Color
  /// The font of each capture.
  let codeFont: Font

  /// Makes the bridge theme.
  ///
  /// - Parameters:
  ///   - accent: The accent of the kit theme.
  ///   - codeFont: The code font of the kit theme.
  init(accent: Color, codeFont: Font) {
    self.tokenTint = accent
    self.codeFont = codeFont
  }

  var editorBackground: Color { AgentTheme.EditorSystemColors.background }
  var editorForeground: Color { AgentTheme.EditorSystemColors.foreground }
  var selection: Color { AgentTheme.EditorSystemColors.selection }
  var gutterBackground: Color { AgentTheme.EditorSystemColors.gutterBackground }
  var statusBarBackground: Color { AgentTheme.EditorSystemColors.barBackground }
  var tabBarBackground: Color { AgentTheme.EditorSystemColors.barBackground }

  /// The attributes of a capture: the editor foreground, the code font, and
  /// the style key.
  ///
  /// - Parameter key: The capture key.
  /// - Returns: The attributes of the capture.
  func attributes(for key: StyleKey) -> AttributeContainer {
    var container = AttributeContainer()
    container.foregroundColor = editorForeground
    container.font = codeFont
    container.styleKey = key.rawValue
    return container
  }
}
