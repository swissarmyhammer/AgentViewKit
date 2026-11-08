import EditorCommands
import Testing

@testable import EditorCommandsUI

extension CommandSystem {
  /// Tells if the scope at `path` shows its focus ring now (style.md,
  /// "Selection and focus").
  ///
  /// The test reads the state of the scope, never pixels: the indicator of
  /// the newest beacon at `path` says whether the beacon holds the focus and
  /// whether an item surface of the content shows that focus as a fill.
  ///
  /// - Parameter path: The path of the scope.
  /// - Returns: `true` while the beacon holds the focus and no item surface
  ///   of the scope shows it.
  /// - Throws: An issue when no beacon stands at `path`.
  func showsFocusRing(at path: FocusPath) throws -> Bool {
    let probe = try #require(geometry.newestProbe(at: path) as? GeometryProbeView)
    return probe.focusIndicator.showsRing
  }
}
