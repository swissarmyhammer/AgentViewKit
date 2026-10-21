import EditorCommands
import EditorCommandsUI

/// The one dispatch call of the targets of the agent scopes.
///
/// ``AgentCommandTarget`` and ``AgentAttachmentTarget`` run their verbs
/// through this call. Thus a button, a key and the palette run a command with
/// the same rule in each scope.
@MainActor
enum AgentCommandDispatch {
  /// Runs the command `id` through the registry of `system`, at `path`.
  ///
  /// - Parameters:
  ///   - id: The id of the command.
  ///   - system: The command system that the scope registered the command
  ///     in, or `nil`.
  ///   - path: The path of the scope in `system`, or `nil`.
  ///   - payload: The payload of the dispatch, or `nil`.
  /// - Returns: `true` when a command ran. `false` when there is no system or
  ///   no path, or when the command is not available.
  static func perform(
    _ id: CommandID, in system: CommandSystem?, at path: FocusPath?, payload: CommandPayload? = nil
  ) -> Bool {
    guard let system, let path else { return false }
    return system.registry.perform(id, at: path, payload: payload)
  }
}
