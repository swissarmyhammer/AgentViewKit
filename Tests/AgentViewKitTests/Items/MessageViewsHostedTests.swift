import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import PackageFileSupport
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct MessageViewsHostedTests {
  /// The longest time that a test waits for the view to change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// A size that shows each block of the entry tests.
  static let tallSize = CGSize(width: 480, height: 1_200)

  /// The accessibility identifier of the custom footer.
  static let footerIdentifier = "custom-footer"

  /// The `messageId` of the agent message of the entry tests.
  static let entryMessageID = "blocks-m"

  /// The first text chunk of the agent message of the entry tests.
  static let firstChunk = "First chunk."

  /// The second text chunk of the agent message of the entry tests.
  static let secondChunk = " Second chunk."

  /// The name of the resource link of the entry tests.
  static let linkName = "Guide"

  /// The URI of the resource link of the entry tests.
  static let linkURI = "https://example.com/docs/guide.html"

  /// The MIME type of the image of the entry tests.
  static let imageMimeType = "image/png"

  /// The kit sources of the entry views. They show the ACP content of a
  /// transcript entry with no copy into a kit record.
  static let entryViewSources = [
    "Sources/AgentViewKit/Items/TranscriptMessageView.swift",
    "Sources/AgentViewKit/Items/ThoughtEntryBlock.swift",
    "Sources/AgentViewKit/Items/CompactionEntryView.swift",
    "Sources/AgentViewKit/Content/EntryContentView.swift",
  ]

  /// An `agent_message_chunk` value of the agent message of the entry tests.
  ///
  /// - Parameter block: The JSON text of the content block.
  /// - Returns: The JSON text of the update.
  static func makeAgentChunk(_ block: String) -> String {
    WireBlockJSON.makeChunk("agent_message_chunk", messageID: entryMessageID, block: block)
  }

  /// The accessibility identifiers of the content block views in `harness`,
  /// in view order.
  ///
  /// - Parameter harness: The harness that shows the thread.
  /// - Returns: Each identifier with the content block prefix.
  static func blockIdentifiers<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
    harness.accessibilityElements()
      .compactMap(\.identifier)
      .filter { $0.hasPrefix(ContentBlockView.identifierPrefix) }
  }

  /// Tells whether an element of `harness` has a label that holds `text`.
  ///
  /// - Parameters:
  ///   - text: The text to find.
  ///   - harness: The harness that shows the thread.
  /// - Returns: `true` when a label holds `text`.
  static func showsLabel<Content: View>(containing text: String, in harness: HostedViewHarness<Content>) -> Bool {
    harness.accessibilityElements().contains { $0.label?.contains(text) == true }
  }

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

  @Test func aUserMessageMountsWithItsIdentifierAndLabel() {
    let message = ThreadFixtures.message(id: "user-mount", text: "Hello.")
    let harness = HostedViewHarness(
      AgentThreadView(
        thread: Self.thread(with: .userMessage(message)), actions: NoopThreadActions()))
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
      AgentThreadView(
        thread: Self.thread(with: .assistantMessage(message)), actions: NoopThreadActions()))
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

  // MARK: - Blocks

  @Test func aMessageWithTwoBlocksMountsTwoBlockViewsInOrder() {
    let message = Self.twoBlockMessage(id: "two-blocks")
    let harness = HostedViewHarness(
      AgentThreadView(
        thread: Self.thread(with: .assistantMessage(message)), actions: NoopThreadActions()))
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
    let harness = HostedViewHarness(AgentThreadView(thread: thread, actions: NoopThreadActions()))
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

  // MARK: - Entries

  @Test func anAgentMessageEntryShowsEachBlockAndASecondChunkChangesTheText() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(
      AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
    defer { harness.close() }
    let image = WireBlockJSON.makeImage(data: try ContentBlockViewHostedTests.pngData(), mimeType: Self.imageMimeType)
    let expectedBlocks = [
      ContentBlockView.identifier(for: .image), ContentBlockView.identifier(for: .resourceLink),
      ContentBlockView.identifier(for: .text),
    ]

    try await session.sendUpdate(Self.makeAgentChunk(image))
    try await session.sendUpdate(Self.makeAgentChunk(WireBlockJSON.makeResourceLink(name: Self.linkName, uri: Self.linkURI)))
    try await session.sendUpdate(Self.makeAgentChunk(WireBlockJSON.makeText(Self.firstChunk)))
    await harness.pump(until: Self.waitTimeout) {
      Self.blockIdentifiers(in: harness) == expectedBlocks && Self.showsLabel(containing: Self.firstChunk, in: harness)
    }

    #expect(Self.blockIdentifiers(in: harness) == expectedBlocks)
    #expect(harness.element(identifier: ImageView.imageIdentifier) != nil)
    #expect(harness.element(identifier: LinkView.cardIdentifier)?.label == Self.linkName)
    #expect(Self.showsLabel(containing: Self.firstChunk, in: harness))

    try await session.sendUpdate(Self.makeAgentChunk(WireBlockJSON.makeText(Self.secondChunk)))
    let joined = Self.firstChunk + Self.secondChunk
    await harness.pump(until: Self.waitTimeout) { Self.showsLabel(containing: joined, in: harness) }

    #expect(Self.showsLabel(containing: joined, in: harness))
    #expect(Self.blockIdentifiers(in: harness) == expectedBlocks)
  }

  @Test func theEntryViewsMakeNoKitCopyOfTheEntryContent() throws {
    let files = try Self.entryViewSources.map { try PackageFiles.file($0) }
    let copy = try Regex(#"SessionUpdateMapping|\bMessage\(|\bReasoning\(|AgentViewKit\.ContentBlock"#)

    let copies = try SourceLines.matching(copy, in: files)

    #expect(copies.isEmpty, "An entry view copies the entry content into a kit record: \(copies)")
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
