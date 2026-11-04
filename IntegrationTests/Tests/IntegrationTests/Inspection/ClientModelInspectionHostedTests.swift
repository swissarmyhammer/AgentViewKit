import AgentViewKitTestSupport
import EditorInspector
import EditorInspectorTestSupport
import EditorSwiftUI
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

  /// The first time of the clock of a timed test.
  static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

  /// The time from the start of the timed tool call to its completion, in
  /// seconds.
  static let toolCallSeconds: TimeInterval = 75

  /// The title, and thus the `toolCallId`, of the timed tool call.
  static let timedCallTitle = "Read README.md"

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
    InspectorRowID.field(view: Object.inspection.id, object: object, group: group, field: field)
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
    #expect(harness.rowValue(row) == "Read")

    try await session.sendUpdate(
      WireBlockJSON.makeToolCallUpdate(id: Self.toolCallID, fields: #""title": "Read Package.swift""#))
    await harness.render { entry.title == "Read Package.swift" }

    #expect(harness.rowValue(row) == "Read Package.swift")
  }

  @Test func theExitRowOfATerminalFollowsItsExit() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      #"{"sessionUpdate": "terminal_update", "terminalId": "\#(Self.terminalID)", "command": "ls"}"#)
    let entry = try await Self.entry(TerminalEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }
    #expect(harness.rowValue(Self.row(of: entry, group: "terminal", field: "command")) == "ls")

    try await session.sendUpdate(
      #"{"sessionUpdate": "terminal_update", "terminalId": "\#(Self.terminalID)", "exitStatus": {"exitCode": 0}}"#)
    await harness.render { entry.exitStatus != nil }

    #expect(
      harness.rowValue(Self.row(of: entry, group: "terminal", field: "exit-status"))
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
    #expect(harness.rowValue(row) == "Hello")

    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: Self.messageID, block: WireBlockJSON.makeText(" there")))
    await harness.render { InspectionText.text(of: entry.content) == "Hello there" }

    #expect(harness.rowValue(row) == "Hello there")
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

    #expect(harness.rowValue(Self.row(of: entry, group: "message", field: "text")) == "Thinking")
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

    #expect(harness.rowValue(Self.row(of: entry, group: "plan", field: "steps")) == "\(WorkStatusLabel.completed): Read")
  }

  @Test func theContextRowOfASessionFollowsItsUsage() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let harness = Self.mount(model)
    defer { harness.close() }
    let row = Self.row(of: model, group: "agent", field: "context-used")
    #expect(harness.rowValue(row) == EditorInspectorStrings.noValue)

    try await session.sendUpdate(#"{"sessionUpdate": "usage_update", "used": 48, "size": 200}"#)
    await harness.render { model.usage != nil }

    #expect(harness.rowValue(row) == "48")
  }

  @Test func theDurationRowOfAToolCallShowsTheTimeToItsCompletion() async throws {
    let clock = FixedClock(start: Self.start)
    let session = try await ScriptedSession.open(now: clock.now)
    defer { session.close() }
    try await session.sendToolCallUpdate(title: Self.timedCallTitle, status: .inProgress)
    let entry = try await Self.entry(ToolCallEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }
    let row = Self.row(of: entry, group: "time", field: "duration")
    #expect(Self.rowValue(row, in: harness) == nil)

    clock.advance(by: Self.toolCallSeconds)
    try await session.sendToolCallUpdate(title: Self.timedCallTitle, status: .completed)
    await harness.render { entry.timing.endedAt != nil }

    let expected = DurationFieldFormat(units: .minutesSeconds).format(.seconds(Self.toolCallSeconds))
    #expect(Self.rowValue(row, in: harness) == expected)
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

    #expect(harness.rowValue(Self.row(of: entry, group: "error", field: "message")) == "It broke.")
  }

  @Test func aUserMessageShowsItsSendState() throws {
    let entry = try #require(PreviewFixtures.entry(.user("Hi"), as: UserMessageEntry.self))
    let harness = Self.mount(entry)
    defer { harness.close() }

    #expect(harness.rowValue(Self.row(of: entry, group: "message", field: "send-state")) == InspectionText.sendState(entry.sendState))
  }

  @Test func aConnectionShowsItsState() {
    let connection = ConnectionModel.preview()
    let harness = Self.mount(connection)
    defer { harness.close() }

    #expect(
      harness.rowValue(Self.row(of: connection, group: "connection", field: "state"))
        == InspectionText.connectionState(connection.state))
  }

  @Test func anMCPServerShowsItsTransport() throws {
    let server = try #require(PreviewFixtures.mcpSession.mcpServers.first)
    let transport = try #require(server.transport)
    let harness = Self.mount(server)
    defer { harness.close() }

    #expect(harness.rowValue(Self.row(of: server, group: "server", field: "transport")) == ConnectionRow.label(for: transport))
  }
}
