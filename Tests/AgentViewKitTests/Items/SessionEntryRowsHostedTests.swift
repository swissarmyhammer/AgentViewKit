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
  /// `SessionModel` (update.md §4.4, §4.7 "Error rows", "Terminal view",
  /// "Plan view").
  @Suite(.serialized, .hostedSerially) @MainActor struct SessionEntryRowsHostedTests {
    /// The longest time that a test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows each row of the tests.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The `terminalId` of the terminal of the tests.
    static let terminalID = "rows-terminal"

    /// The command of the terminal of the tests.
    static let command = "make"

    /// The `planId` of the plan of the tests.
    static let planID = "rows-plan"

    /// The `sessionUpdate` tag of the unknown update.
    static let unknownType = "_vendor_note"

    /// The text that the raw JSON of the unknown update holds.
    static let unknownNote = "kept by the client"

    /// The JSON-RPC code of the error that the scripted agent sends.
    static let scriptedErrorCode = -32603

    /// The member name in the data of the appended error.
    static let errorDataField = "missingField"

    /// The `messageId` of the thought of the tests.
    static let thoughtID = "rows-t"

    /// The text of the thought of the tests.
    static let thoughtText = "Thinking."

    /// The name of the resource link that the content tests send.
    static let linkName = "Guide"

    /// The URI of the resource link that the content tests send.
    static let linkURI = "https://example.com/docs/guide.html"

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
        AgentThreadView(session: session.model, actions: NoopThreadActions())
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

    // MARK: - Thought

    @Test func aThoughtShowsItsTextWhileRunningAndAfterIdleWithNoProgressState() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(SessionTranscriptViewHostedTests.runningState)
      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_thought_chunk", messageID: Self.thoughtID, text: Self.thoughtText))
      await harness.pump(until: Self.waitTimeout) {
        SessionTranscriptViewHostedTests.rowKeys(in: harness).count == 1
      }
      let key = try #require(model.transcript.first?.rowKey)
      store.expand(key)
      await harness.pump(until: Self.waitTimeout) {
        SessionTranscriptViewHostedTests.showsParagraphs(of: Self.thoughtText, in: harness)
      }
      #expect(ComposerSessionModelHostedTests.isRunning(model))
      Self.expectCompleteThought(key: key, in: harness)

      try await session.sendUpdate(SessionTranscriptViewHostedTests.idleState)
      await harness.pump(until: Self.waitTimeout) { !ComposerSessionModelHostedTests.isRunning(model) }
      harness.pump()

      Self.expectCompleteThought(key: key, in: harness)
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

      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_thought_chunk", messageID: Self.thoughtID, text: Self.thoughtText))
      try await session.sendUpdate(
        WireBlockJSON.makeChunk("agent_thought_chunk", messageID: Self.thoughtID, block: Self.linkBlock))
      await harness.pump(until: Self.waitTimeout) {
        SessionTranscriptViewHostedTests.rowKeys(in: harness).count == 1
      }
      let key = try #require(session.model.transcript.first?.rowKey)
      store.expand(key)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: LinkView.cardIdentifier) != nil
      }

      #expect(SessionTranscriptViewHostedTests.showsParagraphs(of: Self.thoughtText, in: harness))
      #expect(harness.element(identifier: LinkView.cardIdentifier)?.label == Self.linkName)
    }

    // MARK: - Compaction

    @Test func aCompactionSummaryShowsTheACPContentOfTheModel() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let compactionID = CompactionAndNoticeHostedTests.compactionID
      let summaryText = CompactionAndNoticeHostedTests.summaryText

      try await session.sendUpdate(
        WireBlockJSON.makeCompactionSummaryChunk(
          compactionID: compactionID, block: WireBlockJSON.makeText(summaryText)))
      try await session.sendUpdate(
        WireBlockJSON.makeCompactionSummaryChunk(compactionID: compactionID, block: Self.linkBlock))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: LinkView.cardIdentifier) != nil
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

      try await session.sendUpdate(Self.terminalUpdate(#""command": "\#(Self.command)""#))
      // The container element of the terminal merges into the element of its
      // row, so the test reads the command element of the header.
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: TerminalView.commandIdentifier) != nil
      }

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

      try await session.sendUpdate(Self.terminalUpdate(#""output": {"data": "\#(Self.base64("one\n"))"}"#))
      await harness.pump(until: Self.waitTimeout) { editor.text == "one\n" }
      #expect(editor.text == "one\n")

      try await session.sendUpdate(Self.terminalChunk("two\n"))
      await harness.pump(until: Self.waitTimeout) { editor.text == "one\ntwo\n" }
      #expect(editor.text == "one\ntwo\n")

      try await session.sendUpdate(Self.terminalUpdate(#""output": {"data": "\#(Self.base64("fresh"))"}"#))
      await harness.pump(until: Self.waitTimeout) { editor.text == "fresh" }
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
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: TaskListView.planIdentifier(row: planKey))?.label == "1 of 2 done"
      }

      let keys = model.transcript.map(\.rowKey)
      #expect(keys.count == 2)
      #expect(keys.first == planKey)
      #expect(SessionTranscriptViewHostedTests.rowKeys(in: harness) == keys)
      #expect(harness.element(identifier: TaskListView.planIdentifier(row: planKey))?.label == "1 of 2 done")
      #expect(
        harness.element(identifier: TaskListView.entryIdentifier(row: planKey, index: 0))?.label
          == "Read, Completed, High priority")
    }

    @Test func eachPlanWithNoPlanIdIsANewRowThatShowsTheContentType() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let update = ##"{"sessionUpdate": "plan_update", "plan": {"type": "markdown", "text": "# Plan"}}"##

      try await session.sendUpdate(update)
      try await session.sendUpdate(update)
      await harness.pump(until: Self.waitTimeout) {
        SessionTranscriptViewHostedTests.rowKeys(in: harness).count == 2
      }

      let keys = session.model.transcript.map(\.rowKey)
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

      try await session.sendUpdate(#"{"sessionUpdate": "\#(Self.unknownType)", "note": "\#(Self.unknownNote)"}"#)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: UnknownItemView.identifier) != nil
      }
      #expect(Self.labels(in: harness).contains { $0.contains(Self.unknownType) })

      let key = try #require(session.model.transcript.first?.rowKey)
      store.expand(key)
      await harness.pump(until: Self.waitTimeout) {
        Self.labels(in: harness).contains { $0.contains(Self.unknownNote) }
      }
      #expect(Self.labels(in: harness).contains { $0.contains(Self.unknownNote) })
    }

    // MARK: - Error

    @Test func aFailedPromptShowsAnErrorRowWithTheJSONRPCCode() async throws {
      let session = try await ScriptedSession.open { $0.failingMethods = ["session/prompt"] }
      defer { session.close() }
      let harness = Self.mountThread(session)
      defer { harness.close() }
      let model = session.model
      let identifier = ErrorView.identifier(for: .acp(code: Self.scriptedErrorCode, message: "failed"))

      let prompt = Task { try await model.prompt([.text(TextContent(text: "Hello."))]) }
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: identifier) != nil }

      if case .success = await prompt.result {
        Issue.record("The prompt did not fail.")
      }
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
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ErrorView.dataIdentifier) != nil
      }

      #expect(harness.element(identifier: ErrorView.dataIdentifier)?.label?.contains(Self.errorDataField) == true)
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
      if let terminal = firstTerminal {
        TerminalView(entry: terminal, model: editor)
      }
    }

    /// The first terminal entry of the transcript, or `nil`.
    private var firstTerminal: TerminalEntry? {
      session.transcript.lazy.compactMap { entry -> TerminalEntry? in
        if case .terminal(let terminal) = entry { terminal } else { nil }
      }.first
    }
  }
#endif
