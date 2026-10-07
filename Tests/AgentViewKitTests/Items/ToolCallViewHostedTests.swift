#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Hosted tests of one ``ToolCallView`` over a `ToolCallEntry` of a
  /// scripted session. `ToolCallEntryViewHostedTests` tests the rows of the
  /// thread.
  @Suite(.serialized, .hostedSerially) @MainActor struct ToolCallViewHostedTests {
    /// The longest time that a test waits for the view to change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows the expanded body of a call.
    static let tallSize = CGSize(width: 520, height: 1_400)

    /// The label of the fixture call after it completes.
    static let completedLabel = "Read README.md, Completed"

    /// The id of the terminal of the terminal test.
    static let terminalID = "terminal-under-test"

    /// The fields of a running call that reads a file, with a raw input and
    /// one text content part.
    static let readFields = #"""
      "title": "Read README.md", "kind": "read", "status": "in_progress",
      "locations": [{"path": "/project/README.md"}],
      "rawInput": {"path": "/project/README.md"},
      "content": [{"type": "content", "content": {"type": "text", "text": "The file."}}]
      """#

    /// Opens a scripted session and sends one tool call.
    ///
    /// - Parameters:
    ///   - id: The `toolCallId` of the call.
    ///   - fields: The other fields of the `tool_call_update`, as JSON members.
    /// - Returns: The session and the entry of the call.
    /// - Throws: The error of the transport, or a missing entry.
    static func openCall(id: String, fields: String) async throws -> (ScriptedSession, ToolCallEntry) {
      let session = try await ScriptedSession.open()
      try await session.sendUpdate(WireBlockJSON.makeToolCallUpdate(id: id, fields: fields))
      _ = await waitUntil { ToolCallEntryViewHostedTests.toolCallEntry(id, in: session.model) != nil }
      return (session, try #require(ToolCallEntryViewHostedTests.toolCallEntry(id, in: session.model)))
    }

    /// Makes a store in which `call` is expanded.
    ///
    /// - Parameter call: The tool call entry.
    /// - Returns: The store.
    static func makeExpandedStore(for call: ToolCallEntry) -> ExpandedBlocksStore {
      let store = ExpandedBlocksStore()
      store.expand(entry: .toolCall(call))
      return store
    }

    /// Mounts the view of `call` with the store `store`.
    ///
    /// - Parameters:
    ///   - call: The tool call entry.
    ///   - store: The store of the expanded rows.
    /// - Returns: The harness.
    static func mount(_ call: ToolCallEntry, store: ExpandedBlocksStore) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: tallSize) {
        ToolCallView(entry: call)
          .environment(\.expandedBlocksStore, store)
          .transaction { $0.disablesAnimations = true }
      }
      harness.pump()
      return harness
    }

    // MARK: - Evaluation counts

    @Test func aStatusUpdateEvaluatesTheRowAndNotTheExpandedBody() async throws {
      let id = "patch-count-call"
      let (session, call) = try await Self.openCall(id: id, fields: Self.readFields)
      defer { session.close() }
      let key = call.id.rowKey
      let harness = Self.mount(call, store: Self.makeExpandedStore(for: call))
      defer { harness.close() }
      let rowKey = ToolCallView.rowCounterKey(for: key)
      let bodyKey = ToolCallView.bodyCounterKey(for: key)
      defer {
        BodyEvaluationCounter.reset(rowKey)
        BodyEvaluationCounter.reset(bodyKey)
      }
      #expect(harness.element(identifier: ToolCallView.bodyIdentifier(for: key)) != nil)
      #expect(BodyEvaluationCounter.count(bodyKey) >= 1)
      BodyEvaluationCounter.reset(rowKey)
      BodyEvaluationCounter.reset(bodyKey)

      try await session.sendUpdate(WireBlockJSON.makeToolCallUpdate(id: id, fields: #""status": "completed""#))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ToolCallView.identifier(for: key))?.label == Self.completedLabel
      }

      #expect(harness.element(identifier: ToolCallView.identifier(for: key))?.label == Self.completedLabel)
      #expect(BodyEvaluationCounter.count(rowKey) >= 1)
      #expect(BodyEvaluationCounter.count(bodyKey) == 0)
    }

    // MARK: - Expand

    @Test func aPressOnTheRowTogglesTheStore() async throws {
      let (session, call) = try await Self.openCall(id: "toggle-call", fields: Self.readFields)
      defer { session.close() }
      let key = call.id.rowKey
      let store = ExpandedBlocksStore()
      let harness = Self.mount(call, store: store)
      defer { harness.close() }
      let toggleID = ToolCallView.toggleIdentifier(for: key)
      let bodyID = ToolCallView.bodyIdentifier(for: key)
      #expect(!store.isExpanded(entry: .toolCall(call)))

      try harness.press(identifier: toggleID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: bodyID) != nil }

      #expect(store.isExpanded(entry: .toolCall(call)))
      #expect(harness.element(identifier: ToolCallView.locationsIdentifier(for: key)) != nil)
      #expect(harness.element(identifier: ToolCallView.inputIdentifier(for: key)) != nil)
      #expect(harness.element(identifier: ToolCallView.contentIdentifier(for: key, index: 0)) != nil)
      #expect(harness.element(identifier: ToolCallView.outputIdentifier(for: key)) == nil)

      try harness.press(identifier: toggleID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: bodyID) == nil }

      #expect(!store.isExpanded(entry: .toolCall(call)))
      #expect(harness.element(identifier: bodyID) == nil)
    }

    // MARK: - Content

    @Test func theTextOfAnExecuteCallShowsAsCommandOutput() async throws {
      let fields = #"""
        "title": "Build", "kind": "execute", "status": "completed",
        "rawInput": {"command": "swift build"}, "rawOutput": {"exitCode": 0},
        "content": [{"type": "content", "content": {"type": "text", "text": "Build complete!"}}]
        """#
      let (session, call) = try await Self.openCall(id: "execute-call", fields: fields)
      defer { session.close() }
      let harness = Self.mount(call, store: Self.makeExpandedStore(for: call))
      defer { harness.close() }

      #expect(harness.element(identifier: CommandOutputView.identifier) != nil)
      #expect(harness.element(identifier: CommandOutputView.footerIdentifier) != nil)
      #expect(harness.element(identifier: ToolCallView.outputIdentifier(for: call.id.rowKey)) != nil)
    }

    @Test func aTerminalPartShowsALabelWithTheTerminalID() async throws {
      let fields = #"""
        "title": "Build", "kind": "execute", "status": "in_progress",
        "content": [{"type": "terminal", "terminalId": "\#(Self.terminalID)"}]
        """#
      let (session, call) = try await Self.openCall(id: "terminal-call", fields: fields)
      defer { session.close() }
      let harness = Self.mount(call, store: Self.makeExpandedStore(for: call))
      defer { harness.close() }

      let labels = harness.accessibilityElements().compactMap(\.label)
      #expect(labels.contains { $0.contains(Self.terminalID) })
      #expect(harness.element(identifier: CommandOutputView.identifier) == nil)
    }

    @Test func anUnknownPartShowsTheUnknownView() async throws {
      let fields = #"""
        "title": "Edit", "kind": "edit", "status": "completed",
        "content": [{"type": "custom", "a": 1}]
        """#
      let (session, call) = try await Self.openCall(id: "unknown-part-call", fields: fields)
      defer { session.close() }
      let harness = Self.mount(call, store: Self.makeExpandedStore(for: call))
      defer { harness.close() }

      #expect(harness.element(identifier: ToolCallView.contentIdentifier(for: call.id.rowKey, index: 0)) != nil)
      #expect(harness.element(identifier: UnknownItemView.identifier) != nil)
    }

    // MARK: - Connection

    @Test func theConnectionChipShowsOnlyForACallThatWaitsForAServer() async throws {
      let fields = #""title": "Search", "kind": "search", "status": "pending""#
      let (session, waiting) = try await Self.openCall(id: "waiting-call", fields: fields)
      defer { session.close() }
      try await session.sendUpdate(WireBlockJSON.makeToolCallUpdate(id: "free-call", fields: fields))
      _ = await waitUntil { ToolCallEntryViewHostedTests.toolCallEntry("free-call", in: session.model) != nil }
      let free = try #require(ToolCallEntryViewHostedTests.toolCallEntry("free-call", in: session.model))
      let harness = HostedViewHarness {
        VStack {
          ToolCallView(entry: waiting)
          ToolCallView(entry: free)
        }
        .toolCallConnectionState { entry in
          entry.id == waiting.id ? .connecting : nil
        }
      }
      defer { harness.close() }
      harness.pump()

      let chips = harness.accessibilityElements().filter {
        $0.identifier == ConnectionStatusChip.identifier(for: .connecting)
      }
      #expect(chips.count == 1)
    }
  }
#endif
