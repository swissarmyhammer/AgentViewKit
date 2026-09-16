import AgentViewKit
import Foundation
import SwiftUI
import Testing

@MainActor struct PromptQueueTests {
  /// Makes a queue with one item for each text, in order.
  ///
  /// - Parameter texts: The texts of the items.
  /// - Returns: The queue.
  static func queue(_ texts: String...) -> PromptQueue {
    let queue = PromptQueue()
    for text in texts {
      queue.enqueue(UserInput(text: text))
    }
    return queue
  }

  /// The texts of the items of `queue`, in order.
  ///
  /// - Parameter queue: The queue to read.
  /// - Returns: The texts.
  static func texts(of queue: PromptQueue) -> [String] {
    queue.items.map(\.input.text)
  }

  // MARK: - Order

  @Test func aNewQueueIsEmpty() {
    let queue = PromptQueue()

    #expect(queue.isEmpty)
    #expect(queue.count == 0)
  }

  @Test func enqueueKeepsTheOrderAndGivesUniqueIdentifiers() {
    let queue = PromptQueue()
    let first = queue.enqueue(UserInput(text: "a"))
    let second = queue.enqueue(UserInput(text: "b"))

    #expect(Self.texts(of: queue) == ["a", "b"])
    #expect(queue.items.map(\.id) == [first, second])
    #expect(first != second)
    #expect(queue.count == 2)
  }

  @Test func removeDropsOnlyTheItemWithTheIdentifier() {
    let queue = Self.queue("a", "b", "c")

    queue.remove(queue.items[1].id)

    #expect(Self.texts(of: queue) == ["a", "c"])
  }

  @Test func removeWithAnUnknownIdentifierChangesNothing() {
    let queue = Self.queue("a")

    queue.remove(QueuedPromptID("missing"))

    #expect(Self.texts(of: queue) == ["a"])
  }

  @Test func updateChangesTheTextAndKeepsThePosition() {
    let queue = Self.queue("a", "b")
    let id = queue.items[0].id

    queue.update(id, text: "edited")

    #expect(Self.texts(of: queue) == ["edited", "b"])
    #expect(queue.items[0].id == id)
  }

  @Test func updateKeepsTheAttachments() {
    let queue = PromptQueue()
    let file = URL(filePath: "/tmp/a.txt")
    let id = queue.enqueue(UserInput(text: "a", attachments: [file]))

    queue.update(id, text: "b")

    #expect(queue.items[0].input == UserInput(text: "b", attachments: [file]))
  }

  @Test func moveFromOffsetsToAnOffsetUsesTheArrayRule() {
    let queue = Self.queue("a", "b", "c")

    queue.move(from: IndexSet(integer: 0), to: 3)

    #expect(Self.texts(of: queue) == ["b", "c", "a"])
  }

  @Test func moveIdentifiersBeforeAnItem() {
    let queue = Self.queue("a", "b", "c")
    let ids = queue.items.map(\.id)

    queue.move([ids[2]], to: .before(ids[0]))

    #expect(Self.texts(of: queue) == ["c", "a", "b"])
  }

  @Test func moveIdentifiersToTheEnd() {
    let queue = Self.queue("a", "b", "c")
    let ids = queue.items.map(\.id)

    queue.move([ids[0], ids[1]], to: .end)

    #expect(Self.texts(of: queue) == ["c", "a", "b"])
  }

  @Test func moveWithUnknownIdentifiersChangesNothing() {
    let queue = Self.queue("a", "b")

    queue.move([QueuedPromptID("missing")], to: .end)

    #expect(Self.texts(of: queue) == ["a", "b"])
  }

  // MARK: - Dequeue

  @Test func dequeueNextRemovesAndReturnsTheFirstItem() {
    let queue = Self.queue("a", "b")

    #expect(queue.dequeueNext() == UserInput(text: "a"))
    #expect(Self.texts(of: queue) == ["b"])
    #expect(queue.dequeueNext() == UserInput(text: "b"))
    #expect(queue.dequeueNext() == nil)
  }

  @Test func takeRemovesAndReturnsTheItemWithTheIdentifier() {
    let queue = Self.queue("a", "b", "c")

    #expect(queue.take(queue.items[1].id) == UserInput(text: "b"))
    #expect(Self.texts(of: queue) == ["a", "c"])
    #expect(queue.take(QueuedPromptID("missing")) == nil)
    #expect(Self.texts(of: queue) == ["a", "c"])
  }

  @Test func dequeueNextSkipsAndRemovesItemsThatAnEditMadeBlank() {
    let queue = Self.queue("a", "b")
    queue.update(queue.items[0].id, text: "  ")

    #expect(queue.dequeueNext() == UserInput(text: "b"))
    #expect(queue.isEmpty)
  }

  @Test func takeRemovesABlankItemAndReturnsNil() {
    let queue = Self.queue("a")
    let id = queue.items[0].id
    queue.update(id, text: "")

    #expect(queue.take(id) == nil)
    #expect(queue.isEmpty)
  }

  @Test func anIdleStateDequeuesTheFirstItem() {
    let queue = Self.queue("a", "b")

    #expect(queue.dequeueNext(after: .idle(.endTurn)) == UserInput(text: "a"))
    #expect(queue.dequeueNext(after: .idle(nil)) == UserInput(text: "b"))
    #expect(queue.isEmpty)
  }

  @Test(arguments: [ThreadState.running, .requiresAction, .idle(.cancelled)])
  func aStateThatIsNotAFinishedTurnKeepsTheQueue(state: ThreadState) {
    let queue = Self.queue("a")

    #expect(queue.dequeueNext(after: state) == nil)
    #expect(Self.texts(of: queue) == ["a"])
  }
}
