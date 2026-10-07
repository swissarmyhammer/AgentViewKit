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

  /// Sends one text chunk of `kind` to a scripted session, and expects that
  /// the thread view of the session shows the message entry with `label`.
  ///
  /// - Parameters:
  ///   - kind: The `sessionUpdate` tag of the chunk, such as
  ///     `user_message_chunk`.
  ///   - identifier: Makes the accessibility identifier of the message view
  ///     from the row key of the entry.
  ///   - label: The accessibility label that the message view must have.
  static func expectMessageEntryMounts(
    kind: String, identifier: @MainActor (String) -> String, label: String
  ) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(
      AgentThreadView(session: session.model, connection: session.connection),
      size: tallSize)
    defer { harness.close() }

    try await session.sendUpdate(
      WireBlockJSON.makeChunk(kind, messageID: entryMessageID, block: WireBlockJSON.makeText(firstChunk)))
    await harness.pump(until: waitTimeout) { !session.model.transcript.isEmpty }
    let key = try #require(session.model.transcript.first?.rowKey)
    await harness.pump(until: waitTimeout) { harness.element(identifier: identifier(key)) != nil }

    #expect(harness.element(identifier: identifier(key))?.label == label)
    #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: key)) == nil)
  }

  // MARK: - Mount

  @Test func aUserMessageEntryMountsWithItsIdentifierAndLabel() async throws {
    #expect(UserMessageView.identifier(for: "user-mount") == "user-message-user-mount")
    try await Self.expectMessageEntryMounts(
      kind: "user_message_chunk", identifier: { UserMessageView.identifier(for: $0) }, label: "You said")
  }

  @Test func anAgentMessageEntryMountsWithItsIdentifierAndLabel() async throws {
    #expect(AssistantMessageView.identifier(for: "assistant-mount") == "assistant-message-assistant-mount")
    try await Self.expectMessageEntryMounts(
      kind: "agent_message_chunk", identifier: { AssistantMessageView.identifier(for: $0) }, label: "Assistant said")
  }

  @Test func theHeaderShowsTheRoleAndTheRelativeTime() {
    let date = Date(timeIntervalSinceNow: -120)
    let harness = HostedViewHarness(MessageHeader(role: .assistant, date: date))
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

  // MARK: - Entries

  @Test func anAgentMessageEntryShowsEachBlockAndASecondChunkChangesTheText() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(
      AgentThreadView(session: session.model), size: Self.tallSize)
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
    let copy = try Regex(#"\bMessage\(|\bReasoning\(|AgentViewKit\.ContentBlock"#)

    let copies = try SourceLines.matching(copy, in: files)

    #expect(copies.isEmpty, "An entry view copies the entry content into a kit record: \(copies)")
  }

  // MARK: - Footer

  @Test func theFooterSlotIsEmptyByDefaultAndShowsTheHostFooterOfAnEntry() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    try await session.sendUpdate(Self.makeAgentChunk(WireBlockJSON.makeText(Self.firstChunk)))
    _ = await waitUntil { !model.transcript.isEmpty }
    let key = try #require(model.transcript.first?.rowKey)
    let message = AssistantMessageView.identifier(for: key)
    let plain = HostedViewHarness(AgentThreadView(session: model), size: Self.tallSize)
    await plain.pump(until: Self.waitTimeout) { plain.element(identifier: message) != nil }
    #expect(plain.element(identifier: message) != nil)
    #expect(plain.element(identifier: Self.footerIdentifier) == nil)
    plain.close()

    let harness = HostedViewHarness(size: Self.tallSize) {
      AgentThreadView(session: model)
        .messageFooter { entry in
          Text("Footer \(entry.id.rowKey)")
            .accessibilityIdentifier(Self.footerIdentifier)
        }
    }
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: Self.footerIdentifier) != nil }

    #expect(harness.element(identifier: Self.footerIdentifier)?.label == "Footer \(key)")
  }
}
