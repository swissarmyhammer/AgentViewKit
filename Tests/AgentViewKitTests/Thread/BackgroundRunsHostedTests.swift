#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import PackageFileSupport
  import SwiftUI
  import Testing

  /// The thread view over a session model while the agent ends its background
  /// runs after the streamed answer (update.md §9.3).
  ///
  /// The kit keeps no state for this order. Each row and the state banner
  /// show only what the session model reports.
  @Suite(.serialized, .hostedSerially) @MainActor struct BackgroundRunsHostedTests {
    /// The longest time that a test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows each row of the script and the state banner.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The number of agent messages of the script: the streamed answer and
    /// the full message with a new `messageId`.
    static let agentMessageCount = 2

    /// The names that a kit source must not declare: a kit copy of the turn,
    /// of the time of the last text, or of a wait for background work.
    static let turnStateNames = ["currentTurn", "lastText", "isWaiting", "waitingFor", "backgroundWork"]

    /// The title of the state banner while the agent runs.
    static let runningTitle = StateBanner.message(for: .running(RunningStateUpdate())).title

    /// Shows the thread of a scripted session.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The harness.
    static func makeHarness(session: ScriptedSession) -> HostedViewHarness<some View> {
      HostedViewHarness(AgentThreadView(session: session.model, actions: NoopThreadActions()), size: tallSize)
    }

    /// The agent message object of an entry.
    ///
    /// - Parameter entry: A transcript entry.
    /// - Returns: The object, or `nil` when the entry is not an agent message.
    static func agentMessage(of entry: TranscriptEntry) -> AgentMessageEntry? {
      if case .agentMessage(let message) = entry { message } else { nil }
    }

    /// The tool call object of an entry.
    ///
    /// - Parameter entry: A transcript entry.
    /// - Returns: The object, or `nil` when the entry is not a tool call.
    static func toolCall(of entry: TranscriptEntry) -> ToolCallEntry? {
      if case .toolCall(let toolCall) = entry { toolCall } else { nil }
    }

    /// The agent message entry of `model` with the message ID `messageID`.
    ///
    /// - Parameters:
    ///   - messageID: The `messageId` of the agent message.
    ///   - model: The session model.
    /// - Returns: The entry, or `nil` when the transcript has no such entry.
    static func agentMessage(messageID: String, in model: SessionModel) -> AgentMessageEntry? {
      model.transcript.lazy.compactMap(agentMessage(of:)).first { $0.messageId?.rawValue == messageID }
    }

    /// The tool call entry of `model` with the title `title`.
    ///
    /// - Parameters:
    ///   - title: The title of the tool call.
    ///   - model: The session model.
    /// - Returns: The entry, or `nil` when the transcript has no such entry.
    static func toolCall(title: String, in model: SessionModel) -> ToolCallEntry? {
      model.transcript.lazy.compactMap(toolCall(of:)).first { $0.title == title }
    }

    /// Tells whether `model` reports the change of one step of the script.
    ///
    /// - Parameters:
    ///   - change: The change of the step.
    ///   - model: The session model.
    /// - Returns: `true` when the model reports the change.
    static func isReported(change: BackgroundRunScript.Change, by model: SessionModel) -> Bool {
      switch change {
      case .agentRunning(let isRunning):
        ComposerSessionModelHostedTests.isRunning(model) == isRunning
      case .agentMessageText(let messageID, let text):
        agentMessage(messageID: messageID, in: model).map { SessionTranscriptViewHostedTests.text(of: $0.content) }
          == text
      case .toolCallStatus(let title, let status):
        toolCall(title: title, in: model)?.status == status
      }
    }

    /// The label that the row of a tool call entry must show.
    ///
    /// - Parameter entry: The tool call entry.
    /// - Returns: The label from the title and the status of the entry, or
    ///   `nil` when the model has no title or no status for the entry.
    static func expectedLabel(of entry: ToolCallEntry) -> String? {
      guard let title = entry.title, let status = entry.status else { return nil }
      return ToolCallView.accessibilityLabel(title: title, status: status)
    }

    /// Tells whether `harness` shows the transcript and the state of `model`:
    /// one row for each entry in transcript order, an assistant message view
    /// for each agent message, the title and the status of each tool call,
    /// and the banner of the agent state.
    ///
    /// - Parameters:
    ///   - model: The session model.
    ///   - harness: The harness that shows the thread.
    /// - Returns: `true` when the view shows what the model reports.
    static func showsTheModel<Content: View>(_ model: SessionModel, in harness: HostedViewHarness<Content>) -> Bool {
      let rowsMatch = SessionTranscriptViewHostedTests.rowKeys(in: harness) == model.transcript.map(\.rowKey)
      let messagesMatch = model.transcript.filter { agentMessage(of: $0) != nil }.allSatisfy { entry in
        harness.element(identifier: AssistantMessageView.identifier(for: entry.rowKey)) != nil
      }
      let toolCallsMatch = model.transcript.allSatisfy { entry in
        toolCall(of: entry).map { toolCall in
          harness.element(identifier: ToolCallView.identifier(for: entry.rowKey))?.label == expectedLabel(of: toolCall)
        } ?? true
      }
      let bannerMatches = harness.stateBannerLabel == model.agentState.map { StateBanner.message(for: $0).title }
      return rowsMatch && messagesMatch && toolCallsMatch && bannerMatches
    }

    /// Sends each step of ``BackgroundRunScript`` through the scripted agent.
    /// After each step, waits until the model reports the change of the step
    /// and the view shows the model, and then calls `afterStep`.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - harness: The harness that shows the thread of the session.
    ///   - afterStep: The checks after one step.
    static func playScript<Content: View>(
      session: ScriptedSession,
      harness: HostedViewHarness<Content>,
      afterStep: (BackgroundRunScript.Step) -> Void = { _ in }
    ) async throws {
      let model = session.model
      for step in BackgroundRunScript.steps {
        try await session.send(update: step.update)
        await harness.pump(until: waitTimeout) { isReported(change: step.change, by: model) }
        await harness.pump(until: waitTimeout) { showsTheModel(model, in: harness) }
        afterStep(step)
      }
    }

    @Test func eachStepShowsWhatTheModelReportsAndTheRunningBannerStaysUntilIdle() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.makeHarness(session: session)
      defer { harness.close() }
      let model = session.model

      try await Self.playScript(session: session, harness: harness) { step in
        #expect(Self.isReported(change: step.change, by: model), "\(step.change)")
        #expect(Self.showsTheModel(model, in: harness), "\(step.change)")
        let isIdleStep = step.change == .agentRunning(false)
        #expect(ComposerSessionModelHostedTests.isRunning(model) == !isIdleStep, "\(step.change)")
        #expect((harness.stateBannerLabel == Self.runningTitle) == !isIdleStep, "\(step.change)")
      }
    }

    @Test func theThreadShowsTwoAgentMessageRowsWithTheToolRowsBetweenThem() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.makeHarness(session: session)
      defer { harness.close() }
      let model = session.model

      try await Self.playScript(session: session, harness: harness)

      let transcript = model.transcript
      let messagePositions = transcript.indices.filter { Self.agentMessage(of: transcript[$0]) != nil }
      let toolPositions = transcript.indices.filter { Self.toolCall(of: transcript[$0]) != nil }
      #expect(messagePositions.count == Self.agentMessageCount)
      #expect(
        messagePositions.map { Self.agentMessage(of: transcript[$0])?.messageId?.rawValue }
          == [BackgroundRunScript.streamedMessageID, BackgroundRunScript.fullMessageID])
      let first = try #require(messagePositions.first)
      let last = try #require(messagePositions.last)
      #expect(toolPositions.count == BackgroundRunScript.toolTitles.count)
      #expect(toolPositions.allSatisfy { first < $0 && $0 < last })
      #expect(SessionTranscriptViewHostedTests.rowKeys(in: harness) == transcript.map(\.rowKey))
      for position in messagePositions {
        #expect(harness.element(identifier: AssistantMessageView.identifier(for: transcript[position].rowKey)) != nil)
      }
    }

    @Test func noKitSourceDeclaresATurnOrAWaitState() throws {
      let files = try PackageFiles.swiftFiles(in: PackageFiles.file("Sources/AgentViewKit"))
      let names = Self.turnStateNames.joined(separator: "|")
      let declaration = try Regex(#"\b(let|var)\s+(\#(names))\w*\b"#)
      #expect(!files.isEmpty)

      let declarations = try SourceLines.matching(declaration, in: files)

      #expect(declarations.isEmpty, "A kit source keeps a turn or a wait state: \(declarations)")
    }
  }
#endif
