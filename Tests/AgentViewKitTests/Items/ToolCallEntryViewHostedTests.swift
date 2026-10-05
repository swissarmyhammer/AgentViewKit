#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The tool call view over a `ToolCallEntry` of a `SessionModel`
  /// (update.md §4.7 "Tool call view", §5 `ToolCallUpdate.name`, §9.4).
  @Suite(.serialized, .hostedSerially) @MainActor struct ToolCallEntryViewHostedTests {
    /// The longest time that a test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows the expanded body of a call.
    static let tallSize = CGSize(width: 520, height: 1_400)

    /// The program name of the tool that the registry test registers.
    static let readFileName = "read_file"

    /// The accessibility identifier of the registered test view.
    static let registeredIdentifier = "registered-read-file"

    /// The label of the fixture call while it runs.
    static let runningLabel = "Read README.md, In progress"

    /// The label of the fixture call after it completes.
    static let completedLabel = "Read README.md, Completed"

    /// The path of the file that the structured diff adds.
    static let addedPath = "/project/new.swift"

    /// The JSON-RPC id of the elicitation request of the agent.
    static let elicitationRequestID = 41

    /// The fields of a running call that reads a file, with no name.
    static let readFields = #"""
      "title": "Read README.md", "kind": "read", "status": "in_progress",
      "locations": [{"path": "/project/README.md"}]
      """#

    /// A `tool_call_update` value for the call of `id`.
    ///
    /// - Parameters:
    ///   - id: The `toolCallId` of the call.
    ///   - fields: The other fields of the update, as JSON members.
    /// - Returns: The JSON text of the update.
    static func toolCallUpdate(id: String, fields: String) -> String {
      #"{"sessionUpdate": "tool_call_update", "toolCallId": "\#(id)", \#(fields)}"#
    }

    /// The row key of the tool call entry of `id`.
    ///
    /// - Parameters:
    ///   - id: The `toolCallId` of the call.
    ///   - model: The session model.
    /// - Returns: The row key, or `nil` while the model has no such entry.
    static func rowKey(ofCall id: String, in model: SessionModel) -> String? {
      toolCallEntry(id, in: model)?.id.rowKey
    }

    /// The tool call entry of `id`.
    ///
    /// - Parameters:
    ///   - id: The `toolCallId` of the call.
    ///   - model: The session model.
    /// - Returns: The entry, or `nil` while the model has no such entry.
    static func toolCallEntry(_ id: String, in model: SessionModel) -> ToolCallEntry? {
      let identity = TranscriptEntry.ID.wire(.toolCall(ToolCallId(rawValue: id)))
      for entry in model.transcript {
        if case .toolCall(let call) = entry, call.id == identity {
          return call
        }
      }
      return nil
    }

    /// Mounts the thread of `session` with a host store, and the registered
    /// test view for ``readFileName``.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - store: The store of the expanded rows.
    /// - Returns: The harness.
    static func mountThread(
      _ session: ScriptedSession, store: ExpandedBlocksStore
    ) -> HostedViewHarness<some View> {
      HostedViewHarness(size: tallSize) {
        AgentThreadView(session: session.model, actions: NoopThreadActions())
          .toolCallView(named: readFileName) { entry in
            Text(entry.title ?? "").accessibilityIdentifier(registeredIdentifier)
          }
          .environment(\.expandedBlocksStore, store)
          .transaction { $0.disablesAnimations = true }
      }
    }

    /// Sends one update, waits for the row of the call, and expands it.
    ///
    /// - Parameters:
    ///   - update: The `tool_call_update` value.
    ///   - id: The `toolCallId` of the call.
    ///   - session: The scripted session.
    ///   - harness: The harness that shows the thread.
    ///   - store: The store of the expanded rows.
    /// - Returns: The row key of the call.
    /// - Throws: The error of the transport, or a missing entry.
    static func showExpandedCall(
      _ update: String, id: String, in session: ScriptedSession,
      harness: HostedViewHarness<some View>, store: ExpandedBlocksStore
    ) async throws -> String {
      try await session.sendUpdate(update)
      await harness.pump(until: waitTimeout) { rowKey(ofCall: id, in: session.model) != nil }
      let key = try #require(rowKey(ofCall: id, in: session.model))
      store.expand(key)
      await harness.pump(until: waitTimeout) {
        harness.element(identifier: ToolCallView.bodyIdentifier(for: key)) != nil
      }
      return key
    }

    // MARK: - Registry and label

    @Test func aNamedCallShowsTheViewRegisteredForItsNameWithTheTitleAsItsLabel() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }

      let update = Self.toolCallUpdate(
        id: "named-c", fields: #""name": "\#(Self.readFileName)", "# + Self.readFields)
      let key = try await Self.showExpandedCall(
        update, id: "named-c", in: session, harness: harness, store: store)

      #expect(harness.element(identifier: Self.registeredIdentifier) != nil)
      #expect(harness.element(identifier: ToolCallView.locationsIdentifier(for: key)) == nil)
      #expect(harness.element(identifier: ToolCallView.identifier(for: key))?.label == Self.runningLabel)
    }

    @Test func aCallWithNoNameShowsTheDefaultBody() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }

      let key = try await Self.showExpandedCall(
        Self.toolCallUpdate(id: "plain-c", fields: Self.readFields), id: "plain-c",
        in: session, harness: harness, store: store)

      #expect(harness.element(identifier: Self.registeredIdentifier) == nil)
      #expect(harness.element(identifier: ToolCallView.locationsIdentifier(for: key)) != nil)
      #expect(harness.element(identifier: ToolCallView.identifier(for: key))?.label == Self.runningLabel)
    }

    @Test func theLabelChangesWithTheStatusOfTheEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let key = try await Self.showExpandedCall(
        Self.toolCallUpdate(id: "status-c", fields: Self.readFields), id: "status-c",
        in: session, harness: harness, store: store)

      try await session.sendUpdate(
        Self.toolCallUpdate(id: "status-c", fields: #""status": "completed""#))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ToolCallView.identifier(for: key))?.label == Self.completedLabel
      }

      #expect(harness.element(identifier: ToolCallView.identifier(for: key))?.label == Self.completedLabel)
    }

    // MARK: - Diff

    @Test func aStructuredDiffShowsTheDiffViewAndNotTheUnknownView() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }

      let fields = #"""
        "title": "Add new.swift", "kind": "edit", "status": "completed",
        "content": [{"type": "diff", "changes": [{"operation": "add", "path": "\#(Self.addedPath)"}]}]
        """#
      _ = try await Self.showExpandedCall(
        Self.toolCallUpdate(id: "diff-c", fields: fields), id: "diff-c",
        in: session, harness: harness, store: store)

      #expect(harness.element(identifier: DiffView.containerIdentifier) != nil)
      #expect(harness.element(identifier: DiffView.identifier(for: Self.addedPath)) != nil)
      #expect(harness.element(identifier: UnknownItemView.identifier) == nil)
    }

    // MARK: - Linked elicitation

    @Test func aLinkedElicitationShowsInTheRowOfItsToolCallOnly() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model
      try await session.sendUpdate(Self.toolCallUpdate(id: "ask-c", fields: Self.readFields))
      try await session.sendUpdate(Self.toolCallUpdate(id: "other-c", fields: Self.readFields))
      await harness.pump(until: Self.waitTimeout) { Self.rowKey(ofCall: "other-c", in: model) != nil }
      let askKey = try #require(Self.rowKey(ofCall: "ask-c", in: model))
      let otherKey = try #require(Self.rowKey(ofCall: "other-c", in: model))

      let params = #"""
        {"sessionId": "\#(ScriptedSession.sessionID)", "toolCallId": "ask-c",
         "message": "Which branch?", "mode": "form",
         "requestedSchema": {"type": "object", "properties": {"branch": {"type": "string"}}}}
        """#
      try await session.agent.send(
        #"{"jsonrpc":"2.0","id":\#(Self.elicitationRequestID),"method":"elicitation/create","params":\#(params)}"#)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ToolCallView.elicitationsIdentifier(for: askKey)) != nil
      }

      let linked = try #require(Self.toolCallEntry("ask-c", in: model)?.linkedElicitationIDs.first)
      #expect(model.pendingElicitations.map(\.id) == [linked])
      #expect(harness.element(identifier: ToolCallView.elicitationsIdentifier(for: askKey)) != nil)
      #expect(harness.element(identifier: ElicitationView.headerIdentifier) != nil)
      #expect(harness.element(identifier: ToolCallView.elicitationsIdentifier(for: otherKey)) == nil)
    }
  }
#endif
