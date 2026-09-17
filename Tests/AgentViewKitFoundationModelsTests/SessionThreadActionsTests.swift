import AgentViewKit
import AgentViewKitFoundationModels
import AgentViewKitTestSupport
import Foundation
import FoundationModels
import Testing

/// The values and the helpers of the actions and hooks tests.
enum ActionSamples {
  /// The id of the reasoning entry that the fake model makes.
  static let reasoningID = "reasoning-1"

  /// The time that the fixed source clock gives.
  static let fixedTime = Date(timeIntervalSince1970: 0)

  /// The number of unsupported verbs of the actions.
  static let unsupportedVerbCount = 8

  /// A turn with reasoning, one tool call, and then a text answer.
  static var reasoningToolTurn: [[FakeEvent]] {
    [[.reasoning(entryID: reasoningID, text: "Read the file first.")] + SourceSamples.toolTurn[0]]
      + SourceSamples.toolTurn.dropFirst()
  }

  /// Makes a profile with the read tool, the fake model, and the hooks.
  ///
  /// The profile is built outside the main actor, so that the session can
  /// take it as a `sending` value.
  ///
  /// - Parameters:
  ///   - rounds: The events of each model call of a turn.
  ///   - instructions: The instructions of the session.
  ///   - hooks: The hooks that stamp the host times.
  /// - Returns: The profile.
  nonisolated static func profile(
    rounds: [[FakeEvent]],
    instructions: String,
    hooks: SessionProfileHooks
  ) -> some LanguageModelSession.DynamicProfile {
    hooks.install(
      on: LanguageModelSession.Profile {
        Instructions(instructions)
        FakeReadTool()
      }
      .model(FakeLanguageModel(rounds: rounds)))
  }

  /// The record of a reasoning item, or `nil` for another item.
  ///
  /// - Parameter item: The item.
  /// - Returns: The record.
  static func reasoning(_ item: ThreadItem?) -> AgentViewKit.Reasoning? {
    if case .reasoning(let record) = item { record } else { nil }
  }
}

/// The debug messages that the actions wrote.
final class DebugLog {
  /// The messages, in order.
  private(set) var messages: [String] = []

  /// Adds a message.
  ///
  /// - Parameter message: The message.
  func write(_ message: String) {
    messages.append(message)
  }
}

@Suite @MainActor struct SessionThreadActionsTests {
  // MARK: - Send and cancel

  /// Sends the prompt of a gated stream, and cancels the turn in the middle
  /// of the stream.
  ///
  /// The helper waits for the response entry in the transcript of the
  /// session, not for the streamed text. A stream snapshot comes one event
  /// late, so the text of the first chunk group can stay back until the gate
  /// opens.
  ///
  /// - Parameters:
  ///   - actions: The actions over a source of a gated session.
  ///   - gate: The gate of the fake model of the session.
  private func sendAndCancel(_ actions: SessionThreadActions, gate: FakeGate) async {
    let source = actions.source
    let sending = Task { await actions.send(UserInput(text: SourceSamples.prompt)) }
    #expect(await waitUntil { source.session.transcript.last?.id == SourceSamples.responseID })
    #expect(source.thread.state == .running)
    let cancelling = Task { await actions.cancel() }
    #expect(await waitUntil { actions.turn?.isCancelled == true })
    for _ in SourceSamples.chunkGroups.dropFirst() {
      gate.open()
    }
    await cancelling.value
    await sending.value
  }

  @Test func sendThenCancelLeavesTheThreadIdleAndTheTurnCancelled() async throws {
    let gate = FakeGate()
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [SourceSamples.gatedStreamEvents], gate: gate))
    let source = SessionThreadSource(session: session)
    let actions = SessionThreadActions(source: source)
    defer { source.stop() }
    source.start()

    await sendAndCancel(actions, gate: gate)

    #expect(source.thread.state == .idle(nil))
    #expect(actions.turn?.isCancelled == true)
    #expect(session.transcript.isEmpty)
    #expect(source.thread.items.isEmpty)
  }

  @Test func aCancelWithThePreservePolicyKeepsTheTurnWithNoError() async throws {
    let gate = FakeGate()
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [SourceSamples.gatedStreamEvents], gate: gate))
    let source = SessionThreadSource(session: session)
    let actions = SessionThreadActions(source: source, transcriptErrorHandlingPolicy: .preserveTranscript)
    defer { source.stop() }
    source.start()

    await sendAndCancel(actions, gate: gate)

    let transcriptIDs = session.transcript.map(\.id)
    #expect(transcriptIDs.last == SourceSamples.responseID)
    #expect(source.thread.items.map(\.id) == transcriptIDs)
    #expect(source.thread.state == .idle(nil))
  }

  @Test func cancelWithNoTurnDoesNothing() async {
    let session = LanguageModelSession(model: FakeLanguageModel(rounds: []))
    let source = SessionThreadSource(session: session)
    let actions = SessionThreadActions(source: source)

    await actions.cancel()

    #expect(actions.turn == nil)
    #expect(source.thread.state == .idle(nil))
  }

  @Test func sendStreamsTheAnswerIntoTheThread() async {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [[.text(entryID: SourceSamples.responseID, text: "Hello")]]))
    let source = SessionThreadSource(session: session)
    let actions = SessionThreadActions(source: source)
    defer { source.stop() }
    source.start()

    await actions.send(UserInput(text: SourceSamples.prompt))

    #expect(actions.turn?.isCancelled == false)
    #expect(source.thread.state == .idle(nil))
    #expect(SourceSamples.assistantMessage(source.thread.items.last)?.id == SourceSamples.responseID)
  }

  // MARK: - Unsupported verbs

  @Test func respondToAPermissionDoesNotThrowAndLogsOnce() async {
    let log = DebugLog()
    let session = LanguageModelSession(model: FakeLanguageModel(rounds: []))
    let source = SessionThreadSource(session: session)
    let actions = SessionThreadActions(source: source, debugLog: log.write)

    await actions.respond(to: ThreadFixtures.permissionRequest(), PermissionDecision(outcome: .cancelled))

    #expect(log.messages.count == 1)
    #expect(source.thread.items.isEmpty)
  }

  @Test func eachUnsupportedVerbLogsOnce() async throws {
    let log = DebugLog()
    let session = LanguageModelSession(model: FakeLanguageModel(rounds: []))
    let actions = SessionThreadActions(source: SessionThreadSource(session: session), debugLog: log.write)

    await actions.respond(to: ThreadFixtures.permissionRequest(), PermissionDecision(outcome: .cancelled))
    await actions.respond(to: ThreadFixtures.formElicitationRequest(), .cancel)
    await actions.setConfigOption(ConfigOptionID("mode"), .boolean(true))
    try await actions.connect(
      AuthorizationRequest(
        id: AuthorizationRequestID("auth-1"), serverName: "GitHub",
        authorizationURL: URL(filePath: "/auth"), meta: nil))
    try await actions.login(AuthMethodID("agent"))
    try await actions.runTerminalAuth(AuthMethod.Terminal(id: AuthMethodID("term"), name: "Terminal"))
    try await actions.writeTerminalLine("yes", to: TerminalID("terminal-1"))
    try await actions.logout()

    #expect(log.messages.count == ActionSamples.unsupportedVerbCount)
    #expect(Set(log.messages).count == ActionSamples.unsupportedVerbCount)
  }

  // MARK: - Profile hooks

  @Test func theHooksStampTheToolCallWithAStartBeforeTheEnd() async throws {
    let clock = TickingClock()
    let hooks = SessionProfileHooks(clock: clock.now)
    let session = LanguageModelSession(
      profile: ActionSamples.profile(
        rounds: SourceSamples.toolTurn, instructions: SourceSamples.instructions, hooks: hooks))
    let source = SessionThreadSource(session: session, clock: { ActionSamples.fixedTime }, hooks: hooks)
    defer { source.stop() }
    source.start()

    try await session.respond(to: SourceSamples.prompt)

    let found = await waitUntil {
      SourceSamples.toolCall(source.thread.item(id: SourceSamples.toolCallID))?.endedAt != nil
    }
    #expect(found)
    let record = try #require(SourceSamples.toolCall(source.thread.item(id: SourceSamples.toolCallID)))
    let started = try #require(record.startedAt)
    let ended = try #require(record.endedAt)
    #expect(started < ended)
    #expect(hooks.times(for: SourceSamples.toolCallID) == SessionActivityTimes(startedAt: started, endedAt: ended))
  }

  @Test func theHooksStampTheReasoningFromThePromptToItsEnd() async throws {
    let clock = TickingClock()
    let hooks = SessionProfileHooks(clock: clock.now)
    let session = LanguageModelSession(
      profile: ActionSamples.profile(
        rounds: ActionSamples.reasoningToolTurn, instructions: SourceSamples.instructions, hooks: hooks))
    let source = SessionThreadSource(session: session, clock: { ActionSamples.fixedTime }, hooks: hooks)
    defer { source.stop() }
    source.start()

    try await session.respond(to: SourceSamples.prompt)

    let found = await waitUntil {
      ActionSamples.reasoning(source.thread.item(id: ActionSamples.reasoningID))?.endedAt != nil
    }
    #expect(found)
    let record = try #require(ActionSamples.reasoning(source.thread.item(id: ActionSamples.reasoningID)))
    let started = try #require(record.startedAt)
    let ended = try #require(record.endedAt)
    #expect(started < ended)
    let promptID = try #require(session.transcript.first { entry in
      if case .prompt = entry { return true }
      return false
    }?.id)
    #expect(hooks.times(for: promptID)?.endedAt == started)
    let call = try #require(hooks.times(for: SourceSamples.toolCallID))
    #expect(ended <= call.startedAt)
    let response = try #require(hooks.times(for: SourceSamples.responseID))
    #expect(try #require(call.endedAt) <= response.startedAt)
  }

  @Test func withoutHooksTheSourceStampsTheObservationTimes() async throws {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: SourceSamples.toolTurn), tools: [FakeReadTool()])
    let source = SessionThreadSource(session: session, clock: { ActionSamples.fixedTime })
    defer { source.stop() }
    source.start()

    try await session.respond(to: SourceSamples.prompt)

    #expect(
      await waitUntil {
        SourceSamples.toolCall(source.thread.item(id: SourceSamples.toolCallID))?.endedAt != nil
      })
    let record = try #require(SourceSamples.toolCall(source.thread.item(id: SourceSamples.toolCallID)))
    #expect(record.startedAt == ActionSamples.fixedTime)
    #expect(record.endedAt == ActionSamples.fixedTime)
  }
}
