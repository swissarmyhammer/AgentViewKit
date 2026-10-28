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
    /// A size that shows the expanded body of a call.
    static let tallSize = CGSize(width: 520, height: 1_400)

    /// The label of the fixture call after it completes.
    static let completedLabel = "Read README.md, Completed"

    /// The id of the terminal of the terminal test.
    static let terminalID = "terminal-under-test"

    /// The program name of the tool that the swap test registers.
    static let registeredName = "read_file"

    /// The accessibility identifier of the first registered view of the swap
    /// test.
    static let firstRegisteredIdentifier = "first-registered-view"

    /// The accessibility identifier of the second registered view of the swap
    /// test.
    static let secondRegisteredIdentifier = "second-registered-view"

    /// The fields of a running call that reads a file, with a raw input and
    /// one text content part.
    static let readFields = #"""
      "title": "Read README.md", "kind": "read", "status": "in_progress",
      "locations": [{"path": "/project/README.md"}],
      "rawInput": {"path": "/project/README.md"},
      "content": [{"type": "content", "content": {"type": "text", "text": "The file."}}]
      """#

    /// The folder of the project of the edit fixture, before a relative path of
    /// the patch.
    static let projectDirectory = "/project/"

    /// The file that the edit fixture only reads: it has a location and no
    /// diff.
    static let readOnlyPath = "/project/Package.swift"

    /// The locations of the edit fixture: the two files of
    /// ``DiffViewHostedTests/patch`` as absolute paths, then
    /// ``readOnlyPath``.
    static let editLocations = [
      projectDirectory + DiffViewHostedTests.firstPath, projectDirectory + DiffViewHostedTests.secondPath,
      readOnlyPath,
    ]

    /// The fields of a completed edit with a raw input, a raw output, the
    /// locations ``editLocations``, and one diff part with the patch of two
    /// files, ``DiffViewHostedTests/patch``. The title and the raw values name
    /// no file.
    ///
    /// - Returns: The fields, as JSON members.
    /// - Throws: The error of the JSON encode of the patch.
    static func editFields() throws -> String {
      let patch = try #require(String(data: JSONEncoder().encode(DiffViewHostedTests.patch), encoding: .utf8))
      let locations = editLocations.map { #"{"path": "\#($0)"}"# }.joined(separator: ", ")
      return #"""
        "title": "Edit two files", "kind": "edit", "status": "completed",
        "locations": [\#(locations)],
        "rawInput": {"replaceAll": false}, "rawOutput": {"applied": true},
        "content": [{"type": "diff", "changes": [], "patch": {"format": "git_patch", "text": \#(patch)}}]
        """#
    }

    /// Opens a scripted session and sends one tool call.
    ///
    /// - Parameters:
    ///   - id: The `toolCallId` of the call.
    ///   - fields: The other fields of the `tool_call_update`, as JSON members.
    /// - Returns: The session and the entry of the call.
    /// - Throws: The error of the transport, or an issue when the model holds
    ///   no such entry at the time limit.
    static func openCall(id: String, fields: String) async throws -> (ScriptedSession, ToolCallEntry) {
      try await ScriptedSession.openWithEntry(
        update: WireBlockJSON.makeToolCallUpdate(id: id, fields: fields),
        lookingUp: { ToolCallEntryViewHostedTests.toolCallEntry(id, in: $0) })
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

    /// Mounts the view of `call` with the store `store`, and makes one
    /// ``HostedViewHarness/render()`` pass.
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
      harness.render()
      return harness
    }

    // MARK: - Font role

    @Test func theTitleRowDrawsInTheUIRole() async throws {
      let (session, call) = try await Self.openCall(id: "font-role-call", fields: Self.readFields)
      defer { session.close() }

      try FontRoleExpectations.expectText(
        of: ToolCallView(entry: call), identifier: ToolCallView.toggleIdentifier(for: call.id.rowKey), drawsIn: .ui,
        size: Self.tallSize)
    }

    // MARK: - Evaluation counts

    /// The mount makes its body evaluations in the ``mount(_:store:)``
    /// render pass, before the reset of the counters. The test then waits
    /// for the status of the entry, which the update is certain to change,
    /// and makes one render pass before it reads the counts.
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
      await harness.render { call.status == .completed }

      #expect(harness.element(identifier: ToolCallView.identifier(for: key))?.label == Self.completedLabel)
      #expect(BodyEvaluationCounter.count(rowKey) >= 1)
      #expect(BodyEvaluationCounter.count(bodyKey) == 0)
    }

    // MARK: - Registry

    @Test func aSwapOfTheRegisteredViewRefreshesTheExpandedBody() async throws {
      let fields = #""name": "\#(Self.registeredName)", "# + Self.readFields
      let (session, call) = try await Self.openCall(id: "swap-call", fields: fields)
      defer { session.close() }
      let choice = RegisteredViewChoice(identifier: Self.firstRegisteredIdentifier)
      let harness = HostedViewHarness(size: Self.tallSize) {
        RegisteredViewSwapHost(call: call, store: Self.makeExpandedStore(for: call), choice: choice)
      }
      defer { harness.close() }
      harness.render()
      #expect(harness.element(identifier: Self.firstRegisteredIdentifier) != nil)

      choice.identifier = Self.secondRegisteredIdentifier
      harness.render()

      #expect(harness.element(identifier: Self.secondRegisteredIdentifier) != nil)
      #expect(harness.element(identifier: Self.firstRegisteredIdentifier) == nil)
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

      #expect(store.isExpanded(entry: .toolCall(call)))
      #expect(harness.element(identifier: ToolCallView.locationsIdentifier(for: key)) != nil)
      #expect(harness.element(identifier: ToolCallView.inputIdentifier(for: key)) != nil)
      #expect(harness.element(identifier: ToolCallView.contentIdentifier(for: key, index: 0)) != nil)
      #expect(harness.element(identifier: ToolCallView.outputIdentifier(for: key)) == nil)

      try harness.press(identifier: toggleID)

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

    // MARK: - Diff

    /// The chips of a call: its location chips and its diff file chips. Each
    /// location chip has the identifier of the chip at index 0 with its own
    /// index in place of the 0, and the identifier of a diff file chip starts
    /// with ``DiffView/identifierPrefix`` and ends with the path of its file.
    ///
    /// - Parameters:
    ///   - key: The row key of the call.
    ///   - harness: The harness that shows the call.
    /// - Returns: The accessibility elements of the chips.
    static func chips<Content: View>(
      ofCall key: String, in harness: HostedViewHarness<Content>
    ) -> [AccessibilityElementSnapshot] {
      let locationPrefix = ToolCallView.locationIdentifier(for: key, index: 0).dropLast()
      return harness.accessibilityElements().filter { element in
        guard let identifier = element.identifier else { return false }
        return identifier.hasPrefix(locationPrefix) || identifier.hasPrefix(DiffView.identifierPrefix)
      }
    }

    /// Each file of the diff shows once, as its ``DiffView`` file chip: the
    /// location of the same file shows no chip of its own (card ^tgjr9xg).
    /// The location that the diff does not show keeps its chip.
    @Test func eachFileOfADiffShowsOnceAsItsDiffChip() async throws {
      let (session, call) = try await Self.openCall(id: "diff-once-call", fields: try Self.editFields())
      defer { session.close() }
      let harness = Self.mount(call, store: Self.makeExpandedStore(for: call))
      defer { harness.close() }
      let key = call.id.rowKey
      let chips = Self.chips(ofCall: key, in: harness)

      for (index, location) in Self.editLocations.enumerated() {
        let name = URL(filePath: location).lastPathComponent
        let named = chips.filter { chip in
          [chip.identifier, chip.label, chip.value].contains { $0?.contains(name) == true }
        }
        #expect(named.count == 1, "\(location): \(named.compactMap(\.identifier))")
        let isInDiff = location != Self.readOnlyPath
        let chip = harness.element(identifier: ToolCallView.locationIdentifier(for: key, index: index))
        #expect((chip == nil) == isInDiff, "\(location)")
      }
      for path in [DiffViewHostedTests.firstPath, DiffViewHostedTests.secondPath] {
        #expect(harness.element(identifier: DiffView.identifier(for: path)) != nil, "\(path)")
      }
    }

    /// A diff in a tool call is no tile of its own (card ^tgjr9xg): its file
    /// chips and its detail start on the leading edge of the other blocks of
    /// the expanded body.
    @Test func theDiffChipsTheDiffTextAndTheOtherBlocksShareOneLeadingEdge() async throws {
      let (session, call) = try await Self.openCall(id: "diff-edge-call", fields: try Self.editFields())
      defer { session.close() }
      let harness = Self.mount(call, store: Self.makeExpandedStore(for: call))
      defer { harness.close() }
      let key = call.id.rowKey
      let identifiers = [
        ToolCallView.locationsIdentifier(for: key), ToolCallView.inputIdentifier(for: key),
        DiffView.identifier(for: DiffViewHostedTests.firstPath), DiffView.detailIdentifier,
        ToolCallView.outputIdentifier(for: key),
      ]

      let edges = try identifiers.map { identifier in
        try #require(harness.frame(identifier: identifier), "\(identifier)").minX
      }
      let first = try #require(edges.first)
      for (identifier, edge) in zip(identifiers, edges) {
        #expect(abs(edge - first) <= DiffViewHostedTests.layoutTolerance, "\(identifier)")
      }
    }

    // MARK: - Status

    @Test func aRunningCallShowsItsStatusSymbolWithNoSpinner() async throws {
      let (session, call) = try await Self.openCall(id: "spinner-call", fields: Self.readFields)
      defer { session.close() }
      let harness = Self.mount(call, store: ExpandedBlocksStore())
      defer { harness.close() }
      let toggleID = ToolCallView.toggleIdentifier(for: call.id.rowKey)

      #expect(harness.element(identifier: toggleID) != nil)
      #expect(harness.progressIndicatorCount() == 0)
    }

    // MARK: - Connection

    @Test func theConnectionChipShowsOnlyForACallThatWaitsForAServer() async throws {
      let fields = #""title": "Search", "kind": "search", "status": "pending""#
      let (session, waiting) = try await Self.openCall(id: "waiting-call", fields: fields)
      defer { session.close() }
      let free = try await session.receiveEntry(
        update: WireBlockJSON.makeToolCallUpdate(id: "free-call", fields: fields),
        lookingUp: { ToolCallEntryViewHostedTests.toolCallEntry("free-call", in: $0) })
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
      harness.render()

      let chips = harness.accessibilityElements().filter {
        $0.identifier == ConnectionStatusChip.identifier(for: .connecting)
      }
      #expect(chips.count == 1)
    }
  }

  /// The registered view that ``RegisteredViewSwapHost`` gives, as the
  /// accessibility identifier of that view.
  @Observable @MainActor final class RegisteredViewChoice {
    /// The accessibility identifier of the registered view.
    var identifier: String

    /// Makes a choice.
    ///
    /// - Parameter identifier: The accessibility identifier of the first
    ///   registered view.
    init(identifier: String) {
      self.identifier = identifier
    }
  }

  /// One expanded ``ToolCallView`` with a registered view for
  /// ``ToolCallViewHostedTests/registeredName``.
  ///
  /// The host reads ``RegisteredViewChoice/identifier`` in its own body, and
  /// registers a new view function for each value. The registered view does
  /// not read the choice, so only a new registration can change it.
  struct RegisteredViewSwapHost: View {
    /// The tool call entry to show.
    let call: ToolCallEntry

    /// The store in which the call is expanded.
    let store: ExpandedBlocksStore

    /// The registered view to give.
    let choice: RegisteredViewChoice

    var body: some View {
      let identifier = choice.identifier
      ToolCallView(entry: call)
        .toolCallView(named: ToolCallViewHostedTests.registeredName) { _ in
          Text(verbatim: identifier).accessibilityIdentifier(identifier)
        }
        .environment(\.expandedBlocksStore, store)
        .transaction { $0.disablesAnimations = true }
    }
  }
#endif
