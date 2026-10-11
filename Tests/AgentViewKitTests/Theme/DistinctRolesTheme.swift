import EditorTheme
import SwiftUI

/// An EditorKit theme with a different color for each color role that the
/// kit reads.
///
/// The colors are plain RGB colors, not dynamic system colors, so that a test
/// can resolve them in a process with no app. No two roles have the same
/// color, so a test can tell which role a view or a function uses.
nonisolated struct DistinctRolesTheme: EditorTheme.Theme {
  /// The colors of the roles.
  enum Role {
    /// The accent.
    static let accent = Color(red: 0.5, green: 0, blue: 0.5)
    /// The running status.
    static let running = Color(red: 0, green: 0, blue: 1)
    /// The succeeded status.
    static let succeeded = Color(red: 0, green: 1, blue: 0)
    /// The failed status.
    static let failed = Color(red: 1, green: 0, blue: 0)
    /// The cancelled status.
    static let cancelled = Color(red: 0.25, green: 0.25, blue: 0.25)
    /// The pending status.
    static let pending = Color(red: 1, green: 1, blue: 0)
    /// The information severity.
    static let info = Color(red: 0, green: 1, blue: 1)
    /// The warning severity.
    static let warning = Color(red: 1, green: 0.5, blue: 0)
    /// The error severity.
    static let error = Color(red: 1, green: 0, blue: 1)
    /// The editor background.
    static let editorBackground = Color(red: 0.9, green: 1, blue: 0.9)
    /// The editor foreground.
    static let editorForeground = Color(red: 0.1, green: 0.1, blue: 0.2)
    /// The selection.
    static let selection = Color(red: 0.7, green: 0.8, blue: 1)
    /// The gutter background.
    static let gutterBackground = Color(red: 0.8, green: 0.8, blue: 0.7)
    /// The status bar background.
    static let statusBarBackground = Color(red: 0, green: 0.5, blue: 0.5)
    /// The tab bar background.
    static let tabBarBackground = Color(red: 0.6, green: 0.4, blue: 0.2)
    /// The full color of the added row band.
    static let added = Color(red: 0.2, green: 0.6, blue: 0.2)
    /// The full color of the removed row band.
    static let removed = Color(red: 0.6, green: 0.2, blue: 0.2)
    /// The opacity of the diff row bands, as in EditorKit.
    static let bandOpacity = DiffTintDefaults.bandOpacity
    /// The code font.
    static let editorFont = Font.system(.callout, design: .serif)
  }

  var editorBackground: Color { Role.editorBackground }
  var editorForeground: Color { Role.editorForeground }
  var selection: Color { Role.selection }
  var gutterBackground: Color { Role.gutterBackground }
  var statusBarBackground: Color { Role.statusBarBackground }
  var tabBarBackground: Color { Role.tabBarBackground }
  var diffAddedBackground: Color { Role.added.opacity(Role.bandOpacity) }
  var diffRemovedBackground: Color { Role.removed.opacity(Role.bandOpacity) }
  var accent: Color { Role.accent }
  var statusRunning: Color { Role.running }
  var statusSucceeded: Color { Role.succeeded }
  var statusFailed: Color { Role.failed }
  var statusCancelled: Color { Role.cancelled }
  var statusPending: Color { Role.pending }
  var severityInfo: Color { Role.info }
  var severityWarning: Color { Role.warning }
  var severityError: Color { Role.error }
  var editorFont: Font { Role.editorFont }

  /// Each capture has the editor foreground and the style key.
  ///
  /// - Parameter key: The capture key.
  /// - Returns: The attributes of the capture.
  func attributes(for key: StyleKey) -> AttributeContainer {
    var container = AttributeContainer()
    container.foregroundColor = editorForeground
    container.styleKey = key.rawValue
    return container
  }
}
