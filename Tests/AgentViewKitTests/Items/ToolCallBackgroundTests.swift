import AgentViewKitTestSupport
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// A tool call whose work goes on in the background stays live until its
/// real end, and a live call that no update can end shows the lost status.
@MainActor @Suite struct ToolCallBackgroundTests {
  /// The id of the background call of the script.
  static let detachedID = ToolCallId(rawValue: BackgroundRunScript.detachedTitle)

  /// The background call of the transcript of `model`, or `nil`.
  static func detachedCall(in model: SessionModel) -> ToolCallEntry? {
    model.transcript.lazy.compactMap { entry in
      if case .toolCall(let call) = entry, call.toolCallId == detachedID { call } else { nil }
    }.first
  }

  /// Sends the steps of the script, and waits for the change of each step.
  static func send(_ steps: ArraySlice<BackgroundRunScript.Step>, to session: ScriptedSession)
    async throws
  {
    let model = session.model
    for step in steps {
      try await session.send(update: step.update)
      switch step.change {
      case .agentRunning:
        let update = step.update
        await ObservationWait.until { model.agentState.map(SessionUpdate.stateUpdate) == update }
      case .toolCallStatus(_, let status):
        await ObservationWait.until { detachedCall(in: model)?.status == status }
      case .agentMessageText:
        break
      }
    }
  }

  @Test(arguments: [ToolCallStatus.completed, .failed])
  func backgroundCallStaysLiveThroughIdleUntilItsFinalStatus(endStatus: ToolCallStatus) async throws
  {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let steps = BackgroundRunScript.detachedRunSteps(endStatus: endStatus)

    // Through the idle that lists the call.
    try await Self.send(steps.prefix(4), to: session)
    let running = try #require(Self.detachedCall(in: session.model))
    let runningStatus = ToolCallBackground.shownStatus(of: running)
    #expect(running.status == .inProgress)
    #expect(runningStatus == .inProgress)
    #expect(EditorStatus(runningStatus).isLive)
    #expect(ToolCallBackground.showsBackgroundCaption(running, shownStatus: runningStatus))

    // The final status and the idle with no background work.
    try await Self.send(steps.dropFirst(4), to: session)
    let ended = try #require(Self.detachedCall(in: session.model))
    let endedStatus = ToolCallBackground.shownStatus(of: ended)
    #expect(endedStatus == endStatus)
    #expect(!EditorStatus(endedStatus).isLive)
    #expect(!ToolCallBackground.showsBackgroundCaption(ended, shownStatus: endedStatus))
  }

  @Test func backgroundCallThatTheIdleAgentDoesNotListIsLost() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let steps = BackgroundRunScript.detachedRunSteps(endStatus: .completed)

    // The call is in progress with its token, then the agent is idle with
    // no background work.
    try await Self.send(steps.prefix(3), to: session)
    try await Self.send(steps.suffix(1), to: session)
    let call = try #require(Self.detachedCall(in: session.model))
    let status = ToolCallBackground.shownStatus(of: call)
    #expect(call.status == .inProgress)
    #expect(status == ToolCallBackground.staleStatus)
    #expect(!EditorStatus(status).isLive)
    #expect(!ToolCallBackground.showsBackgroundCaption(call, shownStatus: status))
  }

  @Test func liveCallOfAClosedSessionIsLost() async throws {
    let session = try await ScriptedSession.open()
    let steps = BackgroundRunScript.detachedRunSteps(endStatus: .completed)
    try await Self.send(steps.prefix(4), to: session)
    let model = session.model

    session.close()
    await ObservationWait.until { model.isClosed }

    let call = try #require(Self.detachedCall(in: model))
    #expect(ToolCallBackground.shownStatus(of: call) == ToolCallBackground.staleStatus)
  }

  @Test func backgroundCallHasTheCompletionTokenOfItsMetadata() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await Self.send(
      BackgroundRunScript.detachedRunSteps(endStatus: .completed).prefix(3), to: session)
    let call = try #require(Self.detachedCall(in: session.model))
    #expect(call.backgroundRun == BackgroundRunScript.detachedCompletionToken)
  }
}
