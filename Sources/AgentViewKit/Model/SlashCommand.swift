/// A command that the agent makes available to the user (plan.md §3.2).
///
/// The fields are the fields of an ACP `AvailableCommand`. The slash
/// completion source of the composer reads a list of these values.
public nonisolated struct SlashCommand: Sendable, Hashable, Identifiable {
  /// The command name, without the leading `/`. The name identifies the
  /// command.
  public var name: String

  /// The text that tells the user what the command does.
  public var description: String

  /// The hint for the text after the command name, or `nil` when the command
  /// takes no input.
  public var inputHint: String?

  /// The identifier of the command. This is ``name``.
  public var id: String { name }

  /// Makes a slash command.
  ///
  /// - Parameters:
  ///   - name: The command name, without the leading `/`.
  ///   - description: The text that tells the user what the command does.
  ///   - inputHint: The hint for the text after the command name, or `nil`.
  public init(name: String, description: String, inputHint: String? = nil) {
    self.name = name
    self.description = description
    self.inputHint = inputHint
  }
}
