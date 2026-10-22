import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

@Suite @MainActor struct PreviewFixturesTests {
  /// The text of the thought of the tests.
  static let thoughtText = "Read the parser first."

  /// The title of the tool call of the tests.
  static let toolCallTitle = "Run swift test"

  @Test func theEntryOfAThoughtItemIsAThoughtEntryWithItsText() throws {
    let entry = try #require(PreviewFixtures.entry(.thought(Self.thoughtText), as: ThoughtEntry.self))

    #expect(entry.content == [.text(TextContent(text: Self.thoughtText))])
  }

  @Test func theEntryOfAnItemOfAnotherKindIsNil() {
    #expect(PreviewFixtures.entry(.thought(Self.thoughtText), as: ToolCallEntry.self) == nil)
  }

  @Test func theFirstEntryOfAKindSkipsTheEntriesOfOtherKinds() {
    let session = SessionModel.preview(transcript: [
      .user("Why does the build fail?"),
      .toolCall(title: Self.toolCallTitle, kind: .execute, status: .pending),
    ])

    #expect(PreviewFixtures.firstEntry(in: session, as: ToolCallEntry.self)?.title == Self.toolCallTitle)
  }

  /// The name of the case of a field kind.
  ///
  /// - Parameter kind: The kind of an elicitation field.
  /// - Returns: The name of the case, such as `text`.
  static func caseName(of kind: ElicitationFieldSchema.Kind) -> String {
    switch kind {
    case .text: "text"
    case .date: "date"
    case .number: "number"
    case .boolean: "boolean"
    case .singleChoice: "singleChoice"
    case .multiChoice: "multiChoice"
    }
  }

  @Test func theElicitationFieldsHoldOneFieldOfEachKindWithItsOwnName() {
    let fields = PreviewFixtures.ElicitationFields.all

    #expect(
      fields.map { Self.caseName(of: $0.kind) }
        == ["text", "number", "boolean", "date", "singleChoice", "multiChoice"])
    #expect(Set(fields.map(\.name)).count == fields.count)
  }

  @Test func theAttachmentsAreFilesOfTheSampleProjectWithTheirOwnIDs() {
    let attachments = PreviewFixtures.attachments

    #expect(!attachments.isEmpty)
    #expect(Set(attachments.map(\.id)).count == attachments.count)
    #expect(attachments.allSatisfy { $0.url.isFileURL && $0.url.lastPathComponent == $0.name })
  }

  @Test func theConfiguredSessionHasAModeOptionForThePicker() {
    let options = PreviewFixtures.configuredSession.configOptions

    #expect(options == PreviewFixtures.configOptions)
    #expect(PermissionModePicker.modeOption(in: options ?? []) != nil)
  }

  @Test func theUsageSessionHoldsTheSampleUsage() {
    #expect(PreviewFixtures.usageSession.usage == PreviewFixtures.usage)
  }

  @Test func theMCPSessionHasAnItemForEachServer() {
    let items = PreviewFixtures.mcpSession.mcpServers

    #expect(items.map(\.server) == PreviewFixtures.mcpServers.map(Optional.some))
  }

  @Test func eachCitationMarkerNamesASourceAndFitsTheResponse() {
    let citations = PreviewFixtures.citations
    let sourceIDs = Set(citations.sources.map(\.id))

    #expect(!citations.markers.isEmpty)
    #expect(citations.markers.allSatisfy { sourceIDs.contains($0.sourceID) })
    #expect(citations.markers.allSatisfy { $0.offset <= PreviewFixtures.citedResponse.count })
  }

  @Test func theElicitationSessionHoldsTheFormRequestThenTheURLRequest() {
    let pending = PreviewFixtures.elicitationSession.pendingElicitations

    #expect(pending.map(\.request) == [PreviewFixtures.formElicitation, PreviewFixtures.urlElicitation])
  }

  @Test func theFormElicitationGivesAFieldForEachPropertyAndNamesWhoAsks() throws {
    let pending = try #require(PreviewFixtures.elicitationSession.pendingElicitations.first)

    #expect(ElicitationView.requestedSchema(of: pending) != .null)
    #expect(
      ElicitationFieldSchema.normalize(from: ElicitationView.requestedSchema(of: pending)).map(\.name)
        == ["name", "retries", "verbose"])
    #expect(!pending.agentPath.isEmpty)
    #expect(pending.source != nil)
  }

  @Test func theURLElicitationNamesTheHostOfItsURL() throws {
    let pending = try #require(PreviewFixtures.elicitationSession.pendingElicitations.last)

    #expect(pending.targetHost == PreviewFixtures.elicitationURLHost)
  }

  @Test func theFieldContextReadsAndWritesTheAnswerOfItsOwnField() {
    var answers: [String: JSONValue] = [:]
    let binding = Binding(get: { answers }, set: { answers = $0 })
    let field = PreviewFixtures.ElicitationFields.text

    let context = PreviewFixtures.fieldContext(field, answers: binding)
    context.value.wrappedValue = .string(Self.thoughtText)

    #expect(context.schema == field)
    #expect(answers == [field.name: .string(Self.thoughtText)])
    #expect(context.value.wrappedValue == .string(Self.thoughtText))
  }

  @Test func theStatusMessagesShowEachLookOfTheBarWithTheirOwnIdentifiers() {
    let messages = PreviewFixtures.statusMessages

    #expect(messages.count == PreviewFixtures.agentStates.count)
    #expect(Set(messages.map(\.identifier)).count == messages.count)
    #expect(messages.contains { $0.isFailure })
    #expect(messages.contains { $0.isOngoing })
    #expect(messages.contains { !$0.isFailure && !$0.isOngoing })
  }

  @Test func theLongStatusMessageIsLongerThanEachStatusMessage() {
    let long = PreviewFixtures.longStatusMessage

    #expect(PreviewFixtures.statusMessages.allSatisfy { long.title.count > $0.title.count })
    #expect(PreviewFixtures.statusMessages.allSatisfy { long.explanation.count > $0.explanation.count })
  }

  @Test func theFailedTurnStatusMessageIsTheFailureOfAnIdleStateWithAnError() {
    let message = PreviewFixtures.failedTurnStatusMessage

    #expect(message.isFailure)
    #expect(message.identifier == StateBanner.failedTurnIdentifier)
  }

  @Test func theStatusActionTakesAPressOnlyWhenItIsEnabled() {
    #expect(PreviewFixtures.statusAction(isEnabled: true).isEnabled)
    #expect(!PreviewFixtures.statusAction(isEnabled: false).isEnabled)
  }

  @Test func theAuthConnectionAsksForASignInWithItsMethods() {
    let methods = [PreviewFixtures.agentAuthMethod, PreviewFixtures.terminalAuthMethod]

    let connection = PreviewFixtures.authConnection(methods: methods)

    #expect(connection.authState == .required(methods))
    #expect(connection.authMethods == methods)
    #expect(connection.canLogin)
  }

  @Test func theAuthConnectionHoldsItsOpenSession() {
    let session = SessionModel.preview()

    let connection = PreviewFixtures.authConnection(methods: [PreviewFixtures.agentAuthMethod], openSessions: [session])

    #expect(connection.openSessions.map(\.sessionId) == [session.sessionId])
  }

  @Test func theAuthConnectionNamesItsAgent() {
    let connection = PreviewFixtures.authConnection(
      methods: [PreviewFixtures.longNameAuthMethod], agentName: PreviewFixtures.longAgentName)

    #expect(connection.initializeResponse?.info.name == PreviewFixtures.longAgentName)
  }

  @Test func theLongNamesAreLongerThanTheOtherNames() throws {
    let longName = try #require(Self.name(of: PreviewFixtures.longNameAuthMethod))
    let otherMethods = [PreviewFixtures.agentAuthMethod, PreviewFixtures.terminalAuthMethod]
    let otherNames = otherMethods.compactMap(Self.name(of:))

    #expect(otherNames.count == otherMethods.count)
    #expect(otherNames.allSatisfy { longName.count > $0.count })
    #expect(PreviewFixtures.longAgentName.count > PreviewFixtures.agentName.count)
  }

  @Test func theTerminalAuthRunnerReportsASuccessfulRun() async throws {
    let status = try await PreviewFixtures.terminalAuthRunner.runTerminalAuth(arguments: [], environment: [:])

    #expect(status == PreviewFixtures.successfulExitStatus)
  }

  @Test func theScrolledSessionHoldsAMessagePairForEachTurn() {
    let transcript = PreviewFixtures.scrolledSession.transcript

    #expect(transcript.count == PreviewFixtures.scrolledTurnCount * Self.messagesPerTurn)
  }

  /// The messages of one turn of the scrolled session: a user message and an
  /// agent message.
  static let messagesPerTurn = 2

  /// The name of an auth method.
  ///
  /// - Parameter method: The auth method.
  /// - Returns: The name of an `agent` or a `terminal` method, or `nil` for a
  ///   method of a type that the kit does not know.
  static func name(of method: AuthMethod) -> String? {
    switch method {
    case .agent(let agent): agent.name
    case .terminal(let terminal): terminal.name
    case .unknown: nil
    }
  }
}
