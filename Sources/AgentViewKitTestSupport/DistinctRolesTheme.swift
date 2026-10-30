import EditorTheme
import SwiftUI

/// An EditorKit theme with a different color for each color role that the
/// kit reads.
///
/// The colors are plain RGB colors, not dynamic system colors, so that a test
/// can resolve them in a process with no app. No two roles have the same
/// color, so a test can tell which role a view or a function uses.
public nonisolated struct DistinctRolesTheme: EditorTheme.Theme {
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
  public enum Role {
    /// The accent.
    public static let accent = Color(red: Level.half, green: 0, blue: Level.half)
    /// The running status.
    public static let running = Color(red: 0, green: 0, blue: 1)
    /// The succeeded status.
    public static let succeeded = Color(red: 0, green: 1, blue: 0)
    /// The failed status.
    public static let failed = Color(red: 1, green: 0, blue: 0)
    /// The cancelled status.
    public static let cancelled = Color(red: Level.quarter, green: Level.quarter, blue: Level.quarter)
    /// The pending status.
    public static let pending = Color(red: 1, green: 1, blue: 0)
    /// The information severity.
    public static let info = Color(red: 0, green: 1, blue: 1)
    /// The warning severity.
    public static let warning = Color(red: 1, green: Level.half, blue: 0)
    /// The error severity.
    public static let error = Color(red: 1, green: 0, blue: 1)
    /// The editor foreground.
    public static let editorForeground = Color(red: Level.tenth, green: Level.tenth, blue: Level.fifth)
    /// The selection.
    public static let selection = Color(red: Level.sevenTenths, green: Level.fourFifths, blue: 1)
    /// The status bar background.
    public static let statusBarBackground = Color(red: 0, green: Level.half, blue: Level.half)
    /// The tab bar background.
    public static let tabBarBackground = Color(
      red: Level.threeFifths, green: Level.twoFifths, blue: Level.fifth)
    /// The full color of the added row band.
    public static let added = Color(red: Level.fifth, green: Level.threeFifths, blue: Level.fifth)
    /// The full color of the removed row band.
    public static let removed = Color(red: Level.threeFifths, green: Level.fifth, blue: Level.fifth)
    /// The opacity of the diff row bands, as in EditorKit.
    public static let bandOpacity = DiffTintDefaults.bandOpacity
    /// The text color of an added count.
    public static let addedText = Color(red: Level.tenth, green: Level.half, blue: Level.tenth)
    /// The text color of a removed count.
    public static let removedText = Color(red: Level.half, green: Level.tenth, blue: Level.tenth)
    /// The UI face: a size that is larger than the body text, and not the
    /// size of ``displayFace`` or ``codeFace``, so that no two font roles are
    /// equal.
    public static let uiFace = FontFace.serif(sizedAs: .title2)
    /// The display face: a size that is much larger than the body text, and
    /// not the size of ``uiFace`` or ``codeFace``.
    public static let displayFace = FontFace.serif(sizedAs: .largeTitle)
    /// The code face: a size that is much larger than the body text, and not
    /// the size of ``uiFace`` or ``displayFace``.
    public static let codeFace = FontFace.serif(sizedAs: .title1)
    /// The terminal foreground (SGR 39).
    public static let terminalForeground = Color(red: Level.fifth, green: Level.tenth, blue: Level.twoFifths)
    /// The terminal background.
    public static let terminalBackground = Color(red: 1, green: Level.nineTenths, blue: Level.sevenTenths)
    /// The terminal palette: the terminal foreground and background, and a
    /// different color for each ANSI color.
    public static let terminalPalette = TerminalPalette { entry in
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
    public static func ansiColor(_ index: Int) -> Color {
      Color(
        red: Double(index) / Double(TerminalPalette.ansiColorCount), green: Level.fourFifths,
        blue: Level.tenth)
    }
  }

  /// Makes the theme. It has no state: each role reads ``Role``.
  public init() {}

  /// The editor foreground: ``Role/editorForeground``.
  public var editorForeground: Color { Role.editorForeground }
  /// The selection: ``Role/selection``.
  public var selection: Color { Role.selection }
  /// The status bar background: ``Role/statusBarBackground``.
  public var statusBarBackground: Color { Role.statusBarBackground }
  /// The tab bar background: ``Role/tabBarBackground``.
  public var tabBarBackground: Color { Role.tabBarBackground }
  /// The band of an added row: ``Role/added`` at ``Role/bandOpacity``.
  public var diffAddedBackground: Color { Role.added.opacity(Role.bandOpacity) }
  /// The band of a removed row: ``Role/removed`` at ``Role/bandOpacity``.
  public var diffRemovedBackground: Color { Role.removed.opacity(Role.bandOpacity) }
  /// The accent: ``Role/accent``.
  public var accent: Color { Role.accent }
  /// The running status: ``Role/running``.
  public var statusRunning: Color { Role.running }
  /// The succeeded status: ``Role/succeeded``.
  public var statusSucceeded: Color { Role.succeeded }
  /// The failed status: ``Role/failed``.
  public var statusFailed: Color { Role.failed }
  /// The cancelled status: ``Role/cancelled``.
  public var statusCancelled: Color { Role.cancelled }
  /// The pending status: ``Role/pending``.
  public var statusPending: Color { Role.pending }
  /// The information severity: ``Role/info``.
  public var severityInfo: Color { Role.info }
  /// The warning severity: ``Role/warning``.
  public var severityWarning: Color { Role.warning }
  /// The error severity: ``Role/error``.
  public var severityError: Color { Role.error }
  /// The text of an added count: ``Role/addedText``.
  public var diffAddedText: Color { Role.addedText }
  /// The text of a removed count: ``Role/removedText``.
  public var diffRemovedText: Color { Role.removedText }
  /// The UI face: ``Role/uiFace``.
  public var uiFace: FontFace { Role.uiFace }
  /// The display face: ``Role/displayFace``.
  public var displayFace: FontFace { Role.displayFace }
  /// The code face: ``Role/codeFace``.
  public var codeFace: FontFace { Role.codeFace }
  /// The terminal palette: ``Role/terminalPalette``.
  public var terminalPalette: TerminalPalette { Role.terminalPalette }

  /// Each capture has the editor foreground and the style key.
  ///
  /// - Parameter key: The capture key.
  /// - Returns: The attributes of the capture.
  public func attributes(for key: StyleKey) -> AttributeContainer {
    var container = AttributeContainer()
    container.foregroundColor = editorForeground
    container.styleKey = key.rawValue
    return container
  }
}
