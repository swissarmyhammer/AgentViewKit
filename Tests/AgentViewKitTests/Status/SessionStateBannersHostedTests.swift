#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The state banners of a `SessionModel` (update.md §4.2 `agentState`, §4.7
  /// "Agent state", "Resume", "Missed updates", "Closed thread", §9.2).
  ///
  /// Each test shows the thread of a scripted session and a composer below it.
  /// The banners read the model directly, so the scripted agent changes the
  /// model and the test reads the banner text after each change.
  @Suite(.serialized, .hostedSerially) @MainActor struct SessionStateBannersHostedTests {
    /// The longest time that a test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows the thread, the banners and the composer.
    static let size = CGSize(width: 480, height: 800)

    /// The text of the composer draft.
    static let draftText = "Hello"

    /// The buffer limits of the overflow test: the connection keeps one
    /// update of one session.
    static let smallBufferLimits = SessionUpdateBufferLimits(maximumUpdatesPerSession: 1, maximumSessions: 1)

    /// The number of updates that the agent sends before the `session/new`
    /// result in the overflow test. It is more than the buffer keeps.
    static let overflowUpdateCount = 2

    /// The two additional workspace roots of the session in the reload test.
    static let additionalDirectories = [AbsolutePath(rawValue: "/tmp/shared-lib"), AbsolutePath(rawValue: "/tmp/docs")]

    /// The names of the stream state of the session model. No source of the
    /// status views declares a property with one of these names.
    static let streamStateNames = ["agentState", "hasMissedUpdates", "isReplaying", "history", "isClosed"]

    /// Each `state_update` that the test sends, with the title that the state
    /// banner must show for it, in send order.
    static let stateTitles: [(update: String, title: String)] = [
      (stateUpdate(#""state": "running""#), "The agent is working"),
      (stateUpdate(#""state": "requires_action""#), "The agent needs your input"),
      (stateUpdate(#""state": "idle""#), "The agent is ready"),
      (stateUpdate(#""state": "idle", "stopReason": "end_turn""#), "The turn is complete"),
      (stateUpdate(#""state": "idle", "stopReason": "cancelled""#), "The turn was cancelled"),
      (stateUpdate(#""state": "idle", "stopReason": "max_tokens""#), "The response is incomplete"),
      (stateUpdate(#""state": "idle", "stopReason": "max_turn_requests""#), "The turn stopped"),
      (stateUpdate(#""state": "idle", "stopReason": "refusal""#), "The model refused to continue"),
      (stateUpdate(#""state": "idle", "stopReason": "_truncated""#), "The response was cut off"),
      (stateUpdate(#""state": "idle", "stopReason": "_custom_stop""#), "The turn stopped for an unknown reason"),
      (stateUpdate(#""state": "paused""#), "The agent reported an unknown state"),
    ]

    /// A `state_update` value.
    ///
    /// - Parameter fields: The other fields of the update, as JSON members.
    /// - Returns: The JSON text of the update.
    static func stateUpdate(_ fields: String) -> String {
      #"{"sessionUpdate": "state_update", \#(fields)}"#
    }

    /// The `session/update` frame of one agent message chunk of the scripted
    /// session.
    ///
    /// - Parameter index: The number of the chunk, which makes its message id.
    /// - Returns: The JSON text of the frame.
    static func chunkFrame(index: Int) -> String {
      let update =
        #"{"sessionUpdate": "agent_message_chunk", "messageId": "early-\#(index)", "content": {"type": "text", "text": "Early."}}"#
      return
        #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"\#(ScriptedSession.sessionID)","update":\#(update)}}"#
    }

    /// Shows the thread of a session and a composer below it. The thread gets
    /// the connection model of the session.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - draft: The model that holds the text of the composer.
    /// - Returns: The harness.
    static func mount(
      _ session: ScriptedSession, draft: PromptInputHostedTestModel
    ) -> HostedViewHarness<some View> {
      HostedViewHarness(size: size) {
        VStack(spacing: 0) {
          AgentThreadView(session: session.model, connection: session.connection, actions: NoopThreadActions())
          PromptInputHost(model: draft)
        }
        .environment(\.sessionModel, session.model)
        .environment(\.connectionModel, session.connection)
        .transaction { $0.disablesAnimations = true }
      }
    }

    /// Tells whether the text of a stream banner shows in `harness`.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the text of the banner.
    ///   - harness: The harness that shows the thread.
    /// - Returns: `true` when the text shows.
    static func shows<Content: View>(_ identifier: String, in harness: HostedViewHarness<Content>) -> Bool {
      harness.element(identifier: identifier) != nil
    }

    // MARK: - Agent state

    @Test func eachAgentStateShowsItsBannerAndANewValueReplacesIt() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mount(session, draft: PromptInputHostedTestModel())
      defer { harness.close() }
      harness.pump()
      #expect(harness.stateBannerLabel == nil)

      for (update, title) in Self.stateTitles {
        try await session.sendUpdate(update)
        await harness.pump(until: Self.waitTimeout) { harness.stateBannerLabel == title }

        #expect(harness.stateBannerLabel == title, "The banner is wrong after \(update).")
      }
    }

    @Test func theShowErrorButtonGivesTheLastErrorEntryOfTheTranscript() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      var shown: [TranscriptEntry.ID] = []
      let harness = HostedViewHarness(size: Self.size) {
        StateBanner(session: session.model) { shown.append($0) }
      }
      defer { harness.close() }
      session.model.appendError(code: .internalError, message: "first", data: nil)
      session.model.appendError(code: .internalError, message: "second", data: nil)
      let lastError = try #require(session.model.transcript.last)

      try await session.sendUpdate(Self.stateUpdate(#""state": "idle", "stopReason": "refusal""#))
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: StateBanner.showErrorIdentifier) != nil }
      try harness.press(identifier: StateBanner.showErrorIdentifier)
      await harness.pump(until: Self.waitTimeout) { !shown.isEmpty }

      #expect(shown == [lastError.id])
    }

    // MARK: - Resume

    @Test func aResumeShowsTheReplayMarkerAndThenThePartialHistoryNote() async throws {
      let session = try await ScriptedSession.open { $0.heldMethods = [ScriptedSession.resumeMethod] }
      defer { session.close() }
      let harness = Self.mount(session, draft: PromptInputHostedTestModel())
      defer { harness.close() }
      harness.pump()
      #expect(!Self.shows(SessionStreamBanner.partialHistoryIdentifier, in: harness))

      let resume = Task { try await session.connection.resumeSession(ScriptedSession.replayFromStartRequest) }
      await harness.pump(until: Self.waitTimeout) { Self.shows(SessionStreamBanner.replayingIdentifier, in: harness) }

      #expect(session.model.isReplaying)
      #expect(Self.shows(SessionStreamBanner.replayingIdentifier, in: harness))
      #expect(!Self.shows(SessionStreamBanner.partialHistoryIdentifier, in: harness))

      session.agent.releaseHeldAnswer()
      _ = try await resume.value
      await harness.pump(until: Self.waitTimeout) { Self.shows(SessionStreamBanner.partialHistoryIdentifier, in: harness) }

      #expect(!Self.shows(SessionStreamBanner.replayingIdentifier, in: harness))
      let note = try #require(harness.element(identifier: SessionStreamBanner.partialHistoryIdentifier)?.label)
      #expect(note.contains("can be partial"))
      #expect(!note.localizedCaseInsensitiveContains("complete"))
    }

    // MARK: - Missed updates

    /// Opens a scripted session whose update buffer overflows before the
    /// `session/new` result, so that the session model gets
    /// `hasMissedUpdates`. The agent holds its answer to `session/resume`.
    ///
    /// - Parameter additionalDirectories: The additional workspace roots of
    ///   the `session/new` request.
    /// - Returns: The open session.
    /// - Throws: The error of `initialize` or of `session/new`.
    static func openOverflowingSession(additionalDirectories: [AbsolutePath] = []) async throws -> ScriptedSession {
      try await ScriptedSession.open(bufferLimits: smallBufferLimits, additionalDirectories: additionalDirectories) {
        $0.leadIns["session/new"] = { _, _ in (1...overflowUpdateCount).map(chunkFrame(index:)) }
        $0.heldMethods = [ScriptedSession.resumeMethod]
      }
    }

    @Test func anOverflowShowsTheMissedUpdatesBannerAndReloadReplaysFromTheStart() async throws {
      let session = try await Self.openOverflowingSession()
      defer { session.close() }
      let harness = Self.mount(session, draft: PromptInputHostedTestModel())
      defer { harness.close() }
      await harness.pump(until: Self.waitTimeout) { Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness) }
      #expect(session.model.hasMissedUpdates)

      try harness.press(identifier: SessionStreamBanner.reloadIdentifier)
      await harness.pump(until: Self.waitTimeout) { !session.agent.messages(method: ScriptedSession.resumeMethod).isEmpty }
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: SessionStreamBanner.reloadIdentifier)?.isEnabled == false
      }

      #expect(session.model.isReplaying)
      let resume = try #require(session.agent.messages(method: ScriptedSession.resumeMethod).first)
      #expect(resume["params"]?["replayFrom"]?["type"]?.stringValue == "start")
      #expect(resume["params"]?["sessionId"]?.stringValue == ScriptedSession.sessionID)
      #expect(resume["params"]?["cwd"]?.stringValue == ScriptedSession.workingDirectory)
      #expect(resume["params"]?["additionalDirectories"] == nil)
      #expect(Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness))
      #expect(harness.element(identifier: SessionStreamBanner.reloadIdentifier)?.isEnabled == false)

      session.agent.releaseHeldAnswer()
      await harness.pump(until: Self.waitTimeout) { !session.model.hasMissedUpdates }
      await harness.pump(until: Self.waitTimeout) { !Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness) }

      #expect(!Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness))
      #expect(session.agent.messages(method: ScriptedSession.resumeMethod).count == 1)
    }

    @Test func reloadSendsTheWorkingDirectoryAndTheAdditionalDirectoriesOfTheSessionModel() async throws {
      let session = try await Self.openOverflowingSession(additionalDirectories: Self.additionalDirectories)
      defer { session.close() }
      let harness = Self.mount(session, draft: PromptInputHostedTestModel())
      defer { harness.close() }
      await harness.pump(until: Self.waitTimeout) { Self.shows(SessionStreamBanner.reloadIdentifier, in: harness) }
      #expect(session.model.additionalDirectories == Self.additionalDirectories)

      try harness.press(identifier: SessionStreamBanner.reloadIdentifier)
      await harness.pump(until: Self.waitTimeout) { !session.agent.messages(method: ScriptedSession.resumeMethod).isEmpty }

      let resume = try #require(session.agent.messages(method: ScriptedSession.resumeMethod).first)
      #expect(resume["params"]?["cwd"]?.stringValue == ScriptedSession.workingDirectory)
      #expect(
        resume["params"]?["additionalDirectories"] == .array(Self.additionalDirectories.map { .string($0.rawValue) }))
    }

    // MARK: - Closed thread

    @Test func aClosedSessionShowsTheClosedStateAndDisablesTheComposer() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mount(session, draft: PromptInputHostedTestModel(text: Self.draftText))
      defer { harness.close() }
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil
      }
      #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == true)
      #expect(!Self.shows(SessionStreamBanner.closedIdentifier, in: harness))

      try await session.connection.close(session.model)
      await harness.pump(until: Self.waitTimeout) { Self.shows(SessionStreamBanner.closedIdentifier, in: harness) }

      #expect(Self.shows(SessionStreamBanner.closedIdentifier, in: harness))
      #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == false)
    }

    // MARK: - No copy

    @Test func noStatusSourceDeclaresACopyOfTheStreamState() throws {
      let statusDirectory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../../Sources/AgentViewKit/Status")
        .standardizedFileURL
      let files = try FileManager.default.contentsOfDirectory(at: statusDirectory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "swift" }
      let names = Self.streamStateNames.joined(separator: "|")
      let declaration = try Regex(#"\b(let|var)\s+(\#(names))\b"#)
      #expect(!files.isEmpty)

      let copies = try SourceLines.matching(declaration, in: files)

      #expect(copies.isEmpty, "A status source keeps a copy of the stream state: \(copies)")
    }
  }
#endif
