import EditorCommands
import EditorCommandsUI
import Testing

/// Checks on the window undo commands of EditorKit (EK-6).
///
/// Each root `.commandScope` of a window registers `edit.undo` and
/// `edit.redo` at its root path, beside the commands that the kit registers
/// there. The kit never removes them. The two commands are unavailable while
/// the undo stack of the window has nothing to undo or redo. The suites that
/// read the commands of a kit scope at a root path use these checks.
enum WindowUndoChecks {
  /// The ids of the two commands that EditorKit registers at each root scope.
  static let commandIDs: Set<CommandID> = [.undo, .redo]

  /// The ids of the commands at `path`, without the window undo commands.
  ///
  /// - Parameters:
  ///   - path: The path of the scope.
  ///   - system: The command system of the window.
  /// - Returns: The ids of the commands that the kit registers at `path`.
  @MainActor static func kitCommandIDs(at path: FocusPath, in system: CommandSystem) -> Set<CommandID> {
    Set(system.registry.definitions(at: path).map(\.id)).subtracting(commandIDs)
  }

  /// Expects that the root scope at `path` has an empty undo stack, and that
  /// `edit.undo` and `edit.redo` are registered there and unavailable.
  ///
  /// - Parameters:
  ///   - path: The root path of the window.
  ///   - system: The command system of the window.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: The error of `#require` when the root has no undo stack.
  @MainActor static func expectUnavailableOnAnEmptyStack(
    at path: FocusPath, in system: CommandSystem, sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let stack = try #require(system.undo.stack(for: path), sourceLocation: sourceLocation)
    #expect(!stack.canUndo, sourceLocation: sourceLocation)
    #expect(!stack.canRedo, sourceLocation: sourceLocation)
    let rows = system.registry.eligible(path: path).filter { commandIDs.contains($0.id) }
    #expect(Set(rows.map(\.id)) == commandIDs, sourceLocation: sourceLocation)
    #expect(rows.allSatisfy { !$0.isEnabled }, "\(rows)", sourceLocation: sourceLocation)
  }
}
