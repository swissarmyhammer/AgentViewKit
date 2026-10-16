#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The tool call view over a `ToolCallEntry` of a `SessionModel`
  /// (plan.md §3.8 "Tool call view").
  ///
  /// One `tool_call_update` makes the whole entry, so a test that waits for
  /// the entry in the model, and then makes one render pass, sees each part
  /// of the call.
  @Suite(.serialized, .hostedSerially) @MainActor struct ToolCallEntryViewHostedTests {
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

    /// The JSON-RPC id of the permission request of the agent.
    static let permissionRequestID = 42

    /// The label of the status of a call that waits for the answer of the
    /// user.
    static let waitingLabel = "Waiting for your answer"

    /// The host of the URL of the linked URL elicitation.
    static let urlHost = "example.com"

    /// The label of the status of a call whose URL elicitation waits for the
    /// end of the flow in the browser.
    static let urlWaitingLabel = "Waiting for \(urlHost)"

    /// The default branch of the linked form of the accept test.
    static let defaultBranch = "main"

    /// The path of the file that the fixture call reads.
    static let readPath = "/project/README.md"

    /// The fields of a running call that reads a file, with no name.
    static let readFields = #"""
      "title": "Read README.md", "kind": "read", "status": "in_progress",
      "locations": [{"path": "\#(readPath)"}]
      """#

    /// The path of the location that a later update adds.
    static let addedLocationPath = "/project/Package.swift"

    /// The line of the location that a later update adds.
    static let addedLocationLine = 12

    /// The text of the chip of the location that a later update adds.
    static let addedLocationText = "\(addedLocationPath):\(addedLocationLine)"

    /// The number of locations of the fixture call after the later update.
    static let locationCountAfterUpdate = 2

    /// The path in the raw input of the raw value tests.
    static let inputPath = "/project/input.txt"

    /// The raw output of the raw value tests before the later update.
    static let firstOutput = "first output"

    /// The raw output of the raw value tests after the later update.
    static let secondOutput = "second output"

    /// The member of the raw output that holds the output text.
    static let outputMember = "result"

    /// The text of the text content part of the raw value tests.
    static let partText = "The text part."

    /// The fields of a completed call with a raw input, a raw output and one
    /// text content part.
    static let rawValueFields = #"""
      "title": "Read input.txt", "kind": "read", "status": "completed",
      "rawInput": {"path": "\#(inputPath)"},
      "rawOutput": {"\#(outputMember)": "\#(firstOutput)"},
      "content": [{"type": "content", "content": {"type": "text", "text": "\#(partText)"}}]
      """#

    /// Tells whether an accessibility element shows `text` in its label or its
    /// value.
    ///
    /// - Parameters:
    ///   - text: The text to find.
    ///   - harness: The harness that shows the thread.
    /// - Returns: `true` when an element shows the text.
    static func showsText<Content: View>(_ text: String, in harness: HostedViewHarness<Content>) -> Bool {
      harness.accessibilityElements().contains { element in
        element.label?.contains(text) == true || element.value?.contains(text) == true
      }
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
        AgentThreadView(session: session.model)
          .toolCallView(named: readFileName) { entry in
            Text(entry.title ?? "").accessibilityIdentifier(registeredIdentifier)
          }
          .environment(\.expandedBlocksStore, store)
          .transaction { $0.disablesAnimations = true }
      }
    }

    /// Sends one update, and waits until the model holds the entry of the
    /// call. The caller makes the render pass.
    ///
    /// - Parameters:
    ///   - update: The `tool_call_update` value.
    ///   - id: The `toolCallId` of the call.
    ///   - session: The scripted session.
    /// - Returns: The entry of the call.
    /// - Throws: The error of the transport, or a missing entry.
    static func receiveCall(
      _ update: String, id: String, in session: ScriptedSession
    ) async throws -> ToolCallEntry {
      try await session.sendUpdate(update)
      let model = session.model
      await ObservationWait.until { toolCallEntry(id, in: model) != nil }
      return try #require(toolCallEntry(id, in: model))
    }

    /// Sends one update, waits until the model holds the entry of the call,
    /// expands the row of the call, and makes one render pass.
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
      let call = try await receiveCall(update, id: id, in: session)
      store.expand(entry: .toolCall(call))
      harness.render()
      return call.id.rowKey
    }

    // MARK: - Registry and label

    @Test func aNamedCallShowsTheViewRegisteredForItsNameWithTheTitleAsItsLabel() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }

      let update = WireBlockJSON.makeToolCallUpdate(
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
        WireBlockJSON.makeToolCallUpdate(id: "plain-c", fields: Self.readFields), id: "plain-c",
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
      let model = session.model
      let key = try await Self.showExpandedCall(
        WireBlockJSON.makeToolCallUpdate(id: "status-c", fields: Self.readFields), id: "status-c",
        in: session, harness: harness, store: store)

      try await session.sendUpdate(
        WireBlockJSON.makeToolCallUpdate(id: "status-c", fields: #""status": "completed""#))
      await harness.render { Self.toolCallEntry("status-c", in: model)?.status == .completed }

      #expect(harness.element(identifier: ToolCallView.identifier(for: key))?.label == Self.completedLabel)
    }

    // MARK: - Locations

    @Test func aLaterUpdateAddsALocationChip() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model
      _ = try await Self.showExpandedCall(
        WireBlockJSON.makeToolCallUpdate(id: "location-c", fields: Self.readFields), id: "location-c",
        in: session, harness: harness, store: store)
      #expect(!Self.showsText(Self.addedLocationText, in: harness))

      let locations = #"""
        "locations": [{"path": "\#(Self.readPath)"},
                      {"path": "\#(Self.addedLocationPath)", "line": \#(Self.addedLocationLine)}]
        """#
      try await session.sendUpdate(WireBlockJSON.makeToolCallUpdate(id: "location-c", fields: locations))
      await harness.render {
        Self.toolCallEntry("location-c", in: model)?.locations.count == Self.locationCountAfterUpdate
      }

      #expect(Self.showsText(Self.addedLocationText, in: harness))
    }

    // MARK: - Raw values and content

    @Test func theBodyShowsTheRawInputTheTextPartAndTheRawOutputOfTheEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }

      let key = try await Self.showExpandedCall(
        WireBlockJSON.makeToolCallUpdate(id: "raw-c", fields: Self.rawValueFields), id: "raw-c",
        in: session, harness: harness, store: store)

      #expect(harness.element(identifier: ToolCallView.inputIdentifier(for: key)) != nil)
      #expect(harness.element(identifier: ToolCallView.contentIdentifier(for: key, index: 0)) != nil)
      #expect(harness.element(identifier: ToolCallView.outputIdentifier(for: key)) != nil)
      #expect(Self.showsText(Self.inputPath, in: harness))
      #expect(Self.showsText(Self.partText, in: harness))
      #expect(Self.showsText(Self.firstOutput, in: harness))
    }

    @Test func aLaterRawOutputUpdateChangesTheShownOutput() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore()
      let harness = Self.mountThread(session, store: store)
      defer { harness.close() }
      let model = session.model
      _ = try await Self.showExpandedCall(
        WireBlockJSON.makeToolCallUpdate(id: "output-c", fields: Self.rawValueFields), id: "output-c",
        in: session, harness: harness, store: store)
      #expect(Self.showsText(Self.firstOutput, in: harness))

      try await session.sendUpdate(
        WireBlockJSON.makeToolCallUpdate(
          id: "output-c", fields: #""rawOutput": {"\#(Self.outputMember)": "\#(Self.secondOutput)"}"#))
      await harness.render {
        Self.toolCallEntry("output-c", in: model)?.rawOutput?[Self.outputMember] == .string(Self.secondOutput)
      }

      #expect(Self.showsText(Self.secondOutput, in: harness))
      #expect(!Self.showsText(Self.firstOutput, in: harness))
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
        WireBlockJSON.makeToolCallUpdate(id: "diff-c", fields: fields), id: "diff-c",
        in: session, harness: harness, store: store)

      #expect(harness.element(identifier: DiffView.containerIdentifier) != nil)
      #expect(harness.element(identifier: DiffView.identifier(for: Self.addedPath)) != nil)
      #expect(harness.element(identifier: UnknownItemView.identifier) == nil)
    }

    // MARK: - Linked elicitation

    // The tool call row shows only a status for a linked elicitation. The
    // card of the elicitation is in the ``RequestDeck`` (deck design
    // section 5, test plan row 38).

    /// Mounts the thread and the deck of `session` in one focus scope, as an
    /// app does, with `reporter` as the focus reporter.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - reporter: The focus reporter of the environment.
    /// - Returns: The harness.
    static func mountThreadAndDeck(
      _ session: ScriptedSession, reporter: RecordingFocusReporter
    ) -> HostedViewHarness<some View> {
      HostedViewHarness(size: tallSize) {
        ThreadAccessibilityHostedTests.threadAndDeck(of: session.model)
          .environment(\.focusReporter, reporter)
          .transaction { $0.disablesAnimations = true }
      }
    }

    /// Sends the running read call of `id`, and then each of `requests`, in
    /// order. The function waits until the model holds the entry of the call
    /// and each request (``ScriptedSession/sendInOrder(_:)``). The caller
    /// makes the render pass.
    ///
    /// - Parameters:
    ///   - id: The `toolCallId` of the call.
    ///   - requests: The requests of the agent.
    ///   - session: The scripted session.
    /// - Returns: The row key of the call.
    /// - Throws: The error of the transport, or a missing entry.
    static func sendCall(
      _ id: String, thenRequests requests: [ScriptedSession.AgentRequest] = [], to session: ScriptedSession
    ) async throws -> String {
      let update = WireBlockJSON.makeToolCallUpdate(id: id, fields: readFields)
      let call = try await receiveCall(update, id: id, in: session)
      try await session.sendInOrder(requests)
      return call.id.rowKey
    }

    /// Sends the call of `id` with one linked elicitation, makes one render
    /// pass, and makes sure that the row of the call shows the waiting
    /// status.
    ///
    /// - Parameters:
    ///   - id: The `toolCallId` of the call.
    ///   - session: The scripted session.
    ///   - harness: The harness that shows the thread and the deck.
    /// - Returns: The row key of the call.
    /// - Throws: The error of the transport, or an issue when the row shows
    ///   no waiting status.
    static func showWaitingCall(
      _ id: String, in session: ScriptedSession, harness: HostedViewHarness<some View>
    ) async throws -> String {
      let key = try await sendCall(id, thenRequests: [.linkedElicitation(toolCall: id)], to: session)
      harness.render()
      try #require(harness.element(identifier: ToolCallView.waitingIdentifier(for: key)) != nil)
      return key
    }

    /// A way that the user cancels a linked elicitation of the deck.
    enum CancelExit: CaseIterable, Sendable {
      /// A press on the Cancel button of the card.
      case cancelButton

      /// Cancel-all of the session model, as when the session closes.
      case cancelAll
    }

    @Test func aLinkedCallShowsTheWaitingStatusInItsRowOnlyAndNoForm() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session, store: ExpandedBlocksStore())
      defer { harness.close() }
      let otherKey = try await Self.sendCall("other-c", to: session)

      let key = try await Self.sendCall("ask-c", thenRequests: [.linkedElicitation(toolCall: "ask-c")], to: session)
      harness.render()

      #expect(harness.element(identifier: ToolCallView.waitingIdentifier(for: key))?.label == Self.waitingLabel)
      #expect(harness.element(identifier: ToolCallView.waitingIdentifier(for: otherKey)) == nil)
      #expect(harness.element(identifier: ElicitationView.formIdentifier) == nil)
    }

    @Test func aPressOnTheWaitingStatusBringsTheLinkedCardToTheFrontWithTheFocus() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let reporter = RecordingFocusReporter()
      let harness = Self.mountThreadAndDeck(session, reporter: reporter)
      defer { harness.close() }
      let model = session.model
      let key = try await Self.sendCall(
        "front-c",
        thenRequests: [.permission(id: Self.permissionRequestID), .linkedElicitation(toolCall: "front-c")],
        to: session)
      harness.render()
      let linked = try #require(model.pendingElicitations.first?.id)
      #expect(model.frontRequest?.id != linked)

      try harness.press(identifier: ToolCallView.waitingIdentifier(for: key))

      #expect(model.frontRequestID == linked)
      #expect(harness.element(identifier: RequestDeck.positionIdentifier)?.label == "Request 2 of 2")
      #expect(reporter.moves.last == RequestDeck.identifier(for: linked.uuidString))
    }

    @Test func anAnswerInTheDeckRemovesTheWaitingStatus() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThreadAndDeck(session, reporter: RecordingFocusReporter())
      defer { harness.close() }
      let model = session.model
      let key = try await Self.showWaitingCall("accept-c", in: session, harness: harness)

      try harness.press(identifier: ElicitationView.submitIdentifier)
      // The model removes the pending elicitation and its link in the same
      // step as the Submit press, so a press that did not answer stops the
      // test here.
      try #require(model.pendingRequests.isEmpty)
      let result = await session.result(ofRequest: Self.elicitationRequestID)

      let expected = try JSONValue(
        json: #"{"action": "accept", "content": {"branch": "\#(Self.defaultBranch)"}}"#)
      #expect(result == expected)
      #expect(harness.element(identifier: ToolCallView.waitingIdentifier(for: key)) == nil)
    }

    @Test(arguments: CancelExit.allCases)
    func aCancelOfTheLinkedCardRemovesTheWaitingStatus(exit: CancelExit) async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThreadAndDeck(session, reporter: RecordingFocusReporter())
      defer { harness.close() }
      let model = session.model
      let key = try await Self.showWaitingCall("cancel-c", in: session, harness: harness)

      switch exit {
      case .cancelButton: try harness.press(identifier: ElicitationView.cancelIdentifier)
      case .cancelAll: model.cancelAllPending()
      }
      // The model removes the pending elicitation and its link in the same
      // step as the cancel, so a cancel that did not reach the model stops
      // the test here.
      try #require(model.pendingRequests.isEmpty)
      harness.render()
      let result = await session.result(ofRequest: Self.elicitationRequestID)

      #expect(result == (try JSONValue(json: #"{"action": "cancel"}"#)))
      #expect(harness.element(identifier: ToolCallView.waitingIdentifier(for: key)) == nil)
    }

    @Test func noToolCallRowShowsAnInlineFormForAPermissionOrAnElicitation() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session, store: ExpandedBlocksStore())
      defer { harness.close() }

      let key = try await Self.sendCall(
        "both-c",
        thenRequests: [.linkedPermission(toolCall: "both-c"), .linkedElicitation(toolCall: "both-c")],
        to: session)
      harness.render()

      #expect(harness.element(identifier: ToolCallView.waitingIdentifier(for: key)) != nil)
      #expect(harness.element(identifier: ElicitationView.formIdentifier) == nil)
      #expect(harness.element(identifier: PermissionView.identifier) == nil)
    }

    /// The accept of a URL elicitation removes its link, and the model keeps
    /// the elicitation in `awaitingURLCompletions` (deck design section 7).
    @Test func aCallWhoseURLElicitationWaitsShowsWaitingForTheHost() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountThread(session, store: ExpandedBlocksStore())
      defer { harness.close() }
      let model = session.model
      let key = try await Self.sendCall("url-c", thenRequests: [.linkedURLElicitation(toolCall: "url-c")], to: session)
      let pending = try #require(model.pendingElicitations.first)

      model.acceptElicitation(pending.id)
      // The accept moves the elicitation in the same step, so an accept that
      // did not reach the model stops the test here.
      try #require(model.awaitingURLCompletions.map(\.id) == [pending.id])
      harness.render()

      #expect(harness.element(identifier: ToolCallView.waitingIdentifier(for: key))?.label == Self.urlWaitingLabel)

      model.stopWaiting(pending.id)
      harness.render()

      #expect(harness.element(identifier: ToolCallView.waitingIdentifier(for: key)) == nil)
    }

    @Test func aCallWithNoSessionModelInTheEnvironmentShowsNoWaitingStatus() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let key = try await Self.sendCall(
        "alone-c", thenRequests: [.linkedElicitation(toolCall: "alone-c")], to: session)
      let entry = try #require(Self.toolCallEntry("alone-c", in: session.model))
      #expect(!entry.linkedElicitationIDs.isEmpty)

      let harness = HostedViewHarness(size: Self.tallSize) { ToolCallView(entry: entry) }
      defer { harness.close() }
      harness.render()

      #expect(harness.element(identifier: ToolCallView.identifier(for: key)) != nil)
      #expect(harness.element(identifier: ToolCallView.waitingIdentifier(for: key)) == nil)
    }
  }

  /// The requests that the agent of ``ToolCallEntryViewHostedTests`` links
  /// to a tool call.
  @MainActor extension ScriptedSession.AgentRequest {
    /// A form elicitation that the agent links to the tool call of `id`,
    /// with the id ``ToolCallEntryViewHostedTests/elicitationRequestID``. The
    /// one field `branch` has the default
    /// ``ToolCallEntryViewHostedTests/defaultBranch``, so the form can submit
    /// at once.
    ///
    /// - Parameter id: The `toolCallId` of the call.
    /// - Returns: The request.
    static func linkedElicitation(toolCall id: String) -> Self {
      let branch = ToolCallEntryViewHostedTests.defaultBranch
      let params = #"""
        {"sessionId": "\#(ScriptedSession.sessionID)", "toolCallId": "\#(id)",
         "message": "Which branch?", "mode": "form",
         "requestedSchema": {"type": "object",
                             "properties": {"branch": {"type": "string", "default": "\#(branch)"}}}}
        """#
      return Self(
        method: ScriptedSession.elicitationMethod, id: ToolCallEntryViewHostedTests.elicitationRequestID,
        params: params)
    }

    /// A URL elicitation that the agent links to the tool call of `id`, with
    /// the id ``ToolCallEntryViewHostedTests/elicitationRequestID``. The URL
    /// has the host ``ToolCallEntryViewHostedTests/urlHost``.
    ///
    /// - Parameter id: The `toolCallId` of the call.
    /// - Returns: The request.
    static func linkedURLElicitation(toolCall id: String) -> Self {
      let host = ToolCallEntryViewHostedTests.urlHost
      let params = #"""
        {"sessionId": "\#(ScriptedSession.sessionID)", "toolCallId": "\#(id)",
         "message": "Sign in.", "mode": "url", "url": "https://\#(host)/login",
         "elicitationId": "url-\#(id)"}
        """#
      return Self(
        method: ScriptedSession.elicitationMethod, id: ToolCallEntryViewHostedTests.elicitationRequestID,
        params: params)
    }

    /// A permission request that the agent links to the tool call of `id`,
    /// with the id ``ToolCallEntryViewHostedTests/permissionRequestID``.
    ///
    /// - Parameter id: The `toolCallId` of the call.
    /// - Returns: The request.
    static func linkedPermission(toolCall id: String) -> Self {
      let params = #"""
        {"sessionId": "\#(ScriptedSession.sessionID)", "toolCall": {"toolCallId": "\#(id)"},
         "title": "Edit a.swift",
         "options": [{"optionId": "yes", "name": "Allow", "kind": "allow_once"}]}
        """#
      return Self(
        method: ScriptedSession.permissionMethod, id: ToolCallEntryViewHostedTests.permissionRequestID,
        params: params)
    }
  }
#endif
