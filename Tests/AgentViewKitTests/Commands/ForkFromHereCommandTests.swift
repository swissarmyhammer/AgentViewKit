@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Tests for Fork from Here, the kit verb that gives a message to the fork
/// action of the host (D205).
///
/// Each test runs the command in the headless harness on a preview session
/// model. The preview model adds each entry when the call returns, so no test
/// waits. No test shows a window.
@MainActor struct ForkFromHereCommandTests {
  /// The title of the verb in the string catalog.
  static let title = "Fork from Here"

  /// The text of the user message of the preview transcript.
  static let question = "Fix the test."

  /// The text of the agent message of the preview transcript.
  static let answer = "The test passes now."

  /// The reason that the host gives when it cannot fork.
  static let hostReason = "This agent cannot fork a session."

  /// The reason of the verb for a message with no `MessageId`.
  static let noMessageIDReason = "The agent has no ID for this message yet."

  /// The reason of the verb when no message is selected.
  static let noMessageReason = "No message is selected."

  /// The requests that the fork action of a test got, in order.
  final class RequestRecorder {
    /// The requests.
    var requests: [ForkFromHereRequest] = []
  }

  /// Makes a preview session model with one user message and one agent
  /// message, each with the `MessageId` of the preview item.
  ///
  /// - Returns: The session model.
  static func makeSession() -> SessionModel {
    .preview(transcript: [.user(question), .agent(answer)])
  }

  /// Makes a harness with the scope of `session` and the item scope of each
  /// message, whose target has the fork action of the host when `recorder`
  /// is not `nil`.
  ///
  /// - Parameters:
  ///   - session: The session model of the scope.
  ///   - recorder: The recorder of the requests of the fork action, or
  ///     `nil` for a host with no fork action.
  ///   - unavailableReason: The reason that the host cannot fork now, or
  ///     `nil`.
  /// - Returns: The fixture.
  static func makeFixture(
    session: SessionModel, recorder: RequestRecorder?, unavailableReason: String? = nil
  ) -> AgentCommandsTests.Fixture {
    AgentCommandsTests.makeFixture(session: session, items: AgentCommandsTests.messageItems(of: session)) { target in
      guard let recorder else { return }
      target.forkFromHere = ForkFromHereAction(unavailableReason: unavailableReason) {
        recorder.requests.append($0)
      }
    }
  }

  /// The path of the item scope of the message at `position` in the
  /// transcript of `session`.
  ///
  /// - Parameters:
  ///   - position: The position of the message entry in the transcript.
  ///   - session: The session model.
  ///   - fixture: The fixture of the scope.
  /// - Returns: The path.
  static func messagePath(
    at position: Int, of session: SessionModel, in fixture: AgentCommandsTests.Fixture
  ) -> FocusPath {
    fixture.path.appending(AgentScopeKind.message(rowKey: session.transcript[position].rowKey))
  }

  /// The availability of Fork from Here at `path`.
  ///
  /// - Parameters:
  ///   - path: The invocation path.
  ///   - fixture: The fixture.
  /// - Returns: The availability.
  /// - Throws: An error when the registry has no Fork from Here.
  static func availability(at path: FocusPath, in fixture: AgentCommandsTests.Fixture) throws -> Availability {
    try CommandTestSupport.availability(
      of: AgentCommandVerb.forkFromHere.id, at: path, in: fixture.system.registry)
  }

  /// The request that Fork from Here gives for the message at `position`.
  ///
  /// - Parameter position: The position of the message entry in the
  ///   transcript.
  /// - Returns: The request that the fork action got.
  /// - Throws: An error when the command did not run, or the action got no
  ///   request.
  static func request(forMessageAt position: Int) throws -> ForkFromHereRequest {
    let session = makeSession()
    let recorder = RequestRecorder()
    let fixture = makeFixture(session: session, recorder: recorder)
    let path = messagePath(at: position, of: session, in: fixture)

    try #require(fixture.system.registry.perform(AgentCommandVerb.forkFromHere.id, at: path, clicked: path))
    return try #require(recorder.requests.only)
  }

  // MARK: - Registry

  @Test func theRegistryHasNoForkFromHereWithNoHostAction() {
    let fixture = Self.makeFixture(session: Self.makeSession(), recorder: nil)

    #expect(fixture.system.registry.definition(for: AgentCommandVerb.forkFromHere.id, at: fixture.path) == nil)
  }

  @Test func theRegistryHasForkFromHereWithItsTitleWithAHostAction() throws {
    let fixture = Self.makeFixture(session: Self.makeSession(), recorder: RequestRecorder())

    let definition = try #require(
      fixture.system.registry.definition(for: CommandID("agent.forkFromHere"), at: fixture.path))

    #expect(CommandTestSupport.staticText(of: definition.title) == Self.title)
  }

  @Test func theRegistrationRemovesForkFromHereWhenTheHostActionGoes() {
    let fixture = Self.makeFixture(session: Self.makeSession(), recorder: RequestRecorder())
    var registry = CommandRegistry()
    AgentCommandRegistration.register(fixture.target, at: fixture.path, into: &registry)
    fixture.target.forkFromHere = nil

    AgentCommandRegistration.register(fixture.target, at: fixture.path, into: &registry)

    #expect(registry.definition(for: AgentCommandVerb.forkFromHere.id, at: fixture.path) == nil)
  }

  // MARK: - Place

  @Test func theVerbIsInTheForkGroup() {
    #expect(AgentCommandVerb.forkFromHere.group == .fork)
  }

  @Test func theForkGroupHasTheIdOfTheKit() {
    #expect(AgentCommandGroup.fork.id == "agent.fork")
  }

  @Test func theVerbHasNoKey() {
    #expect(AgentKeymap.defaultChords[.forkFromHere] == nil)
  }

  @Test func theVerbIsInTheThreadGroupOfTheSessionMenuAfterExport() throws {
    let menu = try #require(AgentCommandVerb.forkFromHere.menu)
    let export = try #require(AgentCommandVerb.exportMarkdown.menu)

    #expect(menu == MenuPlacement(path: .session, group: export.group, order: export.order + 1))
  }

  @Test func theVerbHasTheForkSymbol() {
    #expect(AgentCommandVerb.forkFromHere.icon == AgentSymbol.fork)
  }

  @Test func theContextMenuOfAMessageShowsForkFromHereAfterCopyMessage() {
    let session = Self.makeSession()
    let fixture = Self.makeFixture(session: session, recorder: RequestRecorder())
    let path = Self.messagePath(at: 0, of: session, in: fixture)

    let ids = fixture.system.registry.contextMenuMirror(at: path).map(\.id)

    #expect(ids == [AgentCommandVerb.copyMessage, .forkFromHere, .jumpToNext, .jumpToPrevious].map(\.id))
  }

  // MARK: - Availability

  @Test func theHostReasonDisablesTheVerb() throws {
    let session = Self.makeSession()
    let fixture = Self.makeFixture(session: session, recorder: RequestRecorder(), unavailableReason: Self.hostReason)
    let path = Self.messagePath(at: 1, of: session, in: fixture)

    #expect(try Self.availability(at: path, in: fixture) == .unavailable(reason: Self.hostReason))
  }

  /// A local user message has no `MessageId` until the agent answers the
  /// prompt. The sender of the test never answers, so the message keeps no
  /// id. The test waits until the model holds the message.
  @Test func aMessageWithNoMessageIDDisablesTheVerb() async throws {
    let session = SessionModel.preview(requestSender: PreviewSessionRequestSender(answer: .never))
    let prompt = Task { try? await session.prompt([.text(TextContent(text: Self.question))]) }
    defer { prompt.cancel() }
    await ObservationWait.until { session.transcript.count == 1 }
    let fixture = Self.makeFixture(session: session, recorder: RequestRecorder())
    let path = Self.messagePath(at: 0, of: session, in: fixture)

    #expect(try Self.availability(at: path, in: fixture) == .unavailable(reason: Self.noMessageIDReason))
  }

  @Test func theVerbIsDisabledWithNoSelectedMessage() throws {
    let fixture = Self.makeFixture(session: Self.makeSession(), recorder: RequestRecorder())

    #expect(try Self.availability(at: fixture.path, in: fixture) == .unavailable(reason: Self.noMessageReason))
  }

  // MARK: - Request

  @Test func anAgentMessageGivesARequestAfterTheMessageWithNoText() throws {
    let request = try Self.request(forMessageAt: 1)

    #expect(request == ForkFromHereRequest(messageId: MessageId(rawValue: "preview-1"), side: .after, text: nil))
  }

  @Test func aUserMessageGivesARequestBeforeTheMessageWithItsText() throws {
    let request = try Self.request(forMessageAt: 0)

    #expect(
      request == ForkFromHereRequest(messageId: MessageId(rawValue: "preview-0"), side: .before, text: Self.question))
  }

  // MARK: - Message action

  @Test func theForkButtonOfAMessageIsTheButtonOfTheVerb() {
    #expect(MessageActions.Action.fork.verb == .forkFromHere)
  }

  @Test func theForkButtonHasTheMessageForkIdentifier() {
    #expect(MessageActions.Action.fork.identifier == "message-fork")
  }

  @Test func theActionRowOfAUserMessageHasTheForkButtonAfterExport() {
    #expect(MessageActions.actions(for: .user, canFork: true) == [.copy, .copyThread, .export, .fork, .edit])
  }

  @Test func theActionRowOfAnAgentMessageHasTheForkButtonAfterExport() {
    #expect(MessageActions.actions(for: .assistant, canFork: true) == [.copy, .copyThread, .export, .fork, .retry])
  }

  @Test func theActionRowHasNoForkButtonWhenTheVerbIsNotInTheRegistry() {
    #expect(!MessageActions.actions(for: .assistant, canFork: false).contains(.fork))
  }

  @Test func theForkButtonWithNoScopeIsDisabledWithTheHostReason() throws {
    let session = Self.makeSession()
    let entry = try #require(PreviewFixtures.firstEntry(in: session, as: AgentMessageEntry.self))
    let action = ForkFromHereAction(unavailableReason: Self.hostReason) { _ in }

    #expect(action.unavailableReason(for: .agent(entry)) == Self.hostReason)
  }
}

extension Array {
  /// The one element of the array, or `nil` when the array does not hold
  /// exactly one element.
  fileprivate var only: Element? {
    count == 1 ? first : nil
  }
}
