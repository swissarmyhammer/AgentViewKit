#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import EditorSwiftUI
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The rows of the thought, terminal, plan, unknown and error entries of a
  /// `SessionModel` (plan.md §3.7, §3.8 "Error rows", "Terminal view",
  /// "Plan view").
  ///
  /// Each test waits for a model value that the update is certain to change,
  /// and then makes one render pass before it reads the view. The agent sends
  /// the frames in order, so a wait for the effect of the last update also
  /// covers the earlier updates.
  @Suite(.serialized, .hostedSerially) @MainActor struct SessionEntryRowsHostedTests {
    /// A size that shows each row of the tests.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The `terminalId` of the terminal of the tests.
    static let terminalID = "rows-terminal"

    /// The command of the terminal of the tests.
    static let command = "make"

    /// The `planId` of the plan of the tests.
    static let planID = "rows-plan"

    /// The number of rows after two plan updates with no plan id.
    static let unnamedPlanRowCount = 2

    /// The `sessionUpdate` tag of the unknown update.
    static let unknownType = "_vendor_note"

    /// The text that the raw JSON of the unknown update holds.
    static let unknownNote = "kept by the client"

    /// The JSON-RPC code of the error that the scripted agent sends.
    static let scriptedErrorCode = -32603

    /// The member name in the data of the appended error.
    static let errorDataField = "missingField"

    /// The label of the second plan entry, which no plan update changes.
    static let shipEntryLabel = "Ship, Pending, Low priority"

    /// The label of the first plan entry while it is in progress.
    static let runningReadEntryLabel = "Read, In progress, High priority"

    /// The `messageId` of the thought of the tests.
    static let thoughtID = "rows-t"

    /// The text of the thought of the tests.
    static let thoughtText = "Thinking."

    /// The name of the resource link that the content tests send.
    static let linkName = "Guide"

    /// The URI of the resource link that the content tests send.
    static let linkURI = "https://example.com/docs/guide.html"

    /// The number of content blocks of an entry of the content tests: one
    /// text block and one resource link block.
    static let textAndLinkBlockCount = 2

    /// The JSON text of the resource link block that the content tests send.
    static var linkBlock: String {
      WireBlockJSON.makeResourceLink(name: linkName, uri: linkURI)
    }

    /// The base64 form of the UTF-8 bytes of `text`.
    ///
    /// - Parameter text: The terminal text.
    /// - Returns: The base64 text.
    static func base64(_ text: String) -> String {
      Data(text.utf8).base64EncodedString()
    }

    /// A `terminal_update` value for the terminal of the tests.
    ///
    /// - Parameter fields: The other fields of the update, as JSON members.
    /// - Returns: The JSON text of the update.
    static func terminalUpdate(_ fields: String) -> String {
      #"{"sessionUpdate": "terminal_update", "terminalId": "\#(terminalID)", \#(fields)}"#
    }

    /// A `terminal_output_chunk` value for the terminal of the tests.
    ///
    /// - Parameter text: The text of the chunk.
    /// - Returns: The JSON text of the update.
    static func terminalChunk(_ text: String) -> String {
      #"{"sessionUpdate": "terminal_output_chunk", "terminalId": "\#(terminalID)", "data": "\#(base64(text))"}"#
    }

    /// A `plan_update` value with two entries for the plan of the tests.
    ///
    /// - Parameter firstStatus: The status of the first entry.
    /// - Returns: The JSON text of the update.
    static func planUpdate(firstStatus: String) -> String {
      #"""
      {"sessionUpdate": "plan_update", "plan": {"type": "items", "planId": "\#(planID)",
       "entries": [{"content": "Read", "priority": "high", "status": "\#(firstStatus)"},
                   {"content": "Ship", "priority": "low", "status": "pending"}]}}
      """#
    }

    /// An `agent_message_chunk` value.
    static let agentChunk =
      #"{"sessionUpdate": "agent_message_chunk", "messageId": "rows-m", "content": {"type": "text", "text": "Done."}}"#

    /// Mounts the thread of `session`.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - store: The store of the expanded rows.
    /// - Returns: The harness.
    static func mountThread(
      _ session: ScriptedSession, store: ExpandedBlocksStore = ExpandedBlocksStore()
    ) -> HostedViewHarness<some View> {
      HostedViewHarness(size: tallSize) {
        AgentThreadView(session: session.model)
          .environment(\.expandedBlocksStore, store)
          .transaction { $0.disablesAnimations = true }
      }
    }

    /// Expects that the open reasoning block of the thought of the tests
    /// shows the text of the thought and the look of a complete thought: the
    /// complete title and the complete label, with no progress state.
    ///
    /// - Parameters:
    ///   - key: The row key of the thought.
    ///   - harness: The harness that shows the thread.
    static func expectCompleteThought<Content: View>(key: String, in harness: HostedViewHarness<Content>) {
      #expect(SessionTranscriptViewHostedTests.showsParagraphs(of: thoughtText, in: harness))
      #expect(harness.element(identifier: ReasoningView.titleIdentifier(for: key)) != nil)
      #expect(
        harness.element(identifier: ReasoningView.identifier(for: key))?.label
          == ReasoningView.accessibilityLabel(isInProgress: false, duration: nil))
    }

    /// The labels of the accessibility elements of `harness`.
    ///
    /// - Parameter harness: The harness that shows the thread.
    /// - Returns: Each label.
    static func labels<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
      harness.accessibilityElements().compactMap(\.label)
    }

    /// The first thought entry of a session model.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The entry, or `nil` while the model has no thought entry.
    static func thought(in model: SessionModel) -> ThoughtEntry? {
      model.transcript.lazy.compactMap { entry -> ThoughtEntry? in
        if case .thought(let thought) = entry { thought } else { nil }
      }.first
    }

    /// The first plan entry of a session model.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The entry, or `nil` while the model has no plan entry.
    static func plan(in model: SessionModel) -> PlanTranscriptEntry? {
      model.transcript.lazy.compactMap { entry -> PlanTranscriptEntry? in
        if case .plan(let plan) = entry { plan } else { nil }
      }.first
    }

    /// The first compaction entry of a session model.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The entry, or `nil` while the model has no compaction entry.
    static func compaction(in model: SessionModel) -> CompactionEntry? {
      model.transcript.lazy.compactMap { entry -> CompactionEntry? in
        if case .compaction(let compaction) = entry { compaction } else { nil }
      }.first
    }

    /// The status of the first plan entry of the plan of the tests.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The status, or `nil` while the model has no plan entry.
    static func firstPlanStatus(in model: SessionModel) -> PlanEntryStatus? {
      plan(in: model)?.entries.first?.status
    }

    // MARK: - Thought

    @Test func aThoughtShowsItsTextWhileRunningAndAfterIdleWithNoProgressState() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(ScriptedSession.runningState)
      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_thought_chunk", messageID: Self.thoughtID, text: Self.thoughtText))
      await ObservationWait.until {
        SessionTranscriptViewHostedTests.entryText(of: model, at: 0) == Self.thoughtText
      }
      let entry = try #require(model.transcript.first)
      let key = entry.rowKey
      store.expand(entry: entry)
      harness.render()
      #expect(ComposerSessionModelHostedTests.isRunning(model))
      Self.expectCompleteThought(key: key, in: harness)

      try await session.sendUpdate(ScriptedSession.idleState)
      await harness.render { !ComposerSessionModelHostedTests.isRunning(model) }

      Self.expectCompleteThought(key: key, in: harness)
    }

    @Test func theExpandedPolicyOpensAThoughtEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore { entry in
        if case .thought = entry { true } else { false }
      }
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_thought_chunk", messageID: Self.thoughtID, text: Self.thoughtText))
      await harness.render { SessionTranscriptViewHostedTests.entryText(of: model, at: 0) == Self.thoughtText }

      let entry = try #require(model.transcript.first)
      #expect(store.decision(for: entry) == nil)
      Self.expectCompleteThought(key: entry.rowKey, in: harness)
    }

    @Test func aThoughtChunkEvaluatesOnlyTheRowOfItsThought() async throws {
      try await SessionTranscriptViewHostedTests.expectAChunkEvaluatesOnlyTheRowOfItsEntry(
        kind: "agent_thought_chunk")
    }

    @Test func aThoughtEntryShowsTheACPContentOfTheModel() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_thought_chunk", messageID: Self.thoughtID, text: Self.thoughtText))
      try await session.sendUpdate(
        WireBlockJSON.makeChunk("agent_thought_chunk", messageID: Self.thoughtID, block: Self.linkBlock))
      await ObservationWait.until { Self.thought(in: model)?.content.count == Self.textAndLinkBlockCount }
      let entry = try #require(model.transcript.first)
      store.expand(entry: entry)
      harness.render()

      #expect(SessionTranscriptViewHostedTests.showsParagraphs(of: Self.thoughtText, in: harness))
      #expect(harness.element(identifier: LinkView.cardIdentifier)?.label == Self.linkName)
    }

    // MARK: - Compaction

    @Test func aCompactionSummaryShowsTheACPContentOfTheModel() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let model = session.model
      let compactionID = CompactionAndNoticeHostedTests.compactionID
      let summaryText = CompactionAndNoticeHostedTests.summaryText

      try await session.sendUpdate(
        WireBlockJSON.makeCompactionSummaryChunk(
          compactionID: compactionID, block: WireBlockJSON.makeText(summaryText)))
      try await session.sendUpdate(
        WireBlockJSON.makeCompactionSummaryChunk(compactionID: compactionID, block: Self.linkBlock))
      await harness.render {
        Self.compaction(in: model)?.summary.count == Self.textAndLinkBlockCount
      }

      #expect(Self.labels(in: harness).contains { $0.contains(summaryText) })
      #expect(harness.element(identifier: LinkView.cardIdentifier)?.label == Self.linkName)
    }

    // MARK: - Terminal

    @Test func aTerminalEntryShowsTheTerminalViewInItsRow() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(Self.terminalUpdate(#""command": "\#(Self.command)""#))
      // The container element of the terminal merges into the element of its
      // row, so the test reads the command element of the header.
      await harness.render { TerminalViewHostedTests.firstTerminal(in: model) != nil }

      #expect(harness.element(identifier: TerminalView.commandIdentifier)?.label == Self.command)
      #expect(harness.element(identifier: TerminalView.progressIdentifier) != nil)
      #expect(harness.element(identifier: UnknownItemView.identifier) == nil)
    }

    @Test func aTerminalChunkAppendsTextAndAnOutputSnapshotReplacesIt() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let editor = EditorModel("")
      let harness = HostedViewHarness(size: Self.tallSize) {
        FirstTerminalView(session: session.model, editor: editor)
      }
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(Self.terminalUpdate(#""output": {"data": "\#(Self.base64("one\n"))"}"#))
      await harness.render { TerminalViewHostedTests.firstTerminal(in: model)?.text == "one\n" }
      #expect(editor.text == "one\n")

      try await session.sendUpdate(Self.terminalChunk("two\n"))
      await harness.render { TerminalViewHostedTests.firstTerminal(in: model)?.text == "one\ntwo\n" }
      #expect(editor.text == "one\ntwo\n")

      try await session.sendUpdate(Self.terminalUpdate(#""output": {"data": "\#(Self.base64("fresh"))"}"#))
      await harness.render { TerminalViewHostedTests.firstTerminal(in: model)?.text == "fresh" }
      #expect(editor.text == "fresh")
    }

    // MARK: - Plan

    @Test func twoPlanUpdatesWithTheSamePlanIdShowOneRowAtTheFirstPosition() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(Self.planUpdate(firstStatus: "pending"))
      try await session.sendUpdate(Self.agentChunk)
      try await session.sendUpdate(Self.planUpdate(firstStatus: "completed"))
      let planKey = TranscriptEntry.ID.wire(.plan(PlanId(rawValue: Self.planID))).rowKey
      await harness.render { Self.firstPlanStatus(in: model) == .completed }

      let keys = model.transcript.map(\.rowKey)
      #expect(keys.count == 2)
      #expect(keys.first == planKey)
      #expect(SessionTranscriptViewHostedTests.rowKeys(in: harness) == keys)
      #expect(harness.element(identifier: TaskListView.planIdentifier(row: planKey))?.label == "1 of 2 done")
      #expect(
        harness.element(identifier: TaskListView.entryIdentifier(row: planKey, index: 0))?.label
          == "Read, Completed, High priority")
    }

    @Test func aPlanUpdateChangesTheStatusOfOneRow() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let model = session.model
      let planKey = TranscriptEntry.ID.wire(.plan(PlanId(rawValue: Self.planID))).rowKey
      let firstRow = TaskListView.entryIdentifier(row: planKey, index: 0)
      let secondRow = TaskListView.entryIdentifier(row: planKey, index: 1)
      let running = Self.runningReadEntryLabel
      let completed = "Read, Completed, High priority"

      try await session.sendUpdate(Self.planUpdate(firstStatus: "in_progress"))
      await harness.render { Self.firstPlanStatus(in: model) == .inProgress }
      #expect(harness.element(identifier: firstRow)?.label == running)
      #expect(harness.element(identifier: secondRow)?.label == Self.shipEntryLabel)

      try await session.sendUpdate(Self.planUpdate(firstStatus: "completed"))
      await harness.render { Self.firstPlanStatus(in: model) == .completed }

      #expect(harness.element(identifier: firstRow)?.label == completed)
      #expect(harness.element(identifier: secondRow)?.label == Self.shipEntryLabel)
    }

    @Test func aPlanEntryInProgressShowsItsStatusSymbolWithNoSpinner() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let model = session.model
      let planKey = TranscriptEntry.ID.wire(.plan(PlanId(rawValue: Self.planID))).rowKey
      let firstRow = TaskListView.entryIdentifier(row: planKey, index: 0)
      let running = Self.runningReadEntryLabel

      try await session.sendUpdate(Self.planUpdate(firstStatus: "in_progress"))
      await harness.render { Self.firstPlanStatus(in: model) == .inProgress }

      #expect(harness.element(identifier: firstRow)?.label == running)
      #expect(harness.progressIndicatorCount() == 0)
    }

    @Test func eachPlanWithNoPlanIdIsANewRowThatShowsTheContentType() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let model = session.model
      let update = ##"{"sessionUpdate": "plan_update", "plan": {"type": "markdown", "text": "# Plan"}}"##

      try await session.sendUpdate(update)
      try await session.sendUpdate(update)
      await harness.render { model.transcript.count == Self.unnamedPlanRowCount }

      let keys = model.transcript.map(\.rowKey)
      #expect(keys.count == 2)
      for key in keys {
        let content = harness.element(identifier: TaskListView.unknownContentIdentifier(row: key))
        #expect(content?.label?.contains("markdown") == true, "\(key)")
      }
    }

    // MARK: - Unknown

    @Test func anUnknownSessionUpdateShowsARowWithItsTypeString() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(#"{"sessionUpdate": "\#(Self.unknownType)", "note": "\#(Self.unknownNote)"}"#)
      await harness.render { !model.transcript.isEmpty }
      #expect(harness.element(identifier: UnknownItemView.identifier) != nil)
      #expect(Self.labels(in: harness).contains { $0.contains(Self.unknownType) })

      let entry = try #require(model.transcript.first)
      store.expand(entry: entry)
      harness.render()
      #expect(Self.labels(in: harness).contains { $0.contains(Self.unknownNote) })
    }

    @Test func anUnknownEntryShowsItsRawJSONAsIndentedJSONText() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model
      let member = #""note" : "\#(Self.unknownNote)""#

      try await session.sendUpdate(#"{"sessionUpdate": "\#(Self.unknownType)", "note": "\#(Self.unknownNote)"}"#)
      await ObservationWait.until { !model.transcript.isEmpty }
      let entry = try #require(model.transcript.first)
      store.expand(entry: entry)
      harness.render()

      #expect(Self.labels(in: harness).contains { $0.contains(member) })
    }

    // MARK: - Error

    @Test func aFailedPromptShowsAnErrorRowWithTheJSONRPCCode() async throws {
      let session = try await ScriptedSession.open { $0.failingMethods = ["session/prompt"] }
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let model = session.model
      let identifier = ErrorView.identifier

      let prompt = Task { try await model.prompt([.text(TextContent(text: "Hello."))]) }
      if case .success = await prompt.result {
        Issue.record("The prompt did not fail.")
      }
      await harness.render { TranscriptChecks.hasErrorEntry(model) }

      #expect(
        harness.element(identifier: identifier)?.label
          == "The agent sent an error, Error \(Self.scriptedErrorCode): failed")
    }

    @Test func anAppendedErrorShowsItsData() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }

      session.model.appendError(
        code: .invalidParams, message: "Invalid params",
        data: .object([Self.errorDataField: .string("cwd")]))
      harness.render()

      #expect(Self.showsErrorData(in: harness))
    }

    /// The client gives the text of a connection that closes before the
    /// answer. The test reads that text from `RequestError(reporting:)` of the
    /// client, and does not copy it. The file has no `@testable` import, so
    /// the test presses a config choice to send the kit request.
    @Test func aConnectionThatClosesBeforeTheAnswerShowsTheClientTextInTheErrorRow() async throws {
      let config = ConfigOptionsSessionModelHostedTests.self
      let session = try await config.openSession { $0.heldMethods = [config.setMethod] }
      defer { session.close() }
      let harness = HostedViewHarness(size: Self.tallSize) {
        VStack {
          ConfigOptionsView(session: session.model, style: .form)
          AgentThreadView(session: session.model)
        }
      }
      defer { harness.close() }
      let model = session.model
      let clientText = RequestError(reporting: ConnectionError.closed).message

      try harness.press(identifier: ConfigOptionsView.choiceIdentifier(for: config.modelID, value: "deep-1"))
      await ObservationWait.until { !config.setParams(in: session).isEmpty }
      session.close()
      await harness.render { TranscriptChecks.hasErrorEntry(model) }

      let label = try #require(harness.element(identifier: ErrorView.identifier)?.label)
      #expect(label.contains(clientText), "The error row shows \"\(label)\".")
    }

    /// Tells whether the data element of the error card shows the data of the
    /// appended error.
    ///
    /// - Parameter harness: The harness that shows the thread.
    /// - Returns: `true` when the label of the data element contains
    ///   `errorDataField`.
    private static func showsErrorData<Content: View>(in harness: HostedViewHarness<Content>) -> Bool {
      harness.element(identifier: ErrorView.dataIdentifier)?.label?.contains(errorDataField) == true
    }
  }

  /// Shows the ``TerminalView`` of the first terminal entry of a session, with
  /// an editor model that the test reads.
  private struct FirstTerminalView: View {
    /// The session model.
    let session: SessionModel

    /// The editor model that the terminal view fills.
    let editor: EditorModel

    var body: some View {
      if let terminal = TerminalViewHostedTests.firstTerminal(in: session) {
        TerminalView(entry: terminal, model: editor)
      }
    }
  }
#endif
