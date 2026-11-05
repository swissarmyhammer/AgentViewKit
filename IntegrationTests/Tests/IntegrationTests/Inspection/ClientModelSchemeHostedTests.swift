import AgentViewKitTestSupport
import EditorInspector
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The scheme ids that the rows of a shown inspector of a client model
/// carry, as a test out of process reads them: through accessibility, with
/// EditorKit's `InspectorDriver`, with no mouse and no focus.
///
/// Each id is the exact text of the documented format
/// (``InspectableClientModel/inspectorObjectID``): the explicit id of the
/// inspection, and the readable object id of the model, escaped by
/// EditorKit's scheme. No id holds the debug description of an id type of
/// FoundationModelsACP.
@Suite(.serialized, .hostedSerially) @MainActor struct ClientModelSchemeHostedTests {
  /// The raw session id of the tests, with a field separator of the scheme
  /// (`.`).
  static let sessionID = SessionId(rawValue: "sess.1")

  /// The raw id of the tool call of the tests, with a field separator of
  /// the scheme (`.`).
  static let toolCallID = "inspect.call"

  /// The raw id of the agent message of the tests.
  static let messageID = "inspect-message"

  /// The scheme id of the name row of the inspector of the tool call.
  static let toolCallNameRowID = "inspection:tool-call/object:tool-call-inspect%2Ecall/name"

  /// The scheme id of the text row of the inspector of the agent message.
  static let messageTextRowID = "inspection:agent-message/object:agent-message-inspect-message/field:message.text"

  /// The scheme id of the id row of the inspector of the session.
  static let sessionIDRowID = "inspection:session/object:sess%2E1/field:session.id"

  /// The scheme id of the web search row of the config options form of the
  /// session.
  static let webSearchRowID = "inspection:config-options/object:sess%2E1/field:uncategorized.web-search"

  /// The UUID of the id of an entry that the client made.
  ///
  /// - Parameter id: The id of an entry.
  /// - Returns: The UUID, or `nil` for an entry from the wire.
  static func localUUID(of id: TranscriptEntry.ID) -> UUID? {
    if case .local(let uuid) = id { return uuid }
    return nil
  }

  @Test func theNameRowOfAToolCallCarriesItsKindAndItsToolCallID() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      WireBlockJSON.makeToolCallUpdate(id: Self.toolCallID, fields: #""title": "Read", "status": "pending""#))
    let entry = try await ClientModelInspectionHostedTests.entry(ToolCallEntry.self, in: session)
    let harness = ClientModelInspectionHostedTests.mount(entry)
    defer { harness.close() }

    #expect(harness.showsRow(Self.toolCallNameRowID))
  }

  @Test func theTextRowOfAnAgentMessageCarriesItsKindAndItsMessageID() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: Self.messageID, block: WireBlockJSON.makeText("Hi")))
    let entry = try await ClientModelInspectionHostedTests.entry(AgentMessageEntry.self, in: session)
    let harness = ClientModelInspectionHostedTests.mount(entry)
    defer { harness.close() }

    #expect(harness.showsRow(Self.messageTextRowID))
  }

  @Test func theMessageRowOfALocalErrorCarriesItsUUID() throws {
    let entry = try #require(
      PreviewFixtures.entry(.error(code: .internalError, message: "It broke."), as: ErrorEntry.self))
    let uuid = try #require(Self.localUUID(of: entry.id), "The error entry is not local.")
    let harness = ClientModelInspectionHostedTests.mount(entry)
    defer { harness.close() }

    #expect(harness.showsRow("inspection:error/object:local-\(uuid.uuidString)/field:error.message"))
  }

  @Test func theIDRowOfASessionCarriesItsRawSessionID() {
    let harness = ClientModelInspectionHostedTests.mount(SessionModel.preview(sessionId: Self.sessionID))
    defer { harness.close() }

    #expect(harness.showsRow(Self.sessionIDRowID))
  }

  @Test func aRowOfTheConfigOptionsFormCarriesTheRawSessionID() {
    let session = SessionModel.preview(sessionId: Self.sessionID, configOptions: PreviewFixtures.configOptions)
    let harness = HostedViewHarness(
      ConfigOptionsView(session: session, style: .form), size: ClientModelInspectionHostedTests.size)
    defer { harness.close() }
    harness.render()

    #expect(harness.showsRow(Self.webSearchRowID))
  }
}
