import AgentViewKit
import AgentViewKitTestSupport
import Observation
import Testing

@MainActor
@Suite struct AgentThreadObservationTests {
  /// Makes a thread with one tool call.
  private func makeThread() -> AgentThread {
    let thread = AgentThread()
    thread.apply(.insert(.toolCall(ToolCallRecord(id: "t1", title: "Run")), after: nil))
    return thread
  }

  @Test func aUsageUpdateDoesNotNotifyAnObserverOfTheItems() {
    let thread = makeThread()
    let changed = ChangeFlag.observing { _ = thread.items }

    thread.apply(.setUsage(ContextUsage(used: 1, size: 10)))

    #expect(!changed.value)
  }

  @Test func aUsageUpdateNotifiesAnObserverOfTheUsage() {
    let thread = makeThread()
    let changed = ChangeFlag.observing { _ = thread.usage }

    thread.apply(.setUsage(ContextUsage(used: 1, size: 10)))

    #expect(changed.value)
  }

  @Test func aPatchOfAnExistingRecordDoesNotNotifyAnObserverOfTheItems() {
    let thread = makeThread()
    let changed = ChangeFlag.observing { _ = thread.items }

    thread.apply(.patch(id: "t1", .toolCall(status: .value(.completed))))

    #expect(!changed.value)
  }

  @Test func aPatchOfAnExistingRecordNotifiesAnObserverOfThatRecord() {
    let thread = makeThread()
    let record = thread.items[0].record
    let changed = ChangeFlag.observing { _ = record.revision }

    thread.apply(.patch(id: "t1", .toolCall(status: .value(.completed))))

    #expect(changed.value)
  }

  @Test func anInsertNotifiesAnObserverOfTheItems() {
    let thread = makeThread()
    let changed = ChangeFlag.observing { _ = thread.items }

    thread.apply(.patch(id: "t2", .toolCall(title: .value("Search"))))

    #expect(changed.value)
  }

  @Test func aStreamingAppendDoesNotNotifyAnObserverOfTheItems() {
    let thread = makeThread()
    thread.apply(.appendStreaming(id: "t1", text: "a"))
    let changed = ChangeFlag.observing {
      _ = thread.items
      _ = thread.streaming
    }

    thread.apply(.appendStreaming(id: "t1", text: "b"))

    #expect(!changed.value)
  }
}
