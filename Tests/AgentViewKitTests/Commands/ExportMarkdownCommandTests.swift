import ACPMarkdown
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import Foundation
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Tests for Export as Markdown…, the kit verb that saves the thread as a
/// Markdown file through a save panel (D202).
///
/// The tests run the command in the headless harness and read the export
/// that the command gives to the presenter of its target. No test shows the
/// save panel. A test that waits for the agent waits with
/// `ObservationWait.until` on a value of the session model that the frame is
/// certain to change, with no clock.
@MainActor struct ExportMarkdownCommandTests {
  /// The title of the verb in the string catalog.
  static let title = "Export as Markdown…"

  /// The reason of the verb when the transcript has no wire entry.
  static let emptyReason = "The agent has no messages of this thread yet."

  /// The name of the agent of the scripted connection.
  static let agentName = "scripted-agent"

  /// The value that a catalog lookup gives when the catalog has no entry.
  static let missingValue = "<no catalog entry>"

  /// Sends an agent message, a thought and a tool call from the agent, and
  /// waits until the model holds each entry.
  ///
  /// - Parameter session: The scripted session.
  /// - Throws: The error of the transport.
  static func sendAgentTurn(to session: ScriptedSession) async throws {
    try await session.sendUpdate(
      WireBlockJSON.makeChunk(
        "agent_thought_chunk", messageID: "export-t", block: WireBlockJSON.makeText("Think.")))
    try await session.sendUpdate(
      WireBlockJSON.makeToolCallUpdate(
        id: "export-c", fields: #""title": "Read", "kind": "read", "status": "completed""#))
    try await session.sendUpdate(
      WireBlockJSON.makeChunk(
        "agent_message_chunk", messageID: "export-m", block: WireBlockJSON.makeText("Hello.")))
    let model = session.model
    await ObservationWait.until { model.transcript.count == 3 }
  }

  /// The export that the command gave to the presenter of `fixture`, after
  /// one run of the command.
  ///
  /// - Parameter fixture: The fixture.
  /// - Returns: The export.
  /// - Throws: An error when the command did not run or gave no export.
  static func runExport(in fixture: AgentCommandsTests.Fixture) throws -> SessionMarkdownExport {
    try #require(fixture.system.perform(AgentCommandVerb.exportMarkdown.id))
    return try #require(fixture.target.markdownExports.pending)
  }

  /// The number of `String` fields of `value`, also in its nested values.
  ///
  /// - Parameter value: A value of labels.
  /// - Returns: The count.
  static func stringFieldCount(of value: Any) -> Int {
    Mirror(reflecting: value).children.reduce(0) { count, child in
      count + (child.value is String ? 1 : stringFieldCount(of: child.value))
    }
  }

  // MARK: - Place

  @Test func theRegistryHasTheVerbWithItsTitle() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    let definition = try #require(
      fixture.system.registry.definition(for: CommandID("agent.exportMarkdown"), at: fixture.path))

    #expect(AgentAttachmentCommandsTests.staticText(of: definition.title) == Self.title)
  }

  @Test func theVerbIsInTheThreadGroupOfTheSessionMenuAfterCopyThread() throws {
    let menu = try #require(AgentCommandVerb.exportMarkdown.menu)
    let copyThread = try #require(AgentCommandVerb.copyThread.menu)

    #expect(
      menu == MenuPlacement(path: .session, group: copyThread.group, order: copyThread.order + 1))
  }

  @Test func theVerbIsInTheExportGroup() {
    #expect(AgentCommandVerb.exportMarkdown.group == .export)
  }

  @Test func theVerbHasNoKey() {
    #expect(AgentKeymap.defaultChords[.exportMarkdown] == nil)
  }

  // MARK: - Availability

  @Test func anEmptyThreadDisablesTheVerbWithTheReason() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    let availability = AgentCommand(verb: .exportMarkdown, target: fixture.target, payload: nil)
      .availability(in: fixture.system.context())

    #expect(availability == .unavailable(reason: Self.emptyReason))
  }

  @Test func oneAgentMessageEnablesTheVerb() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)
    try await session.sendUpdate(
      WireBlockJSON.makeChunk(
        "agent_message_chunk", messageID: "export-m", block: WireBlockJSON.makeText("Hi.")))
    let model = session.model
    await ObservationWait.until { model.transcript.count == 1 }

    #expect(try AgentCommandsTests.isAvailable(.exportMarkdown, in: fixture))
  }

  // MARK: - Action

  @Test func theActionGivesTheMarkdownOfTheModelWithTheCatalogLabels() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await Self.sendAgentTurn(to: session)
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    let export = try Self.runExport(in: fixture)

    let options = SessionMarkdown.Options(
      includeThoughts: false, labels: MarkdownExportLabels.catalog)
    #expect(export.text == session.model.markdown(options: options))
  }

  @Test func theActionGivesTheDefaultFileNameOfTheModel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await Self.sendAgentTurn(to: session)
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    let export = try Self.runExport(in: fixture)

    #expect(export.fileName == session.model.exportFileName)
  }

  @Test func theActionGivesTheDefaultFolderOfTheModel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await Self.sendAgentTurn(to: session)
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    let export = try Self.runExport(in: fixture)

    #expect(
      export.folder == URL(fileURLWithPath: ScriptedSession.workingDirectory, isDirectory: true))
  }

  @Test func theActionNamesTheAgentOfTheConnection() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await Self.sendAgentTurn(to: session)
    let fixture = AgentCommandsTests.makeFixture(session: session.model) {
      $0.connection = session.connection
    }

    let export = try Self.runExport(in: fixture)

    let options = SessionMarkdown.Options(
      includeThoughts: false, agentName: Self.agentName, labels: MarkdownExportLabels.catalog)
    #expect(export.text == session.model.markdown(options: options))
  }

  // MARK: - Export button

  @Test func theExportButtonOfAMessageIsTheButtonOfTheVerb() {
    #expect(MessageActions.Action.export.verb == .exportMarkdown)
  }

  @Test func theExportButtonWithNoScopeShowsTheTitleOfTheVerb() {
    #expect(MessageActions.Action.export.title == Self.title)
  }

  @Test func theExportButtonWithNoScopeShowsTheSymbolOfTheVerb() {
    #expect(MessageActions.Action.export.systemImage == AgentCommandVerb.exportMarkdown.icon)
  }

  @Test func theExportButtonWithNoScopeIsDisabledWithTheReasonInAnEmptyThread() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    #expect(MessageActions.disabledReason(of: .export, in: session.model) == Self.emptyReason)
  }

  @Test func theExportButtonWithNoScopeIsEnabledAfterOneAgentMessage() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await Self.sendAgentTurn(to: session)

    #expect(MessageActions.disabledReason(of: .export, in: session.model) == nil)
  }

  // MARK: - Presenter

  @Test func thePresenterShowsNoExportForAnEmptyThread() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let presenter = MarkdownExportPresenter()

    presenter.presentExport(of: session.model, agentName: nil)

    #expect(presenter.pending == nil)
  }

  @Test func thePresenterShowsTheExportOfTheSession() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await Self.sendAgentTurn(to: session)
    let presenter = MarkdownExportPresenter()

    presenter.presentExport(of: session.model, agentName: Self.agentName)

    let expected = SessionMarkdownExport(session: session.model, agentName: Self.agentName)
    #expect(presenter.pending == expected)
  }

  // MARK: - Labels

  @Test func eachLabelHasAnEntryInTheCatalog() {
    for entry in MarkdownExportLabels.entries {
      let text = Bundle.module.localizedString(
        forKey: entry.key, value: Self.missingValue, table: MarkdownExportLabels.table)
      #expect(text != Self.missingValue, "\(entry.key)")
    }
  }

  @Test func theCatalogGivesEachFieldOfTheLabelsOneTime() {
    let fields = Set(MarkdownExportLabels.entries.map(\.field))

    #expect(fields.count == MarkdownExportLabels.entries.count)
    #expect(fields.count == Self.stringFieldCount(of: SessionMarkdown.Labels()))
  }

  @Test func theTurnsOfTheAgentHaveTheSenderNameOfTheKit() {
    #expect(MarkdownExportLabels.catalog.agent == "Assistant")
  }
}
