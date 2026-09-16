import EditorComplete
import EditorCore
import EditorExtensions
import EditorSwiftUI
import Testing

@testable import AgentViewKit

/// A real EditorKit completion engine over a document, for the completion
/// source tests.
///
/// The document registers the completion session field, and the caret is at
/// the end of the text.
@MainActor struct CompletionFixture {
  /// The engine of the document.
  let document: EditorEngine

  /// The completion engine over the sources.
  let completion: CompletionEngine

  /// Makes a fixture.
  ///
  /// - Parameters:
  ///   - text: The text of the document.
  ///   - sources: The completion sources.
  init(_ text: String, sources: [any EditorExtensions.CompletionSource]) {
    document = EditorEngine(text, fields: [.field(CompletionSessionField.self)])
    completion = CompletionEngine(sources: sources)
    let context = EditorContext(document.state)
    context.dispatch(
      EditorTransaction(
        changes: .identity(length: text.utf8.count), selection: .cursor(context.documentEnd)))
  }

  /// The text of the document.
  var text: String {
    document.state.document.string
  }

  /// Runs the query at the caret now.
  ///
  /// - Returns: The labels of the listed rows, in order.
  func query() async -> [String] {
    await completion.ensureQueried(trigger: .typed, in: EditorContext(document.state)).items.map(\.label)
  }

  /// Accepts the row with `label`.
  ///
  /// - Parameter label: The label of the row.
  /// - Returns: `true` when the engine accepted the row.
  @discardableResult
  func accept(_ label: String) -> Bool {
    let context = EditorContext(document.state)
    let item = context.value(CompletionSessionField.self).items.first { $0.label == label }
    guard let item else { return false }
    return CompletionCommands.accept(item, in: context)
  }
}

@Suite @MainActor struct SlashCommandSourceTests {
  /// The commands of the thread.
  static let commands = [
    SlashCommand(name: "compact", description: "Compact the thread", inputHint: "instructions"),
    SlashCommand(name: "context", description: "Show the context"),
    SlashCommand(name: "plan", description: "Make a plan"),
  ]

  /// A fixture with the slash source over ``commands``.
  static func fixture(_ text: String) -> CompletionFixture {
    CompletionFixture(text, sources: [SlashCommandSource(commands: commands)])
  }

  @Test func aSlashAtTheStartOfTheLineListsEachCommand() async {
    let labels = await Self.fixture("/").query()

    #expect(Set(labels) == ["/compact", "/context", "/plan"])
  }

  @Test func theTextAfterTheSlashFiltersTheCommandsByPrefix() async {
    let labels = await Self.fixture("/co").query()

    #expect(Set(labels) == ["/compact", "/context"])
  }

  @Test func aSlashAfterOtherTextListsNothing() async {
    let labels = await Self.fixture("hello /co").query()

    #expect(labels.isEmpty)
  }

  @Test func aSlashAtTheStartOfALaterLineListsTheCommands() async {
    let labels = await Self.fixture("hello\n/pl").query()

    #expect(labels == ["/plan"])
  }

  @Test func acceptInsertsTheCommandNameAndASpace() async {
    let fixture = Self.fixture("/com")
    _ = await fixture.query()

    #expect(fixture.accept("/compact"))
    #expect(fixture.text == "/compact ")
  }

  @Test func theRowShowsTheInputHintAsTheDetail() {
    let row = SlashCommandSource.completion(for: Self.commands[0])

    #expect(row.label == "/compact")
    #expect(row.detail == "instructions")
    #expect(row.documentation == "Compact the thread")
    #expect(row.insert == .text("/compact "))
  }

  @Test func theFilterIgnoresCase() {
    let matches = SlashCommandSource.matches(of: "PL", in: Self.commands)

    #expect(matches.map(\.name) == ["plan"])
  }

  @Test func theSourceOwnsTheSlashOpening() {
    let source = SlashCommandSource(commands: Self.commands)

    #expect(source.tokenOpenings.map(\.text) == ["/"])
  }
}
