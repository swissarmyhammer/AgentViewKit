import AgentViewKit
import AgentViewKitFoundationModels
import AgentViewKitTestSupport
import FoundationModels
import Testing

@testable import DemoSupport

@Suite @MainActor struct SessionThreadSourceObservationTests {
  /// The number of text chunks in the long stream.
  static let longChunkCount = 1_000

  /// The id of the response entry of the long stream.
  static let longResponseID = "long-response"

  /// The text of one chunk of the long stream.
  static let longChunkText = "word "

  /// The number of item changes that one entry can make: the insert of its
  /// item, and the replace with the final entry (research R4).
  static let itemChangesPerEntry = 2

  /// The main actor passes after a stream, so that the last observation
  /// changes reach the counter.
  static let settlePasses = 16

  @Test func aLongStreamChangesTheItemsOnlyAtEntryBoundaries() async {
    let events = Array(
      repeating: FakeEvent.text(entryID: Self.longResponseID, text: Self.longChunkText),
      count: Self.longChunkCount)
    let session = LanguageModelSession(model: FakeLanguageModel(rounds: [events]))
    let source = SessionThreadSource(session: session)
    defer { source.stop() }
    let thread = source.thread
    let items = ChangeCounter { _ = thread.items }
    defer { items.stop() }
    source.start()

    await source.stream(SourceSamples.prompt)
    for _ in 0..<Self.settlePasses {
      await Task.yield()
    }

    #expect(thread.item(id: Self.longResponseID) != nil)
    #expect(items.count >= 1)
    #expect(items.count <= session.transcript.count * Self.itemChangesPerEntry)
  }

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
