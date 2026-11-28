import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The look of a row of message actions in an agent command scope: the
/// chrome line of the flat form of a static message row draws each button
/// in the state that the registry gives its command button (card ^grwk69d).
@MainActor struct MessageActionsLookTests {
  /// The look of the actions of the agent message of a fixture, and the
  /// availability that the registry gives each command of a button at the
  /// item scope of that message.
  ///
  /// - Parameter unavailableReason: The reason that the host cannot fork
  ///   now, or `nil`.
  /// - Returns: The enabled state of each button of the look, and the
  ///   enabled state that the registry gives the command of each button
  ///   with a verb, by title.
  static func lookAndRegistry(
    unavailableReason: String?
  ) throws -> (look: [String: Bool], registry: [String: Bool]) {
    let session = ForkFromHereCommandTests.makeSession()
    let fixture = ForkFromHereCommandTests.makeFixture(
      session: session, recorder: ForkFromHereCommandTests.RequestRecorder(),
      unavailableReason: unavailableReason)
    let entry = try #require(PreviewFixtures.firstEntry(in: session, as: AgentMessageEntry.self))
    let path = ForkFromHereCommandTests.messagePath(at: 1, of: session, in: fixture)
    let context = MessageActions.Context(
      session: session, commandTarget: fixture.target, forkFromHere: fixture.target.forkFromHere, groupsOff: [])
    let look = Dictionary(
      uniqueKeysWithValues: context.look(for: .agent(entry)).buttons.map { ($0.title, $0.isEnabled) })
    let actions = context.actions(for: .assistant).filter { $0.verb != nil }
    let registry = try Dictionary(
      uniqueKeysWithValues: actions.map { action in
        let verb = try #require(action.verb)
        let availability = try CommandTestSupport.availability(of: verb.id, at: path, in: fixture.system.registry)
        return (action.title, availability.isAvailable)
      })
    return (look.filter { registry.keys.contains($0.key) }, registry)
  }

  /// A production change that fails this test: in a scope, the look reads
  /// the state of a command with another item than the message of the
  /// row, so a picture shows Fork from Here enabled where the real button
  /// of the row is disabled, or the reverse.
  @Test func eachCommandButtonOfTheLookHasTheStateOfTheRegistryAtTheMessage() throws {
    let (look, registry) = try Self.lookAndRegistry(unavailableReason: nil)

    #expect(look == registry)
  }

  /// A production change that fails this test: in a scope, the look reads
  /// no reason of the host, so a picture shows Fork from Here enabled while
  /// the real button of the row is disabled.
  @Test func theReasonOfTheHostDisablesTheForkButtonOfTheLookAsTheRegistryDoes() throws {
    let (look, registry) = try Self.lookAndRegistry(unavailableReason: ForkFromHereCommandTests.hostReason)

    #expect(look == registry)
  }
}
