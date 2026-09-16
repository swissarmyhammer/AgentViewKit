import AgentViewKit
import AgentViewKitRouter
import Foundation
import FoundationModelsExtras
import FoundationModelsRouter
import Testing

/// The text of an assistant message, or `nil` for another kind.
@MainActor
private func messageText(_ item: ThreadItem?) -> String? {
  guard case .assistantMessage(let message)? = item else { return nil }
  return message.blocks.compactMap { block -> String? in
    guard case .text(let text) = block.content else { return nil }
    return text
  }.joined()
}

/// Tests for ``RouterThreadSource`` with a scripted session.
@MainActor
@Suite struct RouterThreadSourceTests {
  @Test func runSeedsTheRowsAndThenAppliesTheSessionEvents() async throws {
    let session = FakeRouterSession()
    let projection = SessionProjection()
    projection.apply(.textDelta("Earlier"))
    projection.apply(.entryRecorded(id: "e0", kind: .response))
    session.rows = projection.transcript
    let source = RouterThreadSource(port: session)
    session.emit(
      .turnStarted(RouterFixtures.turnStart),
      .toolCall(id: "c1", name: "read", argumentsJSON: "{}"),
      .toolStatus(id: "c1", status: .completed, summary: "ok", output: nil),
      .turnEnded(TokenUsage(tokensIn: 1, tokensOut: 1, contextFill: 0.5))
    )
    session.finish()
    await source.run()
    #expect(session.calls == [.sessionEvents, .transcriptRows])
    #expect(source.thread.items.map(\.id) == ["e0", "c1"])
    #expect(messageText(source.thread.item(id: "e0")) == "Earlier")
    #expect(source.thread.state == .idle(.endTurn))
    #expect(source.thread.usage == ContextUsage(used: 2, size: 4))
  }

  @Test func runReadsTheSessionOneTime() async {
    let session = FakeRouterSession()
    session.finish()
    let source = RouterThreadSource(port: session)
    await source.run()
    await source.run()
    #expect(session.calls == [.sessionEvents, .transcriptRows])
  }

  @Test func textFragmentsStreamIntoAProvisionalRow() throws {
    let source = RouterThreadSource(port: FakeRouterSession())
    source.apply(.textDelta("Hel"))
    source.apply(.textDelta("lo"))
    #expect(source.thread.items.map(\.id) == ["provisional-1"])
    let stream = try #require(source.thread.streaming["provisional-1"])
    stream.flush()
    #expect(stream.text == "Hello")
  }

  @Test func entryRecordedGivesTheDurableIDToTheProvisionalRow() throws {
    let source = RouterThreadSource(port: FakeRouterSession())
    source.thread.apply(.patch(id: "before", .userMessage(content: .value([ContentBlock(text: "Q")]))))
    source.apply(.textDelta("Hello"))
    source.thread.apply(.patch(id: "after", .toolCall(title: .value("read"))))
    source.apply(.entryRecorded(id: "e1", kind: .response))
    #expect(source.thread.items.map(\.id) == ["before", "e1", "after"])
    #expect(source.thread.streaming.isEmpty)
    #expect(messageText(source.thread.item(id: "e1")) == "Hello")
  }

  @Test func textResetClosesTheRowAndTheNextFragmentOpensANewRow() throws {
    let source = RouterThreadSource(port: FakeRouterSession())
    source.apply(.textDelta("Draft"))
    source.apply(.textReset)
    source.apply(.textDelta("Final"))
    #expect(source.thread.items.map(\.id) == ["provisional-1", "provisional-2"])
    #expect(messageText(source.thread.item(id: "provisional-1")) == "Draft")
    source.apply(.entryRecorded(id: "e1", kind: .response))
    source.apply(.entryRecorded(id: "e2", kind: .response))
    #expect(source.thread.items.map(\.id) == ["e1", "e2"])
    #expect(messageText(source.thread.item(id: "e1")) == "Draft")
    #expect(messageText(source.thread.item(id: "e2")) == "Final")
  }

  @Test func reasoningFragmentsCloseTheTextStreamAndGetTheirDurableID() throws {
    let source = RouterThreadSource(port: FakeRouterSession())
    source.apply(.textDelta("Answer"))
    source.apply(.reasoningDelta("Why"))
    #expect(source.thread.streaming["provisional-1"] == nil)
    #expect(source.thread.streaming["provisional-2"]?.text == "Why")
    source.apply(.entryRecorded(id: "r1", kind: .reasoning))
    guard case .reasoning(let reasoning)? = source.thread.item(id: "r1") else {
      Issue.record("Expected a reasoning record")
      return
    }
    #expect(reasoning.segments == ["Why"])
    #expect(source.thread.items.map(\.id) == ["provisional-1", "r1"])
  }

  @Test func entryRecordedWithNoProvisionalRowChangesNothing() {
    let source = RouterThreadSource(port: FakeRouterSession())
    source.apply(.entryRecorded(id: "e1", kind: .response))
    source.apply(.entryRecorded(id: "c1", kind: .toolCalls))
    #expect(source.thread.items.isEmpty)
  }

  @Test func turnEndedClosesTheOpenStream() {
    let source = RouterThreadSource(port: FakeRouterSession())
    source.apply(.textDelta("Partial"))
    source.apply(.turnEnded(TokenUsage(tokensIn: 1, tokensOut: 1, contextFill: 0.5)))
    #expect(source.thread.streaming.isEmpty)
    #expect(messageText(source.thread.item(id: "provisional-1")) == "Partial")
  }

  @Test func elicitationRequestedAppearsInThePendingElicitations() async throws {
    let session = FakeRouterSession()
    let source = RouterThreadSource(port: session)
    session.emit(.elicitationRequested(try RouterFixtures.formElicitation()))
    session.finish()
    await source.run()
    let request = try #require(source.thread.pendingElicitations.first)
    #expect(request.id.rawValue == RouterFixtures.elicitationId.ulidString)
  }

  @Test func seedFromAProjectionCopiesTheRows() {
    let projection = SessionProjection()
    projection.apply(.toolCall(id: "c1", name: "read", argumentsJSON: "{}"))
    let source = RouterThreadSource(port: FakeRouterSession())
    source.seed(from: projection)
    #expect(source.thread.items.map(\.id) == ["c1"])
  }
}
