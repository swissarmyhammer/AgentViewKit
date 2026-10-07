import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACPClient
import Testing

@Suite @MainActor struct ExpandedBlocksStoreTests {
  /// The number of entries of ``openPolicyEntries()``.
  private static let policyEntryCount = 2

  /// A tool call entry and a thought entry of a scripted session. The policy
  /// in these tests expands the tool call entry, and not the thought entry.
  private struct PolicyEntries {
    /// The scripted session that holds the entries.
    let session: ScriptedSession

    /// The tool call entry.
    let toolCall: TranscriptEntry

    /// The thought entry.
    let thought: TranscriptEntry
  }

  /// Opens a scripted session, and sends a tool call and a thought from the
  /// agent.
  ///
  /// - Returns: The session and its two entries.
  /// - Throws: The error of the transport, or an issue when the transcript
  ///   does not hold the two entries at the time limit.
  private static func openPolicyEntries() async throws -> PolicyEntries {
    let session = try await ScriptedSession.open()
    try await session.sendUpdate(WireBlockJSON.makeToolCallUpdate(id: "tool-1", fields: #""title": "Read file""#))
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_thought_chunk", messageID: "thought-1", block: WireBlockJSON.makeText("Think")))
    let model = session.model
    _ = await waitUntil { model.transcript.count == policyEntryCount }
    let toolCall = try #require(model.transcript.first { if case .toolCall = $0 { true } else { false } })
    let thought = try #require(model.transcript.first { if case .thought = $0 { true } else { false } })
    return PolicyEntries(session: session, toolCall: toolCall, thought: thought)
  }

  /// Makes a store whose policy expands each tool call entry and no other
  /// entry.
  private static func makeStoreThatExpandsToolCalls() -> ExpandedBlocksStore {
    ExpandedBlocksStore { entry in
      if case .toolCall = entry { true } else { false }
    }
  }

  // MARK: - Toggle

  @Test func toggleFlipsOnlyTheGivenId() {
    let store = ExpandedBlocksStore()

    store.toggle("a")
    #expect(store.isExpanded("a"))
    #expect(!store.isExpanded("b"))

    store.toggle("a")
    #expect(!store.isExpanded("a"))
    #expect(!store.isExpanded("b"))
  }

  @Test func expandAndCollapseSetTheGivenIdOnly() {
    let store = ExpandedBlocksStore()
    store.expand("b")

    store.expand("a")
    store.expand("a")
    #expect(store.isExpanded("a"))

    store.collapse("a")
    store.collapse("a")
    #expect(!store.isExpanded("a"))
    #expect(store.isExpanded("b"))
  }

  @Test func anUnknownIdIsCollapsed() {
    let store = ExpandedBlocksStore()

    #expect(!store.isExpanded("never-seen"))
  }

  @Test func aToggleInvalidatesOnlyTheReadersOfThatId() {
    let store = ExpandedBlocksStore()
    let readerOfA = ChangeFlag.observing { _ = store.isExpanded("a") }
    let readerOfB = ChangeFlag.observing { _ = store.isExpanded("b") }

    store.toggle("a")

    #expect(readerOfA.value)
    #expect(!readerOfB.value)
  }

  // MARK: - Default policy

  @Test func theDefaultPolicyExpandsNoEntry() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = ExpandedBlocksStore()

    #expect(!store.isExpanded(entries.toolCall))
    #expect(!store.isExpanded(entries.thought))
  }

  @Test func thePolicyDecidesAnEntryWithNoDecision() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()

    #expect(store.isExpanded(entries.toolCall))
    #expect(!store.isExpanded(entries.thought))
  }

  @Test func aDecisionWinsOverThePolicy() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()

    store.collapse(entries.toolCall.rowKey)
    store.expand(entries.thought.rowKey)

    #expect(!store.isExpanded(entries.toolCall))
    #expect(store.isExpanded(entries.thought))
  }

  @Test func aDecisionEqualToTheCollapsedValueInvalidatesAPolicyReader() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()
    let reader = ChangeFlag.observing { _ = store.isExpanded(entries.toolCall) }

    store.collapse(entries.toolCall.rowKey)

    #expect(reader.value)
    #expect(!store.isExpanded(entries.toolCall))
  }

  @Test func seedRecordsThePolicyValueForTheRowKey() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()

    store.seed(entries.toolCall)
    store.seed(entries.thought)

    #expect(store.isExpanded(entries.toolCall.rowKey))
    #expect(!store.isExpanded(entries.thought.rowKey))
  }

  @Test func seedDoesNotReplaceADecision() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()
    store.collapse(entries.toolCall.rowKey)

    store.seed(entries.toolCall)

    #expect(!store.isExpanded(entries.toolCall.rowKey))
  }

  @Test func toggleAfterSeedFlipsThePolicyValue() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()
    store.seed(entries.toolCall)

    store.toggle(entries.toolCall.rowKey)

    #expect(!store.isExpanded(entries.toolCall))
  }
}
