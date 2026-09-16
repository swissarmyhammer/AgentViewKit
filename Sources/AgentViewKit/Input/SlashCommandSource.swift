import EditorComplete
import EditorExtensions

/// The EditorKit completion source for the slash commands of a thread
/// (plan.md §4.1, §9 D).
///
/// The source answers only when the caret is in a `/` token at the start of a
/// line. It lists each command whose name starts with the text after the `/`.
/// An accepted command inserts `/`, the name, and a space. The row shows the
/// ``SlashCommand/inputHint`` as the detail text.
public nonisolated struct SlashCommandSource: EditorExtensions.CompletionSource {
  /// The text that opens a slash command token.
  public static let trigger = "/"

  /// The token opening of a slash command. The body of the token is a run of
  /// word characters.
  static let opening = CompletionTokenOpening(text: trigger)

  /// The commands that the source lists, in order.
  public let commands: [SlashCommand]

  /// Makes a slash command source.
  ///
  /// - Parameter commands: The commands that the source lists.
  public init(commands: [SlashCommand]) {
    self.commands = commands
  }

  /// The `/` opening, so that the completion engine replaces the full token.
  public var tokenOpenings: [CompletionTokenOpening] {
    [Self.opening]
  }

  /// The commands that match the slash token at the caret.
  ///
  /// - Parameter context: The completion context of the engine.
  /// - Returns: The matching commands, or `nil` when the caret is not in a
  ///   slash token at the start of a line.
  public func completions(for context: CompletionContext) async -> CompletionResult? {
    guard !Task.isCancelled else { return nil }
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
  static func matches(of query: String, in commands: [SlashCommand]) -> [SlashCommand] {
    let query = query.lowercased()
    return commands.filter { $0.name.lowercased().hasPrefix(query) }
  }

  /// The completion row of one command.
  ///
  /// - Parameter command: The command.
  /// - Returns: A row with the `/` name as the label, the input hint as the
  ///   detail, and the description as the documentation.
  static func completion(for command: SlashCommand) -> Completion {
    let name = trigger + command.name
    return Completion(
      label: name, insert: .text(name + " "), kind: .function, detail: command.inputHint,
      documentation: command.description, filterText: name)
  }
}
