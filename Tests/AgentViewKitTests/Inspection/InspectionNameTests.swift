import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit
@testable import EditorInspector

/// Checks the name of each block of an inspector, with no view: the name
/// that EditorKit shows in the name row of the block (`InspectorBlock`), so
/// two blocks of one type have two different names.
@Suite @MainActor struct InspectionNameTests {
  /// The locale of the texts with a time.
  nonisolated static let locale = Locale(identifier: "en_US")

  /// The time zone of the texts with a time.
  nonisolated static let timeZone = TimeZone(identifier: "UTC")!

  /// A start time at 6:15 AM in ``timeZone``. The en_US time has a narrow
  /// no-break space before "AM".
  nonisolated static let startedAt = Date(timeIntervalSince1970: 22_500)

  /// The name of the block of `object`, as the inspector shows it.
  ///
  /// - Parameters:
  ///   - object: The object of the block.
  ///   - inspection: The inspection of its type.
  /// - Returns: The name of the block.
  private func name<Object>(of object: Object, in inspection: Inspection<Object>) -> String {
    InspectorBlock.header(of: object, in: inspection)
  }

  /// The names of the blocks of two transcript entries of one kind.
  ///
  /// - Parameters:
  ///   - first: The item of the first entry.
  ///   - second: The item of the second entry.
  ///   - type: The class of the entries.
  /// - Returns: The two names, in order.
  private func names<Entry: InspectableClientModel>(
    _ first: PreviewTranscriptItem, _ second: PreviewTranscriptItem, as type: Entry.Type
  ) throws -> [String] {
    try [first, second].map { item in
      let entry = try #require(PreviewFixtures.entry(item, as: type))
      return name(of: InspectedClientModel(entry), in: Entry.inspection)
    }
  }

  /// The item of an update that the agent sends as JSON.
  ///
  /// - Parameter json: The JSON text of the update.
  /// - Returns: The item.
  private func update(_ json: String) throws -> PreviewTranscriptItem {
    .update(try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8)))
  }

  /// The item of a message between two sessions.
  ///
  /// - Parameters:
  ///   - id: The id of the message.
  ///   - sender: The id of the session that sent it.
  ///   - text: The text of the message.
  /// - Returns: The item.
  private func sessionMessage(id: String, from sender: String, text: String) throws -> PreviewTranscriptItem {
    try update(
      #"""
      {"sessionUpdate": "session_message", "messageId": "\#(id)", "senderSessionId": "\#(sender)",
       "content": [{"type": "text", "text": "\#(text)"}]}
      """#)
  }

  // MARK: - The shared helper

  @Test func aShortTextIsItsOwnFirstWords() {
    #expect(InspectionName.firstWords(of: "Fix the parser.") == "Fix the parser.")
  }

  @Test func aLongTextStopsAfterItsFirstWordsWithAnEllipsis() {
    #expect(InspectionName.firstWords(of: "The parser reads one token too far.") == "The parser reads one token too…")
  }

  @Test func theFirstWordsJoinTheLinesOfATextWithASpace() {
    #expect(InspectionName.firstWords(of: "First line\n\nSecond line") == "First line Second line")
  }

  @Test func aTextWithNoWordHasNoFirstWords() {
    #expect(InspectionName.firstWords(of: " \n ") == nil)
  }

  @Test func aMessageWithAnAuthorAndATimeIsNamedByThem() {
    let name = InspectionName.message(
      author: "child-1", startedAt: Self.startedAt, text: "The tests pass.", locale: Self.locale,
      timeZone: Self.timeZone)

    #expect(name == "child-1 · 6:15\u{202F}AM")
  }

  @Test func aMessageWithNoAuthorIsNamedByItsFirstWords() {
    let name = InspectionName.message(
      author: nil, startedAt: Self.startedAt, text: "The tests pass.", locale: Self.locale, timeZone: Self.timeZone)

    #expect(name == "The tests pass.")
  }

  @Test func aMessageWithNoTimeIsNamedByItsFirstWords() {
    let name = InspectionName.message(
      author: "child-1", startedAt: nil, text: "The tests pass.", locale: Self.locale, timeZone: Self.timeZone)

    #expect(name == "The tests pass.")
  }

  // MARK: - Two items of one type

  @Test func twoUserMessagesHaveTwoNames() throws {
    let names = try names(.user("Fix the parser."), .user("Then run the tests."), as: UserMessageEntry.self)

    #expect(names == ["Fix the parser.", "Then run the tests."])
  }

  @Test func twoAgentMessagesHaveTwoNames() throws {
    let names = try names(
      .agent("The parser reads one token too far."), .agent("Each test passes."), as: AgentMessageEntry.self)

    #expect(names == ["The parser reads one token too…", "Each test passes."])
  }

  @Test func twoThoughtsHaveTwoNames() throws {
    let names = try names(
      .thought("The loop ends one step late."), .thought("Run the suite."), as: ThoughtEntry.self)

    #expect(names == ["The loop ends one step late.", "Run the suite."])
  }

  @Test func twoSessionMessagesHaveTwoNames() throws {
    let names = try names(
      sessionMessage(id: "mail-1", from: "child-1", text: "The lexer change is ready."),
      sessionMessage(id: "mail-2", from: "child-2", text: "The tests pass."), as: SessionMessageEntry.self)

    #expect(Set(names).count == names.count)
  }

  @Test func twoToolCallsHaveTwoNames() throws {
    let names = try names(
      .toolCall(title: "Read Lexer.swift", kind: .read, status: .completed),
      .toolCall(title: "Edit Lexer.swift", kind: .edit, status: .inProgress), as: ToolCallEntry.self)

    #expect(names == ["Read Lexer.swift", "Edit Lexer.swift"])
  }

  @Test func twoTerminalsHaveTwoNames() throws {
    let names = try names(
      .terminal(command: "swift build", output: "", exitCode: 0),
      .terminal(command: "swift test", output: "", exitCode: nil), as: TerminalEntry.self)

    #expect(names == ["swift build", "swift test"])
  }

  @Test func twoPlansAreNamedByTheirCurrentSteps() throws {
    let read = PlanEntry(content: "Read the failing test", priority: .high, status: .completed)
    let change = PlanEntry(content: "Change the parser", priority: .medium, status: .pending)
    let names = try names(
      .plan([read, change]), .plan([PlanEntry(content: "Run the tests", priority: .high, status: .inProgress)]),
      as: PlanTranscriptEntry.self)

    #expect(names == ["Change the parser", "Run the tests"])
  }

  @Test func aPlanWithEachStepDoneIsNamedByItsLastStep() throws {
    let steps = [
      PlanEntry(content: "Read the failing test", priority: .high, status: .completed),
      PlanEntry(content: "Change the parser", priority: .medium, status: .completed),
    ]
    let entry = try #require(PreviewFixtures.entry(.plan(steps), as: PlanTranscriptEntry.self))

    #expect(name(of: InspectedClientModel(entry), in: PlanTranscriptEntry.inspection) == "Change the parser")
  }

  @Test func twoCompactionsHaveTwoNames() throws {
    let names = try names(
      update(#"{"sessionUpdate": "compaction_update", "compactionId": "compaction-1", "status": "completed"}"#),
      update(#"{"sessionUpdate": "compaction_update", "compactionId": "compaction-2", "status": "in_progress"}"#),
      as: CompactionEntry.self)

    #expect(Set(names).count == names.count)
  }

  @Test func aCompactionWithASummaryIsNamedByItsFirstWords() throws {
    let names = try names(
      update(
        #"""
        {"sessionUpdate": "compaction_update", "compactionId": "compaction-1", "status": "completed",
         "summary": [{"type": "text", "text": "The parser work so far."}]}
        """#),
      update(#"{"sessionUpdate": "compaction_update", "compactionId": "compaction-2", "status": "completed"}"#),
      as: CompactionEntry.self)

    #expect(names.first == "The parser work so far.")
  }

  @Test func twoErrorsHaveTwoNames() throws {
    let names = try names(
      .error(code: .internalError, message: "The agent stopped."),
      .error(code: .invalidParams, message: "The path is not absolute."), as: ErrorEntry.self)

    #expect(names == ["The agent stopped.", "The path is not absolute."])
  }

  @Test func twoUnknownUpdatesHaveTwoNames() throws {
    let names = try names(
      update(#"{"sessionUpdate": "x_board_update", "note": "first"}"#),
      update(#"{"sessionUpdate": "x_index_update", "note": "second"}"#), as: UnknownEntry.self)

    #expect(names == ["x_board_update", "x_index_update"])
  }

  @Test func twoSessionsHaveTwoNames() {
    let names = [SessionId(rawValue: "sess_1"), SessionId(rawValue: "sess_2")].map { id in
      name(of: InspectedClientModel(SessionModel.preview(sessionId: id)), in: SessionModel.inspection)
    }

    #expect(names == ["sess_1", "sess_2"])
  }

  @Test func twoConnectionsInTwoStatesHaveTwoNames() {
    let names = [ConnectionModel.preview(), ConnectionModel.preview(state: .connecting)].map { connection in
      name(of: connection, in: ConnectionModel.inspection)
    }

    #expect(Set(names).count == names.count)
  }

  @Test func aConnectionToAnAgentIsNamedByTheAgent() {
    #expect(name(of: ConnectionModel.previewSample, in: ConnectionModel.inspection) == "preview-agent")
  }

  @Test func twoMCPServersHaveTwoNames() {
    let names = PreviewFixtures.mcpSession.mcpServers.map { name(of: $0, in: MCPServerItem.inspection) }

    #expect(names == ["GitHub", "Files"])
  }

  @Test func twoAttachmentsHaveTwoNames() {
    let names = PreviewFixtures.attachments.map { attachment in
      name(of: InspectedAttachment(attachment), in: AttachmentInspector.inspection)
    }

    #expect(names == PreviewFixtures.attachments.map(\.name))
  }


  // MARK: - An empty name

  /// The name of the block of a connection whose agent sends `agentName`.
  ///
  /// - Parameter agentName: The name of the agent in its `initialize` answer.
  /// - Returns: The name of the block.
  private func connectionName(agentName: String) -> String {
    let response = InitializeResponse(
      info: Implementation(name: agentName, version: "1.0.0"), protocolVersion: ACPClient.supportedProtocolVersion)
    return name(of: ConnectionModel.preview(initializeResponse: response), in: ConnectionModel.inspection)
  }

  @Test func aConnectionWithAnEmptyAgentNameIsNamedByItsState() {
    #expect(connectionName(agentName: "") == name(of: ConnectionModel.preview(), in: ConnectionModel.inspection))
  }

  @Test func aConnectionWithABlankAgentNameIsNamedByItsState() {
    #expect(connectionName(agentName: " \n ") == name(of: ConnectionModel.preview(), in: ConnectionModel.inspection))
  }

  @Test func anEmptyTextIsNotAName() {
    #expect(InspectionName.present("") == nil)
  }

  @Test func aTextOfSpacesAndLineBreaksIsNotAName() {
    #expect(InspectionName.present(" \n\t ") == nil)
  }

  @Test func aTextWithAWordIsItsOwnName() {
    #expect(InspectionName.present(" sess_1 ") == " sess_1 ")
  }

  @Test func anMCPServerWithAnEmptyNameIsNamedByTheTitle() throws {
    let server = MCPServer.stdio(MCPServerStdio(command: AbsolutePath(rawValue: "/usr/local/bin/files-mcp"), name: ""))
    let item = try #require(SessionModel.preview(mcpServers: [server]).mcpServers.first)

    #expect(name(of: item, in: MCPServerItem.inspection) == MCPServerItem.inspection.title)
  }

  @Test func aToolCallWithAnEmptyTitleIsNamedByTheTitleOfItsType() throws {
    let entry = try #require(
      PreviewFixtures.entry(.toolCall(title: "", kind: .read, status: .completed), as: ToolCallEntry.self))

    #expect(name(of: InspectedClientModel(entry), in: ToolCallEntry.inspection) == ToolCallEntry.inspection.title)
  }

  @Test func aTerminalWithAnEmptyCommandIsNamedByTheTitleOfItsType() throws {
    let entry = try #require(
      PreviewFixtures.entry(.terminal(command: " ", output: "", exitCode: 0), as: TerminalEntry.self))

    #expect(name(of: InspectedClientModel(entry), in: TerminalEntry.inspection) == TerminalEntry.inspection.title)
  }

  @Test func aSessionMessageWithAnEmptySenderIsNamedByItsFirstWords() throws {
    let names = try names(
      sessionMessage(id: "mail-1", from: "", text: "The tests pass."),
      sessionMessage(id: "mail-2", from: " ", text: "The lexer change is ready."), as: SessionMessageEntry.self)

    #expect(names == ["The tests pass.", "The lexer change is ready."])
  }

  @Test func anAttachmentWithAnEmptyNameIsNamedByTheTitleOfItsType() {
    let file = PreviewFixtures.sourceFileAttachment
    let attachment = Attachment(id: file.id, url: file.url, type: file.type, name: " ", size: file.size)

    #expect(
      name(of: InspectedAttachment(attachment), in: AttachmentInspector.inspection)
        == AttachmentInspector.inspection.title)
  }
}
