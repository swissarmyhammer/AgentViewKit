#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The state banners of a `SessionModel` (plan.md §3.2 `agentState`, §3.8
  /// "Agent state and stop reasons", "Resume", "Missed updates", "Closed
  /// thread").
  ///
  /// Each test shows the thread of a scripted session and a composer below it.
  /// The banners read the model directly, so the scripted agent changes the
  /// model and the test reads the banner text after each change. The test
  /// waits for the model value that the change is certain to set, and then
  /// makes one render pass before it reads the banner.
  @Suite(.serialized, .hostedSerially) @MainActor struct SessionStateBannersHostedTests {
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
      (stateUpdate(#""state": "idle", "stopReason": "end_turn""#), "The response is complete"),
      (stateUpdate(#""state": "idle", "stopReason": "cancelled""#), "The response was cancelled"),
      (stateUpdate(#""state": "idle", "stopReason": "max_tokens""#), "The response is incomplete"),
      (stateUpdate(#""state": "idle", "stopReason": "max_turn_requests""#), "The response reached its request limit"),
      (stateUpdate(#""state": "idle", "stopReason": "refusal""#), "The model refused to continue"),
      (stateUpdate(#""state": "idle", "stopReason": "error""#), "The response failed"),
      (stateUpdate(#""state": "idle", "stopReason": "_truncated""#), "The response was cut off"),
      (stateUpdate(#""state": "idle", "stopReason": "_custom_stop""#), "The response stopped for an unknown reason"),
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
    /// - Throws: The error of the encoder.
    static func chunkFrame(index: Int) throws -> String {
      ScriptedSession.sessionUpdateFrame(
        update: try ScriptedSession.agentMessageChunkUpdate(messageID: "early-\(index)", text: "Early."))
    }

    /// Shows the thread of a session and a composer below it. The thread gets
    /// the connection model of the session.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - draft: The model that holds the text of the composer.
    ///   - requestStartReport: The report that gets the method of each request
    ///     that a view starts, or `nil`.
    /// - Returns: The harness.
    static func mount(
      _ session: ScriptedSession, draft: PromptInputHostedTestModel,
      requestStartReport: ObservationReport<String>? = nil
    ) -> HostedViewHarness<some View> {
      HostedViewHarness(size: size) {
        AgentThreadView(session: session.model, connection: session.connection) {
          PromptInputHost(model: draft)
        }
        .environment(\.sessionModel, session.model)
        .environment(\.connectionModel, session.connection)
        .environment(\.requestStartReport, requestStartReport)
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
      let model = session.model
      harness.hostingView.layoutSubtreeIfNeeded()
      #expect(harness.stateBannerLabel == nil)

      // Each state of the list differs from the state before it, so a change
      // of `agentState` is the event that the model folded the update.
      for (update, title) in Self.stateTitles {
        let before = model.agentState
        try await session.sendUpdate(update)
        await AgentWorkOrderHostedTests.layOut(harness) { model.agentState != before }

        #expect(harness.stateBannerLabel == title, "The banner is wrong after \(update).")
      }
    }

    /// The press of the Show Error button calls the host closure at once, so
    /// the test reads the closure value after the press.
    @Test func theShowErrorButtonGivesTheLastErrorEntryOfTheTranscript() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      var shown: [TranscriptEntry.ID] = []
      let harness = HostedViewHarness(size: Self.size) {
        StateBanner(session: session.model) { shown.append($0) }
      }
      defer { harness.close() }
      let model = session.model
      model.appendError(code: .internalError, message: "first", data: nil)
      model.appendError(code: .internalError, message: "second", data: nil)
      let lastError = try #require(model.transcript.last)

      let before = model.agentState
      try await session.sendUpdate(Self.stateUpdate(#""state": "idle", "stopReason": "refusal""#))
      await harness.render { model.agentState != before }
      #expect(harness.element(identifier: StateBanner.showErrorIdentifier)?.label == "Show Error")
      try harness.press(identifier: StateBanner.showErrorIdentifier)

      #expect(shown == [lastError.id])
    }

    // MARK: - Resume

    @Test func aResumeShowsTheReplayMarkerAndThenThePartialHistoryNote() async throws {
      let session = try await ScriptedSession.open { $0.heldMethods = [ScriptedSession.resumeMethod] }
      defer { session.close() }
      let harness = Self.mount(session, draft: PromptInputHostedTestModel())
      defer { harness.close() }
      let model = session.model
      harness.render()
      #expect(!Self.shows(SessionStreamBanner.partialHistoryIdentifier, in: harness))

      let resume = Task { try await session.connection.resumeSession(ScriptedSession.replayFromStartRequest) }
      await harness.render { model.isReplaying }

      #expect(model.isReplaying)
      #expect(Self.shows(SessionStreamBanner.replayingIdentifier, in: harness))
      #expect(!Self.shows(SessionStreamBanner.partialHistoryIdentifier, in: harness))

      session.agent.releaseHeldAnswer()
      _ = try await resume.value
      await harness.render { !model.isReplaying }

      #expect(!Self.shows(SessionStreamBanner.replayingIdentifier, in: harness))
      let note = try #require(harness.element(identifier: SessionStreamBanner.partialHistoryIdentifier)?.label)
      #expect(note.contains("can be partial"))
      #expect(!note.localizedCaseInsensitiveContains("complete"))
    }

    // MARK: - Missed updates

    /// How the scripted agent answers `session/resume` in a missed-updates
    /// test.
    enum ResumeAnswer {
      /// The agent holds its answer until the test releases it, and then
      /// answers with a result.
      case held
      /// The agent answers at once with a JSON-RPC error.
      case failure
    }

    /// Opens a scripted session whose update buffer overflows before the
    /// `session/new` result, so that the session model gets
    /// `hasMissedUpdates`.
    ///
    /// - Parameters:
    ///   - additionalDirectories: The additional workspace roots of the
    ///     `session/new` request.
    ///   - resumeAnswer: How the agent answers `session/resume`.
    /// - Returns: The open session.
    /// - Throws: The error of the encoder, of `initialize` or of
    ///   `session/new`.
    static func openOverflowingSession(
      additionalDirectories: [AbsolutePath] = [], resumeAnswer: ResumeAnswer = .held
    ) async throws -> ScriptedSession {
      let chunkFrames = try (1...overflowUpdateCount).map(chunkFrame(index:))
      return try await ScriptedSession.open(bufferLimits: smallBufferLimits, additionalDirectories: additionalDirectories) {
        $0.leadIns["session/new"] = { _, _ in chunkFrames }
        switch resumeAnswer {
        case .held: $0.heldMethods = [ScriptedSession.resumeMethod]
        case .failure: $0.failingMethods = [ScriptedSession.resumeMethod]
        }
      }
    }

    /// Whether the last entry of the transcript of `model` is an error entry,
    /// as the failure of a request that a view started adds.
    ///
    /// - Parameter model: The session model.
    /// - Returns: `true` when the last entry is an error entry.
    static func endsWithAnError(_ model: SessionModel) -> Bool {
      guard case .error = model.transcript.last else { return false }
      return true
    }

    /// Waits for the missed-updates banner, presses Reload, and waits until
    /// the failure of the resume is in the transcript.
    ///
    /// The banner records the failure before the session model adds the
    /// error entry, so the banner shows the failure when the entry is there.
    ///
    /// - Parameters:
    ///   - session: An overflowing session whose agent fails `session/resume`.
    ///   - harness: The harness that shows the thread of the session.
    /// - Throws: The error of the press.
    static func reloadAndWaitForTheFailure<Content: View>(
      of session: ScriptedSession, in harness: HostedViewHarness<Content>
    ) async throws {
      let model = session.model
      await harness.render { model.hasMissedUpdates }

      try harness.press(identifier: SessionStreamBanner.reloadIdentifier)
      await harness.render { !model.isReplaying && endsWithAnError(model) }
    }

    @Test func aFailedReloadShowsTheReloadFailedBannerWithTheReloadButton() async throws {
      let session = try await Self.openOverflowingSession(resumeAnswer: .failure)
      defer { session.close() }
      let harness = Self.mount(session, draft: PromptInputHostedTestModel())
      defer { harness.close() }

      try await Self.reloadAndWaitForTheFailure(of: session, in: harness)

      #expect(session.model.hasMissedUpdates)
      #expect(Self.shows(SessionStreamBanner.reloadFailedIdentifier, in: harness))
      #expect(!Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness))
      let reload = try #require(harness.element(identifier: SessionStreamBanner.reloadIdentifier))
      #expect(reload.label == "Reload")
      #expect(reload.isEnabled)
    }

    /// The test reads the error that the agent gives to `session/resume` with
    /// a resume of its own before the press, so the expected text comes from
    /// the same failure and not from a copy of its wording.
    @Test func theReloadFailedBannerExplainsTheErrorOfTheReload() async throws {
      let session = try await Self.openOverflowingSession(resumeAnswer: .failure)
      defer { session.close() }
      let failure = try #require(
        await #expect(throws: (any Error).self) {
          try await session.connection.resumeSession(ScriptedSession.replayFromStartRequest)
        })
      let harness = Self.mount(session, draft: PromptInputHostedTestModel())
      defer { harness.close() }

      try await Self.reloadAndWaitForTheFailure(of: session, in: harness)

      let label = try #require(harness.element(identifier: SessionStreamBanner.reloadFailedIdentifier)?.label)
      #expect(label.contains(failure.localizedDescription))
    }

    @Test func aReloadAfterAFailureShowsTheMissedUpdatesBannerAgainWhileItRuns() async throws {
      let session = try await Self.openOverflowingSession(resumeAnswer: .failure)
      defer { session.close() }
      let harness = Self.mount(session, draft: PromptInputHostedTestModel())
      defer { harness.close() }
      let model = session.model
      let agent = session.agent
      try await Self.reloadAndWaitForTheFailure(of: session, in: harness)
      agent.failingMethods = []
      agent.heldMethods = [ScriptedSession.resumeMethod]

      try harness.press(identifier: SessionStreamBanner.reloadIdentifier)
      await harness.render { model.isReplaying && agent.isHoldingAnswer }

      #expect(!Self.shows(SessionStreamBanner.reloadFailedIdentifier, in: harness))
      #expect(Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness))
      #expect(harness.element(identifier: SessionStreamBanner.reloadIdentifier)?.isEnabled == false)

      agent.releaseHeldAnswer()
      await harness.render { !model.hasMissedUpdates }

      #expect(!Self.shows(SessionStreamBanner.reloadFailedIdentifier, in: harness))
      #expect(!Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness))
    }

    /// The press of Reload starts the resume in a task. The agent holds its
    /// answer, so the model replays until the test releases the answer.
    @Test func anOverflowShowsTheMissedUpdatesBannerAndReloadReplaysFromTheStart() async throws {
      let session = try await Self.openOverflowingSession()
      defer { session.close() }
      let starts = ReportRecorder<String>()
      let harness = Self.mount(session, draft: PromptInputHostedTestModel(), requestStartReport: starts.report)
      defer { harness.close() }
      let model = session.model
      let agent = session.agent
      await harness.render { model.hasMissedUpdates }
      #expect(Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness))
      #expect(model.hasMissedUpdates)
      #expect(harness.element(identifier: SessionStreamBanner.reloadIdentifier)?.label == "Reload")

      try harness.press(identifier: SessionStreamBanner.reloadIdentifier)
      // The Reload button starts the resume in the same step as the press, so
      // a press that started nothing stops the test here.
      try #require(starts.values == [ScriptedSession.resumeMethod])
      await harness.render { model.isReplaying && !agent.messages(method: ScriptedSession.resumeMethod).isEmpty }

      #expect(model.isReplaying)
      let resume = try #require(agent.messages(method: ScriptedSession.resumeMethod).first)
      #expect(resume["params"]?["replayFrom"]?["type"]?.stringValue == "start")
      #expect(resume["params"]?["sessionId"]?.stringValue == ScriptedSession.sessionID)
      #expect(resume["params"]?["cwd"]?.stringValue == ScriptedSession.workingDirectory)
      #expect(resume["params"]?["additionalDirectories"] == nil)
      #expect(Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness))
      #expect(harness.element(identifier: SessionStreamBanner.reloadIdentifier)?.isEnabled == false)

      agent.releaseHeldAnswer()
      await harness.render { !model.hasMissedUpdates }

      #expect(!Self.shows(SessionStreamBanner.missedUpdatesIdentifier, in: harness))
      #expect(agent.messages(method: ScriptedSession.resumeMethod).count == 1)
    }

    @Test func reloadSendsTheWorkingDirectoryAndTheAdditionalDirectoriesOfTheSessionModel() async throws {
      let session = try await Self.openOverflowingSession(additionalDirectories: Self.additionalDirectories)
      defer { session.close() }
      let starts = ReportRecorder<String>()
      let harness = Self.mount(session, draft: PromptInputHostedTestModel(), requestStartReport: starts.report)
      defer { harness.close() }
      let model = session.model
      let agent = session.agent
      await harness.render { model.hasMissedUpdates }
      #expect(Self.shows(SessionStreamBanner.reloadIdentifier, in: harness))
      #expect(model.additionalDirectories == Self.additionalDirectories)

      try harness.press(identifier: SessionStreamBanner.reloadIdentifier)
      // The Reload button starts the resume in the same step as the press, so
      // a press that started nothing stops the test here.
      try #require(starts.values == [ScriptedSession.resumeMethod])
      await ObservationWait.until { !agent.messages(method: ScriptedSession.resumeMethod).isEmpty }

      let resume = try #require(agent.messages(method: ScriptedSession.resumeMethod).first)
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
      let model = session.model
      harness.render()
      #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == true)
      #expect(!Self.shows(SessionStreamBanner.closedIdentifier, in: harness))

      try await session.connection.close(model)
      await harness.render { model.isClosed }

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
