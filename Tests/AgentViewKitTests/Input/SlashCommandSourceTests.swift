import AgentViewKitTestSupport
import EditorComplete
import EditorCore
import EditorExtensions
import EditorSwiftUI
import Foundation
import FoundationModelsACP
import Testing

@testable import AgentViewKit

@Suite @MainActor struct SlashCommandSourceTests {
  /// The slash commands of the session.
  static let wire = [
    Command(
      description: "Compact the thread", name: "compact",
      input: .text(TextCommandInput(hint: "instructions"))),
    Command(description: "Show the context", name: "context"),
    Command(description: "Make a plan", name: "plan"),
  ]

  /// The available commands of the session: the slash commands, and a command
  /// of a kind that the kit does not know.
  static let commands =
    wire.map(AvailableCommand.command) + [.unknown("macro", .object([:]))]

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
    let row = SlashCommandSource.completion(for: Self.wire[0])

    #expect(row.label == "/compact")
    #expect(row.detail == "instructions")
    #expect(row.documentation == "Compact the thread")
    #expect(row.insert == .text("/compact "))
  }

  @Test func theFilterIgnoresCase() {
    let matches = SlashCommandSource.matches(of: "PL", in: Self.commands)

    #expect(matches.map(\.name) == ["plan"])
  }

  @Test func aCommandOfAnUnknownKindIsNotListed() async {
    let labels = await Self.fixture("/").query()

    #expect(!labels.contains { $0.contains("macro") })
    #expect(SlashCommandSource.matches(of: "", in: Self.commands).count == Self.wire.count)
  }

  @Test func theSourceOwnsTheSlashOpening() {
    let source = SlashCommandSource(commands: Self.commands)

    #expect(source.tokenOpenings.map(\.text) == ["/"])
  }
}
