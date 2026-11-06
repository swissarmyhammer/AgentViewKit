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

/// The inspections of the client models in an EditorKit `InspectorView`, in
/// a real window.
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

  /// The working directory of the terminal of the tests.
  static let terminalFolder = "/tmp/inspect-terminal"

  /// The files of the locations of the tool call of the tests, in the
  /// order of the agent.
  static let locationFiles = ["/tmp/inspect-call/Package.swift", "/tmp/inspect-call/README.md"]

  /// The line of each location of the tool call of the tests.
  static let locationLine = 12

  /// The additional directories of the session of the tests, in order.
  static let additionalFolders = ["/tmp/inspect-session/Sources", "/tmp/inspect-session/Tests"]

  /// The id of the agent message of the tests.
  static let messageID = "inspect-message"

  /// A time from the start of a tool call to its completion that is
  /// shorter than `EntryTimingView.shortestShownDuration`, in seconds.
  nonisolated static let tooShortSeconds: TimeInterval = 0.2

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

  /// Mounts an `InspectorView` of the client model `model`, which the view
  /// shows through its `InspectedClientModel`, and makes one render pass.
  ///
  /// - Parameter model: The model to inspect.
  /// - Returns: The harness. The caller closes it.
  static func mount<Model: InspectableClientModel>(_ model: Model) -> HostedViewHarness<InspectorView> {
    mount(InspectedClientModel(model))
  }

  /// The scheme id of a row of the `InspectorView` of the client model
  /// `model`: the view and the object id of its `InspectedClientModel`, the
  /// group and the field.
  ///
  /// - Parameters:
  ///   - model: The inspected model.
  ///   - group: The group part, such as `tool-call`.
  ///   - field: The field part, such as `title`.
  /// - Returns: The id that the row carries.
  static func row<Model: InspectableClientModel>(of model: Model, group: String, field: String) -> String {
    row(of: InspectedClientModel(model), group: group, field: field)
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

  @Test func theStatusRowOfAToolCallFollowsItsStatus() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendToolCallUpdate(title: Self.timedCallTitle, status: .inProgress)
    let entry = try await Self.entry(ToolCallEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }
    let row = Self.row(of: entry, group: "tool-call", field: "status")
    #expect(harness.rowValue(row) == EditorStatus(EditorSymbol.Status.inProgress).label)

    try await session.sendToolCallUpdate(title: Self.timedCallTitle, status: .completed)
    await harness.render { entry.shownStatus == .completed }

    #expect(harness.rowValue(row) == EditorStatus(EditorSymbol.Status.completed).label)
  }

  @Test func theStatusRowOfAnMCPServerShowsTheReasonOfAFailure() async throws {
    let session = try await MCPServersHostedTests.openSessionWithTwoServers()
    defer { session.close() }
    let model = session.model
    let server = try #require(model.mcpServers.first { $0.name == MCPServersHostedTests.filesName })
    let harness = Self.mount(server)
    defer { harness.close() }
    let row = Self.row(of: server, group: "server", field: "status")

    try await session.sendUpdate(
      MCPServersHostedTests.makeStatusUpdate(
        name: MCPServersHostedTests.filesName, transport: MCPServersHostedTests.stdioTransport, status: "failed",
        reason: MCPServersHostedTests.failureReason))
    await harness.render {
      MCPServersHostedTests.server(
        MCPServersHostedTests.filesName, has: .failed(reason: MCPServersHostedTests.failureReason), in: model)
    }

    #expect(harness.rowValue(row) == EditorStatus(EditorSymbol.Status.failed).label)
    #expect(harness.inspectorDriver.statusDetail(of: row) == MCPServersHostedTests.failureReason)
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

  @Test func theWorkingDirectoryRowOfATerminalShowsItsFolder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      #"""
      {"sessionUpdate": "terminal_update", "terminalId": "\#(Self.terminalID)", "command": "ls",
       "cwd": "\#(Self.terminalFolder)"}
      """#)
    let entry = try await Self.entry(TerminalEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }

    #expect(
      harness.rowValue(Self.row(of: entry, group: "terminal", field: "working-directory"))
        == InspectionPath.folder(entry.cwd).path(percentEncoded: false))
  }

  @Test func theWorkingDirectoryRowOfASessionShowsItsFolder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let cwd = try #require(model.cwd)
    let harness = Self.mount(model)
    defer { harness.close() }

    #expect(
      harness.rowValue(Self.row(of: model, group: "session", field: "working-directory"))
        == InspectionPath.folder(cwd).path(percentEncoded: false))
  }

  /// The `tool_call_update` of the tool call of the tests with a location
  /// for each of ``locationFiles``, each at ``locationLine``.
  static var locationsUpdate: String {
    let locations = locationFiles.map { #"{"path": "\#($0)", "line": \#(locationLine)}"# }
    return WireBlockJSON.makeToolCallUpdate(
      id: toolCallID, fields: #""locations": [\#(locations.joined(separator: ", "))]"#)
  }

  /// The paths that the chips of the paths row `row` show, in order: the
  /// accessibility value of each chip.
  ///
  /// - Parameters:
  ///   - row: The scheme id of the paths row.
  ///   - harness: The harness that shows the row.
  /// - Returns: The paths.
  static func chipPaths<Content: View>(in row: String, of harness: HostedViewHarness<Content>) -> [String] {
    chipText(in: row, of: harness, accessibilityValue(of:))
  }

  /// The names that the chips of the paths row `row` show, in order: the
  /// accessibility label of each chip.
  ///
  /// - Parameters:
  ///   - row: The scheme id of the paths row.
  ///   - harness: The harness that shows the row.
  /// - Returns: The names.
  static func chipNames<Content: View>(in row: String, of harness: HostedViewHarness<Content>) -> [String] {
    chipText(in: row, of: harness, accessibilityLabel(of:))
  }

  /// The text that `accessor` reads from each chip of the paths row `row`, in order.
  ///
  /// - Parameters:
  ///   - row: The scheme id of the paths row.
  ///   - harness: The harness that shows the row.
  ///   - accessor: The accessibility text of a chip.
  /// - Returns: The text of each chip that has it.
  private static func chipText<Content: View>(
    in row: String, of harness: HostedViewHarness<Content>, _ accessor: (NSObject) -> String?
  ) -> [String] {
    harness.inspectorDriver.pathChips(in: row).compactMap(accessor)
  }

  @Test func theLocationsRowOfAToolCallFollowsItsLocations() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      WireBlockJSON.makeToolCallUpdate(id: Self.toolCallID, fields: #""title": "Read", "status": "pending""#))
    let entry = try await Self.entry(ToolCallEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }
    let row = Self.row(of: entry, group: "tool-call", field: "locations")
    #expect(harness.rowValue(row) == EditorInspectorStrings.noValue)

    try await session.sendUpdate(Self.locationsUpdate)
    await harness.render { entry.locations.count == Self.locationFiles.count }

    #expect(Self.chipPaths(in: row, of: harness) == Self.locationFiles)
  }

  @Test func theLocationsRowOfAToolCallShowsTheLineOfEachLocation() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(Self.locationsUpdate)
    let entry = try await Self.entry(ToolCallEntry.self, in: session)
    let harness = Self.mount(entry)
    defer { harness.close() }
    let row = Self.row(of: entry, group: "tool-call", field: "locations")

    let names = Self.locationFiles.map { PathChip.Parts(path: $0, line: Self.locationLine).name }
    #expect(Self.chipNames(in: row, of: harness) == names)
  }

  @Test func theAdditionalDirectoriesRowOfASessionShowsAChipForEachFolder() async throws {
    let session = try await ScriptedSession.open(additionalDirectories: Self.additionalFolders.map(AbsolutePath.init))
    defer { session.close() }
    let model = session.model
    let harness = Self.mount(model)
    defer { harness.close() }

    let row = Self.row(of: model, group: "session", field: "additional-directories")
    let folders = Self.additionalFolders.map { InspectionPath.folder(AbsolutePath(rawValue: $0)).path(percentEncoded: false) }
    #expect(Self.chipPaths(in: row, of: harness) == folders)
  }

  @Test func theAdditionalDirectoriesRowOfASessionWithNoneShowsTheDash() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let harness = Self.mount(model)
    defer { harness.close() }

    #expect(
      harness.rowValue(Self.row(of: model, group: "session", field: "additional-directories"))
        == EditorInspectorStrings.noValue)
  }

  // MARK: - Opening a path

  /// Mounts an `InspectorView` of the client model `model`, whose path chips
  /// open their URL with `service`, and makes one render pass.
  ///
  /// - Parameters:
  ///   - model: The model to inspect.
  ///   - service: The service that records each open.
  /// - Returns: The harness. The caller closes it.
  static func mount<Model: InspectableClientModel>(
    _ model: Model, opening service: RecordingAttachmentFileService
  ) -> HostedViewHarness<InspectorView> {
    mount(InspectedClientModel(model, fileService: service))
  }

  /// The run of the Open verb on the file or the folder at `url`, as the
  /// recording service records it.
  ///
  /// - Parameter url: The URL that a chip opens.
  /// - Returns: The recorded call.
  static func openCall(of url: URL) -> RecordingAttachmentFileService.Call {
    RecordingAttachmentFileService.Call(verb: .openAttachment, attachment: Attachment(url: url))
  }

  @Test func pressingTheWorkingDirectoryOfATerminalOpensItsFolder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      #"""
      {"sessionUpdate": "terminal_update", "terminalId": "\#(Self.terminalID)", "command": "ls",
       "cwd": "\#(Self.terminalFolder)"}
      """#)
    let entry = try await Self.entry(TerminalEntry.self, in: session)
    let service = RecordingAttachmentFileService()
    let harness = Self.mount(entry, opening: service)
    defer { harness.close() }

    try harness.inspectorDriver.open(Self.row(of: entry, group: "terminal", field: "working-directory"))

    #expect(service.calls == [Self.openCall(of: InspectionPath.folder(entry.cwd))])
  }

  @Test func pressingTheWorkingDirectoryOfASessionOpensItsFolder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let service = RecordingAttachmentFileService()
    let harness = Self.mount(model, opening: service)
    defer { harness.close() }

    try harness.inspectorDriver.open(Self.row(of: model, group: "session", field: "working-directory"))

    #expect(service.calls == [Self.openCall(of: InspectionPath.folder(model.cwd))])
  }

  @Test func openingALocationOfAToolCallOpensItsFile() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(Self.locationsUpdate)
    let entry = try await Self.entry(ToolCallEntry.self, in: session)
    let service = RecordingAttachmentFileService()
    let harness = Self.mount(entry, opening: service)
    defer { harness.close() }
    let index = Self.locationFiles.count - 1

    try harness.inspectorDriver.openPath(at: index, in: Self.row(of: entry, group: "tool-call", field: "locations"))

    let file = InspectionPath.file(AbsolutePath(rawValue: Self.locationFiles[index]))
    #expect(service.calls == [Self.openCall(of: file)])
  }

  @Test func openingAnAdditionalDirectoryOfASessionOpensItsFolder() async throws {
    let session = try await ScriptedSession.open(additionalDirectories: Self.additionalFolders.map(AbsolutePath.init))
    defer { session.close() }
    let model = session.model
    let service = RecordingAttachmentFileService()
    let harness = Self.mount(model, opening: service)
    defer { harness.close() }
    let index = Self.additionalFolders.count - 1

    try harness.inspectorDriver.openPath(
      at: index, in: Self.row(of: model, group: "session", field: "additional-directories"))

    let folder = InspectionPath.folder(AbsolutePath(rawValue: Self.additionalFolders[index]))
    #expect(service.calls == [Self.openCall(of: folder)])
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

    #expect(harness.rowValue(Self.row(of: entry, group: "plan", field: "steps")) == "\(EditorStatus(EditorSymbol.Status.completed).label): Read")
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

  /// A tool call of a timed test: the time from its start to its
  /// completion, and whether its inspection then shows a duration row.
  struct TimedCall: Sendable, CustomTestStringConvertible {
    /// The time from the start of the call to its completion, in seconds.
    let seconds: TimeInterval

    /// Whether the Time group shows a duration row once the call completed.
    let showsDuration: Bool

    /// The name of the case in the test report.
    var testDescription: String { "\(seconds) s" }
  }

  /// The timed calls of the duration test: one that takes a step of the
  /// clock and shows its duration, and one that ends before
  /// `EntryTimingView.shortestShownDuration` and shows no row.
  nonisolated static let timedCalls = [
    TimedCall(seconds: TimedSessionClock.stepSeconds, showsDuration: true),
    TimedCall(seconds: tooShortSeconds, showsDuration: false),
  ]

  /// The locale of the environment of the timed tests: the Time rows show
  /// their text in it.
  static let timedLocale = Locale(identifier: "en_US")

  /// Mounts an `InspectorView` of the timed tool call `entry` in
  /// ``timedLocale`` and `timeZone`, and makes one render pass.
  ///
  /// - Parameters:
  ///   - entry: The inspected tool call.
  ///   - timeZone: The time zone of the environment of the view.
  /// - Returns: The harness. The caller closes it.
  static func mountTimed(_ entry: ToolCallEntry, timeZone: TimeZone = .current) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      InspectorView(InspectedClientModel(entry))
        .environment(\.locale, timedLocale)
        .environment(\.timeZone, timeZone)
    }
    harness.render()
    return harness
  }

  /// Starts the timed tool call in `session`, at the time of the clock of
  /// the session.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The entry of the running call.
  /// - Throws: The error of the transport, or an issue when no entry arrives.
  static func startTimedCall(in session: ScriptedSession) async throws -> ToolCallEntry {
    try await session.sendToolCallUpdate(title: timedCallTitle, status: .inProgress)
    return try await entry(ToolCallEntry.self, in: session)
  }

  /// Moves `clock` on by `seconds`, completes the timed tool call `entry` in
  /// `session`, and renders until the entry has ended.
  ///
  /// - Parameters:
  ///   - entry: The running tool call.
  ///   - seconds: The time from its start to its completion.
  ///   - clock: The clock of the session.
  ///   - session: The scripted session.
  ///   - harness: The harness that shows the inspection of `entry`.
  /// - Throws: The error of the transport.
  static func completeTimedCall<Content: View>(
    _ entry: ToolCallEntry, after seconds: TimeInterval, clock: FixedClock, in session: ScriptedSession,
    shownBy harness: HostedViewHarness<Content>
  ) async throws {
    clock.advance(by: seconds)
    try await session.sendToolCallUpdate(title: timedCallTitle, status: .completed)
    await harness.render { entry.timing.endedAt != nil }
  }

  @Test(arguments: timedCalls)
  func theDurationRowOfAToolCallShowsTheTimeToItsCompletion(call: TimedCall) async throws {
    let clock = FixedClock(start: TimedSessionClock.start)
    let session = try await ScriptedSession.open(now: clock.now)
    defer { session.close() }
    let entry = try await Self.startTimedCall(in: session)
    let harness = Self.mountTimed(entry)
    defer { harness.close() }
    let row = Self.timeRow(of: entry, field: "duration")
    #expect(harness.rowValue(row) == nil)

    try await Self.completeTimedCall(entry, after: call.seconds, clock: clock, in: session, shownBy: harness)

    let style = EntryTimingView.lineDurationStyle(locale: Self.timedLocale)
    let expected = call.showsDuration ? style.format(.seconds(call.seconds)) : nil
    #expect(harness.rowValue(row) == expected)
  }

  @Test func theStartedRowOfAToolCallShowsItsStartInTheTimeOfDayOfTheEnvironment() async throws {
    let zone = try #require(TimedSessionClock.zoneOtherThanTheMachines())
    let clock = FixedClock(start: TimedSessionClock.start)
    let session = try await ScriptedSession.open(now: clock.now)
    defer { session.close() }
    let entry = try await Self.startTimedCall(in: session)
    let harness = Self.mountTimed(entry, timeZone: zone)
    defer { harness.close() }

    let style = EntryTimingView.startStyle(locale: Self.timedLocale, timeZone: zone)
    #expect(harness.rowValue(Self.timeRow(of: entry, field: "started")) == style.format(TimedSessionClock.start))
  }

  @Test func theEndedRowOfARunningToolCallShowsNoValue() async throws {
    let clock = FixedClock(start: TimedSessionClock.start)
    let session = try await ScriptedSession.open(now: clock.now)
    defer { session.close() }
    let entry = try await Self.startTimedCall(in: session)
    let harness = Self.mountTimed(entry)
    defer { harness.close() }

    #expect(harness.rowValue(Self.timeRow(of: entry, field: "ended")) == EditorInspectorStrings.noValue)
  }

  @Test func theEndedRowOfACompletedToolCallShowsItsEndInTheTimeOfDayOfTheEnvironment() async throws {
    let zone = try #require(TimedSessionClock.zoneOtherThanTheMachines())
    let clock = FixedClock(start: TimedSessionClock.start)
    let session = try await ScriptedSession.open(now: clock.now)
    defer { session.close() }
    let entry = try await Self.startTimedCall(in: session)
    let harness = Self.mountTimed(entry, timeZone: zone)
    defer { harness.close() }

    let seconds = TimedSessionClock.stepSeconds
    try await Self.completeTimedCall(entry, after: seconds, clock: clock, in: session, shownBy: harness)

    let end = TimedSessionClock.start.addingTimeInterval(seconds)
    let style = EntryTimingView.startStyle(locale: Self.timedLocale, timeZone: zone)
    #expect(harness.rowValue(Self.timeRow(of: entry, field: "ended")) == style.format(end))
  }

  /// The scheme id of a row of the Time group of `entry`.
  ///
  /// - Parameters:
  ///   - entry: The inspected tool call.
  ///   - field: The field part: `started`, `ended` or `duration`.
  /// - Returns: The id that the row carries.
  static func timeRow(of entry: ToolCallEntry, field: String) -> String {
    row(of: entry, group: "time", field: field)
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

    #expect(harness.rowValue(Self.row(of: entry, group: "message", field: "send-state")) == EditorStatus(entry.sendState).label)
  }

  @Test func aConnectionShowsItsState() {
    let connection = ConnectionModel.preview()
    let harness = Self.mount(connection)
    defer { harness.close() }

    #expect(
      harness.rowValue(Self.row(of: connection, group: "connection", field: "state"))
        == EditorStatus(connection.state).label)
  }

  @Test func anMCPServerShowsItsTransport() throws {
    let server = try #require(PreviewFixtures.mcpSession.mcpServers.first)
    let transport = try #require(server.transport)
    let harness = Self.mount(server)
    defer { harness.close() }

    #expect(harness.rowValue(Self.row(of: server, group: "server", field: "transport")) == ConnectionRow.label(for: transport))
  }
}
