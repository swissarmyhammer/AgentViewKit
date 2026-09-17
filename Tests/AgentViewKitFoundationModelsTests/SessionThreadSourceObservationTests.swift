import AgentViewKit
import AgentViewKitFoundationModels
import AgentViewKitTestSupport
import FoundationModels
import Testing

@Suite @MainActor struct SessionThreadSourceObservationTests {
  @Test func aChunkInvalidatesOnlyTheStreamingObserver() async throws {
    let gate = FakeGate()
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [SourceSamples.gatedStreamEvents], gate: gate))
    let source = SessionThreadSource(session: session)
    defer { source.stop() }
    let thread = source.thread
    source.start()
    let run = Task { await source.stream(SourceSamples.prompt) }
    #expect(await SourceSamples.openFirstGateAndWaitForText(session: session, thread: thread, gate: gate))
    let message = try #require(thread.streaming[SourceSamples.responseID])
    let first = message.text
    let itemsChanged = ChangeFlag.observing { _ = thread.items }
    let streamChanged = ChangeFlag.observing { _ = message.text }

    gate.open()
    let grew = await waitUntil {
      message.flush()
      return message.text.count > first.count
    }

    #expect(grew)
    #expect(streamChanged.value)
    #expect(!itemsChanged.value)
    gate.open()
    await run.value
  }
}
