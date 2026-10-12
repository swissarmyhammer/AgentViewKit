import EditorTheme
import SwiftUI

/// An EditorKit theme with a different color for each color role that the
/// kit reads.
///
/// The colors are plain RGB colors, not dynamic system colors, so that a test
/// can resolve them in a process with no app. No two roles have the same
/// color, so a test can tell which role a view or a function uses.
nonisolated struct DistinctRolesTheme: EditorTheme.Theme {
  /// The values of one color component, from 0 to 1, that the role colors
  /// use. Each name gives the fraction of the full component.
  private enum Level {
    /// One tenth of the full component.
    static let tenth = 0.1
    /// One fifth of the full component.
    static let fifth = 0.2
    /// One quarter of the full component.
    static let quarter = 0.25
    /// Two fifths of the full component.
    static let twoFifths = 0.4
    /// One half of the full component.
    static let half = 0.5
    /// Three fifths of the full component.
    static let threeFifths = 0.6
    /// Seven tenths of the full component.
    static let sevenTenths = 0.7
    /// Four fifths of the full component.
    static let fourFifths = 0.8
    /// Nine tenths of the full component.
    static let nineTenths = 0.9
  }

  /// The colors of the roles.
  enum Role {
    /// The accent.
    static let accent = Color(red: Level.half, green: 0, blue: Level.half)
    /// The running status.
    static let running = Color(red: 0, green: 0, blue: 1)
    /// The succeeded status.
    static let succeeded = Color(red: 0, green: 1, blue: 0)
    /// The failed status.
    static let failed = Color(red: 1, green: 0, blue: 0)
    /// The cancelled status.
    static let cancelled = Color(red: Level.quarter, green: Level.quarter, blue: Level.quarter)
    /// The pending status.
    static let pending = Color(red: 1, green: 1, blue: 0)
    /// The information severity.
    static let info = Color(red: 0, green: 1, blue: 1)
    /// The warning severity.
    static let warning = Color(red: 1, green: Level.half, blue: 0)
    /// The error severity.
    static let error = Color(red: 1, green: 0, blue: 1)
    /// The editor background.
    static let editorBackground = Color(red: Level.nineTenths, green: 1, blue: Level.nineTenths)
    /// The editor foreground.
    static let editorForeground = Color(red: Level.tenth, green: Level.tenth, blue: Level.fifth)
    /// The selection.
    static let selection = Color(red: Level.sevenTenths, green: Level.fourFifths, blue: 1)
    /// The gutter background.
    static let gutterBackground = Color(
      red: Level.fourFifths, green: Level.fourFifths, blue: Level.sevenTenths)
    /// The status bar background.
    static let statusBarBackground = Color(red: 0, green: Level.half, blue: Level.half)
    /// The tab bar background.
    static let tabBarBackground = Color(
      red: Level.threeFifths, green: Level.twoFifths, blue: Level.fifth)
    /// The full color of the added row band.
    static let added = Color(red: Level.fifth, green: Level.threeFifths, blue: Level.fifth)
    /// The full color of the removed row band.
    static let removed = Color(red: Level.threeFifths, green: Level.fifth, blue: Level.fifth)
    /// The opacity of the diff row bands, as in EditorKit.
    static let bandOpacity = DiffTintDefaults.bandOpacity
    /// The text color of an added count.
    static let addedText = Color(red: Level.tenth, green: Level.half, blue: Level.tenth)
    /// The text color of a removed count.
    static let removedText = Color(red: Level.half, green: Level.tenth, blue: Level.tenth)
    /// The code font: a text style that is much larger than the body text,
    /// so that a test can see it in the size of a view. It is not the size
    /// of ``proseFont``, so a test can tell the two roles apart.
    static let editorFont = Font.system(.title, design: .serif)
    /// The prose font: a text style that is much larger than the body text,
    /// so that a test can see it in the size of a view.
    static let proseFont = Font.system(.largeTitle, design: .serif)
    /// The terminal foreground (SGR 39).
    static let terminalForeground = Color(red: Level.fifth, green: Level.tenth, blue: Level.twoFifths)
    /// The terminal background.
    static let terminalBackground = Color(red: 1, green: Level.nineTenths, blue: Level.sevenTenths)
    /// The terminal palette: the terminal foreground and background, and a
    /// different color for each ANSI color.
    static let terminalPalette = TerminalPalette { entry in
      switch entry {
      case .foreground: terminalForeground
      case .background: terminalBackground
      default: ansiColor(entry.rawValue)
      }
    }

    /// The color of ANSI color `index` in ``terminalPalette``. The red
    /// component grows with the index, so that no two ANSI colors are equal.
    ///
    /// - Parameter index: The ANSI color number, from 0 to 15.
    /// - Returns: The color.
    static func ansiColor(_ index: Int) -> Color {
      Color(
        red: Double(index) / Double(TerminalPalette.ansiColorCount), green: Level.fourFifths,
        blue: Level.tenth)
    }
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
  var diffAddedText: Color { Role.addedText }
  var diffRemovedText: Color { Role.removedText }
  var editorFont: Font { Role.editorFont }
  var proseFont: Font { Role.proseFont }
  var terminalPalette: TerminalPalette { Role.terminalPalette }

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
