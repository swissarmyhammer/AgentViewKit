import EditorCommands
import EditorCommandsUI
import Testing

@testable import AgentViewKit

/// The checks that the command test suites share.
///
/// Each check reads a registry or the verbs with no view, so no check waits
/// or shows a window.
@MainActor enum CommandTestSupport {
  /// The prefix of each command id of the kit.
  static let kitPrefix = "agent."

  /// The text of a static title.
  ///
  /// - Parameter title: The title of a definition.
  /// - Returns: The text, or `nil` when the title is not static.
  static func staticText(of title: CommandTitle) -> String? {
    if case .static(let text) = title { text } else { nil }
  }

  /// The availability of the command `id` at `path`, as the surfaces of
  /// EditorKit read it.
  ///
  /// - Parameters:
  ///   - id: The command id.
  ///   - path: The invocation path.
  ///   - registry: The registry with the command.
  ///   - sourceLocation: The place of the call, for a failure.
  /// - Returns: `.available` for an enabled row, otherwise `.unavailable`
  ///   with the reason of the row.
  /// - Throws: An error when the registry has no eligible row of `id` at
  ///   `path`.
  static func availability(
    of id: CommandID, at path: FocusPath, in registry: CommandRegistry,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> Availability {
    let row = try #require(
      registry.eligible(path: path).first { $0.id == id }, sourceLocation: sourceLocation)
    return row.isEnabled ? .available : .unavailable(reason: row.reason ?? "")
  }

  /// Expects that the command id of each verb is the kit prefix and the raw
  /// value of the verb, `agent.<verb>`.
  ///
  /// - Parameters:
  ///   - verbs: The verbs.
  ///   - id: Gives the command id of a verb.
  ///   - sourceLocation: The place of the call, for a failure.
  static func expectKitPrefix<Verb: RawRepresentable<String>>(
    of verbs: some Sequence<Verb>, id: (Verb) -> CommandID,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    for verb in verbs {
      #expect(id(verb).rawValue == kitPrefix + verb.rawValue, sourceLocation: sourceLocation)
    }
  }
}
