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

    /// The accessibility identifier of the custom tool call view.
    static let customToolCallIdentifier = "custom-tool-call"

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
      let harness = HostedViewHarness(AgentThreadView(thread: thread))
      defer { harness.close() }
      harness.pump()

      for item in thread.items {
        #expect(harness.element(identifier: ItemRow.identifier(for: item.id)) != nil)
      }
    }

    @Test func theToolCallOverrideReplacesOnlyTheToolCallView() {
      let thread = AgentThread()
      thread.apply(
        .insert(.toolCall(ThreadFixtures.toolCall(id: "override-call", status: .completed)), after: nil))
      thread.apply(
        .insert(.assistantMessage(ThreadFixtures.message(id: "override-message")), after: nil))
      let view = AgentThreadView(thread: thread)
        .toolCallView { call in
          Text("Custom \(call.title)")
            .accessibilityIdentifier(Self.customToolCallIdentifier)
        }
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      let custom = harness.accessibilityElements().filter {
        $0.identifier == Self.customToolCallIdentifier
      }
      #expect(custom.count == 1)
      #expect(custom.first?.label == "Custom Read README.md")
      #expect(harness.element(identifier: ItemRow.identifier(for: "override-message")) != nil)
      #expect(
        harness.element(identifier: ItemRow.placeholderIdentifier(for: "override-message")) != nil)
      #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: "override-call")) == nil)
    }

    @Test func aPatchToOneRecordEvaluatesOnlyItsRow() {
      let prefix = "patch-count-item-"
      let thread = Self.messageThread(prefix: prefix, count: Self.patchItemCount)
      let harness = HostedViewHarness(AgentThreadView(thread: thread), size: Self.tallSize)
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
