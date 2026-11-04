import AgentViewKitTestSupport
import EditorInspector
import EditorInspectorTestSupport
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The `Inspectable` conformances of the client models in an EditorKit
/// `InspectorView`, in a real window.
///
/// Each test inspects one model and reads one row with EditorKit's
/// `InspectorDriver`, by its scheme id: the view, the object, the group and
/// the field (``row(of:group:field:)``). A live test sends a `session/update`
/// from the scripted agent, waits for the model value that the update is
/// certain to change, and reads the row again.
@Suite(.serialized, .hostedSerially) @MainActor struct ClientModelInspectionHostedTests {
  /// The width of the window: about the width of an inspector column, in
  /// points.
  static let width: CGFloat = 360

  /// The height of the window, in points.
  static let height: CGFloat = 640

  /// The size of the window.
  static let size = CGSize(width: width, height: height)

  /// The id of the tool call of the tests.
  static let toolCallID = "inspect-call"

  /// The id of the terminal of the tests.
  static let terminalID = "inspect-terminal"

  /// The id of the agent message of the tests.
  static let messageID = "inspect-message"

  /// Mounts an `InspectorView` of `object` and makes one render pass.
  ///
  /// - Parameter object: The model to inspect.
  /// - Returns: The harness. The caller closes it.
  static func mount<Object: Inspectable>(_ object: Object) -> HostedViewHarness<InspectorView> {
    let harness = HostedViewHarness(InspectorView(object), size: size)
    harness.render()
    return harness
  }

  /// The scheme id of a row of the `InspectorView` of `object`: the view and
  /// the object id of its inspection, the group and the field.
  ///
  /// - Parameters:
  ///   - object: The inspected model.
  ///   - group: The group part, such as `tool-call`.
  ///   - field: The field part, such as `title`.
  /// - Returns: The id that the row carries.
  static func row<Object: Inspectable>(of object: Object, group: String, field: String) -> String {
    let view = Object.inspection.id
    return InspectorDriver.field(
      view: view, object: InspectorScheme.objectID(of: [object], key: view), group: group, field: field)
  }

  /// The value that the row of `identifier` shows, read by EditorKit's
  /// `InspectorDriver`.
  ///
  /// - Parameters:
  ///   - identifier: The scheme id of the row.
  ///   - harness: The harness of the view.
  /// - Returns: The value, or `nil` when no row has the identifier.
  static func rowValue(_ identifier: String, in harness: HostedViewHarness<InspectorView>) -> String? {
    InspectorDriver(window: harness.window, root: harness.hostingView).value(of: identifier)
  }

  /// The first entry of `type` in the transcript of `session`, after it
  /// arrives.
  ///
  /// - Parameters:
  ///   - type: The class of the entry.
  ///   - session: The scripted session.
  /// - Returns: The entry.
  /// - Throws: When no entry of the type arrives.
  static func entry<Entry: AnyObject>(_ type: Entry.Type, in session: ScriptedSession) async throws -> Entry {
    let model = session.model
    await ObservationWait.until { PreviewFixtures.firstEntry(in: model, as: type) != nil }
    return try #require(PreviewFixtures.firstEntry(in: model, as: type))
  }

  // MARK: - Live

  @Test func theTitleRowOfAToolCallFollowsItsTitle() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      WireBlockJSON.makeToolCallUpdate(id: Self.toolCallID, fields: #""title": "Read", "status": "pending""#))
    let entry = try await Self.entry(ToolCallEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }
    let row = Self.row(of: entry, group: "tool-call", field: "title")
    #expect(Self.rowValue(row, in: harness) == "Read")

    try await session.sendUpdate(
      WireBlockJSON.makeToolCallUpdate(id: Self.toolCallID, fields: #""title": "Read Package.swift""#))
    await harness.render { entry.title == "Read Package.swift" }

    #expect(Self.rowValue(row, in: harness) == "Read Package.swift")
  }

  @Test func theExitRowOfATerminalFollowsItsExit() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      #"{"sessionUpdate": "terminal_update", "terminalId": "\#(Self.terminalID)", "command": "ls"}"#)
    let entry = try await Self.entry(TerminalEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }
    #expect(Self.rowValue(Self.row(of: entry, group: "terminal", field: "command"), in: harness) == "ls")

    try await session.sendUpdate(
      #"{"sessionUpdate": "terminal_update", "terminalId": "\#(Self.terminalID)", "exitStatus": {"exitCode": 0}}"#)
    await harness.render { entry.exitStatus != nil }

    #expect(
      Self.rowValue(Self.row(of: entry, group: "terminal", field: "exit-status"), in: harness)
        == TerminalView.ExitSummary(code: 0, signal: nil).label)
  }

  @Test func theTextRowOfAnAgentMessageFollowsItsChunks() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: Self.messageID, block: WireBlockJSON.makeText("Hello")))
    let entry = try await Self.entry(AgentMessageEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }
    let row = Self.row(of: entry, group: "message", field: "text")
    #expect(Self.rowValue(row, in: harness) == "Hello")

    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: Self.messageID, block: WireBlockJSON.makeText(" there")))
    await harness.render { InspectionText.text(of: entry.content) == "Hello there" }

    #expect(Self.rowValue(row, in: harness) == "Hello there")
  }

  @Test func theTextRowOfAThoughtFollowsItsChunks() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_thought_chunk", messageID: Self.messageID, block: WireBlockJSON.makeText("Think")))
    let entry = try await Self.entry(ThoughtEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }

    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_thought_chunk", messageID: Self.messageID, block: WireBlockJSON.makeText("ing")))
    await harness.render { InspectionText.text(of: entry.content) == "Thinking" }

    #expect(Self.rowValue(Self.row(of: entry, group: "message", field: "text"), in: harness) == "Thinking")
  }

  @Test func theStepsRowOfAPlanFollowsItsSteps() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(Self.planUpdate(status: "pending"))
    let entry = try await Self.entry(PlanTranscriptEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }

    try await session.sendUpdate(Self.planUpdate(status: "completed"))
    await harness.render { entry.entries.first?.status == .completed }

    #expect(Self.rowValue(Self.row(of: entry, group: "plan", field: "steps"), in: harness) == "\(WorkStatusLabel.completed): Read")
  }

  @Test func theContextRowOfASessionFollowsItsUsage() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let harness = Self.mount(model)
    defer { harness.close() }
    let row = Self.row(of: model, group: "agent", field: "context-used")
    #expect(Self.rowValue(row, in: harness) == EditorInspectorStrings.noValue)

    try await session.sendUpdate(#"{"sessionUpdate": "usage_update", "used": 48, "size": 200}"#)
    await harness.render { model.usage != nil }

    #expect(Self.rowValue(row, in: harness) == "48")
  }

  /// A `plan_update` with one step, `Read`.
  ///
  /// - Parameter status: The wire status of the step.
  /// - Returns: The JSON text of the update.
  static func planUpdate(status: String) -> String {
    #"""
    {"sessionUpdate": "plan_update", "plan": {"type": "items", "planId": "inspect-plan",
     "entries": [{"content": "Read", "priority": "high", "status": "\#(status)"}]}}
    """#
  }

  // MARK: - Fields

  @Test func anErrorShowsItsMessage() throws {
    let entry = try #require(
      PreviewFixtures.entry(.error(code: .internalError, message: "It broke."), as: ErrorEntry.self))
    let harness = Self.mount(entry)
    defer { harness.close() }

    #expect(Self.rowValue(Self.row(of: entry, group: "error", field: "message"), in: harness) == "It broke.")
  }

  @Test func aUserMessageShowsItsSendState() throws {
    let entry = try #require(PreviewFixtures.entry(.user("Hi"), as: UserMessageEntry.self))
    let harness = Self.mount(entry)
    defer { harness.close() }

    #expect(Self.rowValue(Self.row(of: entry, group: "message", field: "send-state"), in: harness) == InspectionText.sendState(entry.sendState))
  }

  @Test func aConnectionShowsItsState() {
    let connection = ConnectionModel.preview()
    let harness = Self.mount(connection)
    defer { harness.close() }

    #expect(
      Self.rowValue(Self.row(of: connection, group: "connection", field: "state"), in: harness)
        == InspectionText.connectionState(connection.state))
  }

  @Test func anMCPServerShowsItsTransport() throws {
    let server = try #require(PreviewFixtures.mcpSession.mcpServers.first)
    let transport = try #require(server.transport)
    let harness = Self.mount(server)
    defer { harness.close() }

    #expect(Self.rowValue(Self.row(of: server, group: "server", field: "transport"), in: harness) == ConnectionRow.label(for: transport))
  }
}
