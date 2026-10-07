import AgentViewKitTestSupport
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

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

  @Test func toggleFlipsOnlyTheGivenEntry() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = ExpandedBlocksStore()

    store.toggle(entry: entries.toolCall)
    #expect(store.isExpanded(entry: entries.toolCall))
    #expect(!store.isExpanded(entry: entries.thought))

    store.toggle(entry: entries.toolCall)
    #expect(!store.isExpanded(entry: entries.toolCall))
    #expect(!store.isExpanded(entry: entries.thought))
  }

  @Test func expandAndCollapseSetTheGivenEntryOnly() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = ExpandedBlocksStore()
    store.expand(entry: entries.thought)

    store.expand(entry: entries.toolCall)
    store.expand(entry: entries.toolCall)
    #expect(store.isExpanded(entry: entries.toolCall))

    store.collapse(entry: entries.toolCall)
    store.collapse(entry: entries.toolCall)
    #expect(!store.isExpanded(entry: entries.toolCall))
    #expect(store.isExpanded(entry: entries.thought))
  }

  @Test func aToggleInvalidatesOnlyTheReadersOfThatEntry() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = ExpandedBlocksStore()
    let readerOfToolCall = ChangeFlag.observing { _ = store.isExpanded(entry: entries.toolCall) }
    let readerOfThought = ChangeFlag.observing { _ = store.isExpanded(entry: entries.thought) }

    store.toggle(entry: entries.toolCall)

    #expect(readerOfToolCall.value)
    #expect(!readerOfThought.value)
  }

  @Test func toggleWithNoSeedFlipsThePolicyValue() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()

    store.toggle(entry: entries.toolCall)
    store.toggle(entry: entries.thought)

    #expect(!store.isExpanded(entry: entries.toolCall))
    #expect(store.isExpanded(entry: entries.thought))
  }

  // MARK: - Row identifier

  // A row with no transcript entry, such as a thread item of the old thread
  // path or an unknown content block, uses the internal identifier form.

  @Test func anUnknownIdIsCollapsed() {
    let store = ExpandedBlocksStore()

    #expect(!store.isExpanded(id: "never-seen"))
    #expect(store.decision(for: "never-seen") == nil)
  }

  @Test func expandAndCollapseSetTheGivenIdOnly() {
    let store = ExpandedBlocksStore()
    store.expand(id: "b")

    store.expand(id: "a")
    #expect(store.isExpanded(id: "a"))

    store.collapse(id: "a")
    #expect(!store.isExpanded(id: "a"))
    #expect(store.isExpanded(id: "b"))
  }

  // MARK: - Default policy

  @Test func theDefaultPolicyExpandsNoEntry() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = ExpandedBlocksStore()

    #expect(!store.isExpanded(entry: entries.toolCall))
    #expect(!store.isExpanded(entry: entries.thought))
  }

  @Test func thePolicyDecidesAnEntryWithNoDecision() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()

    #expect(store.isExpanded(entry: entries.toolCall))
    #expect(!store.isExpanded(entry: entries.thought))
  }

  @Test func aDecisionWinsOverThePolicy() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()

    store.collapse(entry: entries.toolCall)
    store.expand(entry: entries.thought)

    #expect(!store.isExpanded(entry: entries.toolCall))
    #expect(store.isExpanded(entry: entries.thought))
  }

  @Test func aDecisionEqualToTheCollapsedValueInvalidatesAPolicyReader() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()
    let reader = ChangeFlag.observing { _ = store.isExpanded(entry: entries.toolCall) }

    store.collapse(entry: entries.toolCall)

    #expect(reader.value)
    #expect(!store.isExpanded(entry: entries.toolCall))
  }

  @Test func seedRecordsThePolicyValueAsTheDecisionOfTheEntry() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()
    #expect(store.decision(for: entries.toolCall) == nil)
    #expect(store.decision(for: entries.thought) == nil)

    store.seed(entry: entries.toolCall)
    store.seed(entry: entries.thought)

    #expect(store.decision(for: entries.toolCall) == true)
    #expect(store.decision(for: entries.thought) == false)
  }

  @Test func seedDoesNotReplaceADecision() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()
    store.collapse(entry: entries.toolCall)

    store.seed(entry: entries.toolCall)

    #expect(!store.isExpanded(entry: entries.toolCall))
  }

  @Test func toggleAfterSeedFlipsThePolicyValue() async throws {
    let entries = try await Self.openPolicyEntries()
    defer { entries.session.close() }
    let store = Self.makeStoreThatExpandsToolCalls()
    store.seed(entry: entries.toolCall)

    store.toggle(entry: entries.toolCall)

    #expect(!store.isExpanded(entry: entries.toolCall))
  }
}
