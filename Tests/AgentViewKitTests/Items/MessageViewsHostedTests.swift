import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct MessageViewsHostedTests {
  /// The longest time that a test waits for the view to change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The text of the system prompt.
  static let instructions = "Answer in one line."

  /// The accessibility identifier of the custom footer.
  static let footerIdentifier = "custom-footer"

  /// Makes a thread with one item.
  ///
  /// - Parameter item: The item.
  /// - Returns: The thread.
  static func thread(with item: ThreadItem) -> AgentThread {
    let thread = AgentThread()
    thread.apply(.insert(item, after: nil))
    return thread
  }

  /// Makes a message with a text block and then an unknown block.
  ///
  /// - Parameter id: The identifier of the message.
  /// - Returns: The message.
  static func twoBlockMessage(id: String) -> Message {
    Message(
      id: id,
      blocks: [
        ContentBlock(text: "First block."),
        ContentBlock(content: .unknown(kind: "future_block", raw: .object([:]))),
      ])
  }

  // MARK: - Mount

  @Test func theSystemPromptMountsWithItsIdentifierAndLabel() {
    let record = SystemPrompt(id: "system-mount", text: Self.instructions)
    let harness = HostedViewHarness(AgentThreadView(thread: Self.thread(with: .system(record))))
    defer { harness.close() }
    harness.pump()

    #expect(SystemPromptView.identifier == "system-prompt")
    #expect(harness.element(identifier: SystemPromptView.identifier)?.label == "Instructions")
    #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: record.id)) == nil)
  }

  @Test func aUserMessageMountsWithItsIdentifierAndLabel() {
    let message = ThreadFixtures.message(id: "user-mount", text: "Hello.")
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: .userMessage(message))))
    defer { harness.close() }
    harness.pump()

    let identifier = UserMessageView.identifier(for: message.id)
    #expect(identifier == "user-message-user-mount")
    #expect(harness.element(identifier: identifier)?.label == "You said")
    #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: message.id)) == nil)
  }

  @Test func anAssistantMessageMountsWithItsIdentifierAndLabel() {
    let message = ThreadFixtures.message(id: "assistant-mount", text: "Hi.")
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: .assistantMessage(message))))
    defer { harness.close() }
    harness.pump()

    let identifier = AssistantMessageView.identifier(for: message.id)
    #expect(identifier == "assistant-message-assistant-mount")
    #expect(harness.element(identifier: identifier)?.label == "Assistant said")
    #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: message.id)) == nil)
  }

  @Test func theHeaderShowsTheRoleAndTheRelativeTime() {
    let date = Date(timeIntervalSinceNow: -120)
    let message = ThreadFixtures.message(id: "header-date", text: "Hi.")
    let harness = HostedViewHarness(AssistantMessageView(message: message, date: date))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: MessageHeader.roleIdentifier)?.label == "Assistant")
    let dateLabel = harness.element(identifier: MessageHeader.dateIdentifier)?.label
    #expect(dateLabel == MessageHeader.relativeText(for: date))
  }

  @Test func theHeaderHasNoTimeWithNoDate() {
    let harness = HostedViewHarness(MessageHeader(role: .user))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: MessageHeader.roleIdentifier)?.label == "You")
    #expect(harness.element(identifier: MessageHeader.dateIdentifier) == nil)
  }

  @Test func theRelativeTextIsRelativeToNow() {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let earlier = now.addingTimeInterval(-3_600)
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    #expect(
      MessageHeader.relativeText(for: earlier, now: now)
        == formatter.localizedString(for: earlier, relativeTo: now))
  }

  // MARK: - Disclosure

  @Test func theSystemPromptIsCollapsedAndAPressExpandsIt() async throws {
    let record = SystemPrompt(id: "system-toggle", text: Self.instructions)
    let harness = HostedViewHarness(AgentThreadView(thread: Self.thread(with: .system(record))))
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: SystemPromptView.toggleIdentifier) != nil
    }

    #expect(harness.element(identifier: SystemPromptView.bodyIdentifier) == nil)
    #expect(!harness.accessibilityElements().contains { $0.label == Self.instructions })

    try harness.press(identifier: SystemPromptView.toggleIdentifier)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: SystemPromptView.bodyIdentifier) != nil
    }

    #expect(harness.element(identifier: SystemPromptView.bodyIdentifier) != nil)
    #expect(harness.accessibilityElements().contains { $0.label == Self.instructions })

    try harness.press(identifier: SystemPromptView.toggleIdentifier)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: SystemPromptView.bodyIdentifier) == nil
    }
    #expect(harness.element(identifier: SystemPromptView.bodyIdentifier) == nil)
  }

  @Test func theStoreOfTheEnvironmentKeepsTheSystemPromptExpanded() {
    let record = SystemPrompt(id: "system-store", text: Self.instructions)
    let store = ExpandedBlocksStore()
    store.expand(record.id)
    let harness = HostedViewHarness(
      SystemPromptView(record: record).environment(\.expandedBlocksStore, store))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: SystemPromptView.bodyIdentifier) != nil)
  }

  // MARK: - Blocks

  @Test func aMessageWithTwoBlocksMountsTwoBlockViewsInOrder() {
    let message = Self.twoBlockMessage(id: "two-blocks")
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: .assistantMessage(message))))
    defer { harness.close() }
    harness.pump()

    let blockIdentifiers = harness.accessibilityElements()
      .compactMap(\.identifier)
      .filter { $0.hasPrefix(ContentBlockView.identifierPrefix) }
    #expect(
      blockIdentifiers == [
        ContentBlockView.identifier(for: .text), ContentBlockView.identifier(for: .unknown),
      ])
  }

  @Test func aStreamingMessageShowsTheStreamAndTheOtherBlocks() async {
    let message = Self.twoBlockMessage(id: "streaming-blocks")
    let thread = Self.thread(with: .userMessage(message))
    thread.apply(.appendStreaming(id: message.id, text: "Streamed text"))
    let harness = HostedViewHarness(AgentThreadView(thread: thread))
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: ResponseView.tailIdentifier) != nil
    }

    let blockIdentifiers = harness.accessibilityElements()
      .compactMap(\.identifier)
      .filter { $0.hasPrefix(ContentBlockView.identifierPrefix) }
    #expect(harness.element(identifier: ResponseView.tailIdentifier) != nil)
    #expect(blockIdentifiers == [ContentBlockView.identifier(for: .unknown)])
  }

  // MARK: - Footer

  @Test func theFooterSlotIsEmptyByDefaultAndShowsTheHostFooter() {
    let message = ThreadFixtures.message(id: "footer-message", text: "Hi.")
    let plain = HostedViewHarness(UserMessageView(message: message))
    plain.pump()
    #expect(plain.element(identifier: Self.footerIdentifier) == nil)
    plain.close()

    let view = UserMessageView(message: message)
      .messageFooter { message in
        Text("Footer \(message.id)")
          .accessibilityIdentifier(Self.footerIdentifier)
      }
    let harness = HostedViewHarness(view)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: Self.footerIdentifier)?.label == "Footer footer-message")
  }
}
