import EditorComplete
import EditorExtensions
import FoundationModelsACP

/// The EditorKit completion source for the slash commands of a session
/// (plan.md §4.1, §9 D; update.md §4.2 "Last-value state", §4.4 "Commands
/// not reported").
///
/// The source reads the ACP commands that `SessionModel.availableCommands`
/// holds. It keeps the value that the model gives and no other copy. The
/// value has three states:
///
/// - `nil`: the agent did not report its commands. The source gives no
///   answer, so the composer shows no command menu.
/// - `[]`: the agent reported no command. The source gives an empty list, so
///   the composer shows an empty menu with a short note.
/// - A list: the source lists each command whose name starts with the text
///   after the `/`.
///
/// The source answers only when the caret is in a `/` token at the start of a
/// line. An accepted command inserts `/`, the name, and a space. The row
/// shows the hint of the text input of the command as the detail text.
public nonisolated struct SlashCommandSource: EditorExtensions.CompletionSource {
  /// The text that opens a slash command token.
  public static let trigger = "/"

  /// The token opening of a slash command. The body of the token is a run of
  /// word characters.
  static let opening = CompletionTokenOpening(text: trigger)

  /// The commands that the agent reported, in order, or `nil` when the agent
  /// did not report its commands.
  public let commands: [AvailableCommand]?

  /// Makes a slash command source.
  ///
  /// - Parameter commands: The value of `SessionModel.availableCommands`.
  public init(commands: [AvailableCommand]?) {
    self.commands = commands
  }

  /// The `/` opening, so that the completion engine replaces the full token.
  public var tokenOpenings: [CompletionTokenOpening] {
    [Self.opening]
  }

  /// The commands that match the slash token at the caret.
  ///
  /// - Parameter context: The completion context of the engine.
  /// - Returns: The matching commands. `nil` when the agent did not report
  ///   its commands, or when the caret is not in a slash token at the start
  ///   of a line.
  public func completions(for context: CompletionContext) async -> CompletionResult? {
    guard !Task.isCancelled, let commands else { return nil }
    let line = context.editor.line(containing: context.position)
    guard
      let token = CompletionTokenizer.openedToken(
        line: line, caret: context.position, opening: Self.opening),
      token.replacing.lowerBound.utf8Offset == line.range.lowerBound.utf8Offset
    else {
      return nil
    }
    let query = String(token.prefix.dropFirst(Self.trigger.count))
    return CompletionResult(items: Self.matches(of: query, in: commands).map(Self.completion(for:)))
  }

  /// The commands whose names start with `query`. The comparison ignores
  /// case.
  ///
  /// - Parameters:
  ///   - query: The text after the `/`.
  ///   - commands: The commands to filter.
  /// - Returns: The matching commands, in their order.
  static func matches(of query: String, in commands: [AvailableCommand]) -> [AvailableCommand] {
    let query = query.lowercased()
    return commands.filter { $0.name.lowercased().hasPrefix(query) }
  }

  /// The completion row of one command.
  ///
  /// - Parameter command: The command.
  /// - Returns: A row with the `/` name as the label, the input hint as the
  ///   detail, and the description as the documentation.
  static func completion(for command: AvailableCommand) -> Completion {
    let name = trigger + command.name
    return Completion(
      label: name, insert: .text(name + " "), kind: .function, detail: inputHint(of: command),
      documentation: command.description, filterText: name)
  }

  /// The hint of the text input of a command.
  ///
  /// - Parameter command: The command.
  /// - Returns: The hint of a `text` input, or `nil` for a command with no
  ///   input or with an input type that the kit does not know.
  static func inputHint(of command: AvailableCommand) -> String? {
    guard case .text(let input) = command.input else { return nil }
    return input.hint
  }
}
