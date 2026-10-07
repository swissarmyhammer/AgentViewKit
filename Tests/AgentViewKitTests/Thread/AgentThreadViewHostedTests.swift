#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import SwiftUI
  import Testing

  @Suite(.serialized, .hostedSerially) @MainActor struct AgentThreadViewHostedTests {
    /// The number of items in the thread of the patch test.
    static let patchItemCount = 10

    /// The position of the item that the patch test changes.
    static let patchedPosition = 3

    /// A size that shows each row of the patch thread.
    static let tallSize = CGSize(width: 480, height: 1_600)

    /// Makes a thread of user messages. The id of each item is `prefix` and
    /// its position.
    ///
    /// - Parameters:
    ///   - prefix: The start of each item id.
    ///   - count: The number of items.
    /// - Returns: The thread.
    static func messageThread(prefix: String, count: Int) -> AgentThread {
      let thread = AgentThread()
      for position in 0..<count {
        let message = ThreadFixtures.message(id: "\(prefix)\(position)", text: "Message \(position).")
        thread.apply(.insert(.userMessage(message), after: nil))
      }
      return thread
    }

    @Test func eachItemMountsARowWithItsIdentifier() {
      let thread = Self.messageThread(prefix: "mount-item-", count: 3)
      let harness = HostedViewHarness(
        AgentThreadView(thread: thread, actions: NoopThreadActions()))
      defer { harness.close() }
      harness.pump()

      for item in thread.items {
        #expect(harness.element(identifier: ItemRow.identifier(for: item.id)) != nil)
      }
    }

    @Test func aPatchToOneRecordEvaluatesOnlyItsRow() {
      let prefix = "patch-count-item-"
      let thread = Self.messageThread(prefix: prefix, count: Self.patchItemCount)
      let harness = HostedViewHarness(
        AgentThreadView(thread: thread, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }
      harness.pump()
      let counterPrefix = ItemRow.counterKey(for: prefix)
      for item in thread.items {
        #expect(BodyEvaluationCounter.count(ItemRow.counterKey(for: item.id)) >= 1)
      }
      BodyEvaluationCounter.reset(prefix: counterPrefix)

      let patchedID = "\(prefix)\(Self.patchedPosition)"
      thread.apply(.patch(id: patchedID, .userMessageChunk(ContentBlock(text: " More."))))
      harness.pump()

      for item in thread.items {
        let expected = item.id == patchedID ? 1 : 0
        #expect(BodyEvaluationCounter.count(ItemRow.counterKey(for: item.id)) == expected)
      }
      BodyEvaluationCounter.reset(prefix: counterPrefix)
    }
  }
#endif
