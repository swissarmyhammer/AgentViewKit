import EditorSwiftUI
import EditorTheme

/// The ANSI test fixtures that the terminal suites share: the escape
/// character, the terminal palette, the ANSI color numbers, and the color
/// runs that the palette gives.
///
/// Each suite reads its fixtures from here, so that a change to a fixture is
/// made in one place.
public nonisolated enum ANSIFixtures {
  /// The escape character that starts each control sequence.
  public static let escape = "\u{1B}"
  /// The terminal palette of the tests. Each of its colors is different, so
  /// a test can tell which entry a run has.
  public static let palette = DistinctRolesTheme.Role.terminalPalette
  /// The ANSI color number of red (SGR 31).
  public static let redIndex = 1
  /// The ANSI color number of green (SGR 32).
  public static let greenIndex = 2

  /// A run with the text color of ANSI color `index` in ``palette``.
  ///
  /// - Parameters:
  ///   - range: The UTF-8 byte range of the run.
  ///   - index: The ANSI color number.
  /// - Returns: The run.
  @MainActor public static func ansiRun(_ range: Range<Int>, _ index: Int) -> EditorColorRun {
    EditorColorRun(range: range, foreground: palette.ansiColor(index))
  }

  /// A run with the terminal foreground of ``palette``.
  ///
  /// - Parameter range: The UTF-8 byte range of the run.
  /// - Returns: The run.
  @MainActor public static func foregroundRun(_ range: Range<Int>) -> EditorColorRun {
    EditorColorRun(range: range, foreground: palette[.foreground])
  }
}
