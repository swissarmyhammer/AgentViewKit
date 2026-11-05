import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI

/// The bindings of the declined-key tests (^zb5td6w): a chord bound to the
/// command under test at its scope, and the same chord bound after it to a
/// recording command of the host, which runs when the key goes on.
@MainActor enum FallbackKeyBinding {
  /// The id of the recording command of the host.
  static let fallbackID: CommandID = "host.fallback"

  /// Binds `chord` to `commandID` at `scope`, and then to a recording command
  /// at `host`, so the command under test is the first binding of the chord.
  ///
  /// - Parameters:
  ///   - chord: The chord.
  ///   - commandID: The id of the command under test.
  ///   - scope: The path that binds the command under test.
  ///   - host: The path of the recording command: `scope` or a scope around
  ///     it.
  ///   - system: The command system of the window.
  /// - Returns: The log of the recording command.
  static func bind(
    _ chord: KeyChord, to commandID: CommandID, at scope: FocusPath, fallbackAt host: FocusPath,
    in system: CommandSystem
  ) -> CommandRunLog {
    system.registry.bindKey(chord.asSequence, to: .command(commandID), mode: .cua, at: scope)
    let fallbacks = CommandRunLog()
    system.registry.register(.makeRecording(id: fallbackID, keys: [.cua: chord], log: fallbacks), at: host)
    return fallbacks
  }
}
