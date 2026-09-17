#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import SwiftUI
  import Testing

  @Suite(.serialized, .hostedSerially) @MainActor struct ToolCallViewHostedTests {
    /// The longest time that a test waits for the view to change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows the expanded body of a call.
    static let tallSize = CGSize(width: 520, height: 1_400)

    /// The label of the fixture call while it runs.
    static let runningLabel = "Read README.md, In progress"

    /// The label of the fixture call after it completes.
    static let completedLabel = "Read README.md, Completed"

    /// The id of the terminal of the terminal test.
    static let terminalID = "terminal-under-test"

    /// The command of the terminal and execute tests.
    static let command = "swift build"

    /// Makes a thread with one tool call.
    ///
    /// - Parameters:
    ///   - id: The identifier of the call.
    ///   - status: The progress of the call.
    /// - Returns: The thread and the call.
    static func makeCallThread(id: String, status: ToolCallStatus) -> (AgentThread, ToolCallRecord) {
      let thread = AgentThread()
      let call = ThreadFixtures.toolCall(id: id, status: status)
      thread.apply(.insert(.toolCall(call), after: nil))
      return (thread, call)
    }

    /// Makes a store in which the call of `id` is expanded.
    ///
    /// - Parameter id: The identifier of the call.
    /// - Returns: The store.
    static func makeExpandedStore(for id: String) -> ExpandedBlocksStore {
      let store = ExpandedBlocksStore()
      store.expand(id)
      return store
    }

    // MARK: - Mount

    @Test func aCallMountsWithItsIdentifierAndLabel() {
      let id = "mount-call"
      let call = ThreadFixtures.toolCall(id: id, status: .inProgress)
      let harness = HostedViewHarness { ToolCallView(record: call) }
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ToolCallView.identifier(for: id))?.label == Self.runningLabel)
      #expect(harness.element(identifier: ToolCallView.toggleIdentifier(for: id)) != nil)
      #expect(harness.element(identifier: ToolCallView.bodyIdentifier(for: id)) == nil)
    }

    @Test func theLabelChangesWithTheStatus() async {
      let id = "label-call"
      let (thread, call) = Self.makeCallThread(id: id, status: .inProgress)
      let harness = HostedViewHarness { ToolCallView(record: call) }
      defer { harness.close() }
      harness.pump()
      #expect(harness.element(identifier: ToolCallView.identifier(for: id))?.label == Self.runningLabel)

      thread.apply(.patch(id: id, .toolCall(status: .value(.completed))))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ToolCallView.identifier(for: id))?.label == Self.completedLabel
      }

      #expect(harness.element(identifier: ToolCallView.identifier(for: id))?.label == Self.completedLabel)
    }

    @Test func theThreadViewShowsTheToolCallView() {
      let id = "thread-call"
      let (thread, _) = Self.makeCallThread(id: id, status: .completed)
      let harness = HostedViewHarness(AgentThreadView(thread: thread))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ToolCallView.identifier(for: id)) != nil)
      #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: id)) == nil)
    }

    // MARK: - Evaluation counts

    @Test func aStatusPatchEvaluatesTheRowAndNotTheExpandedBody() {
      let id = "patch-count-call"
      let (thread, call) = Self.makeCallThread(id: id, status: .inProgress)
      let store = Self.makeExpandedStore(for: id)
      let harness = HostedViewHarness(size: Self.tallSize) {
        ToolCallView(record: call)
          .environment(\.expandedBlocksStore, store)
          .transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }
      harness.pump()
      let rowKey = ToolCallView.rowCounterKey(for: id)
      let bodyKey = ToolCallView.bodyCounterKey(for: id)
      #expect(harness.element(identifier: ToolCallView.bodyIdentifier(for: id)) != nil)
      #expect(BodyEvaluationCounter.count(rowKey) >= 1)
      #expect(BodyEvaluationCounter.count(bodyKey) >= 1)
      BodyEvaluationCounter.reset(rowKey)
      BodyEvaluationCounter.reset(bodyKey)

      thread.apply(.patch(id: id, .toolCall(status: .value(.completed))))
      harness.pump()

      #expect(BodyEvaluationCounter.count(rowKey) == 1)
      #expect(BodyEvaluationCounter.count(bodyKey) == 0)
      BodyEvaluationCounter.reset(rowKey)
      BodyEvaluationCounter.reset(bodyKey)
    }

    // MARK: - Expand

    @Test func aPressOnTheRowTogglesTheStore() async throws {
      let id = "toggle-call"
      let call = ThreadFixtures.toolCall(id: id, status: .completed)
      let store = ExpandedBlocksStore()
      let harness = HostedViewHarness(size: Self.tallSize) {
        ToolCallView(record: call)
          .environment(\.expandedBlocksStore, store)
          .transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }
      harness.pump()
      let toggleID = ToolCallView.toggleIdentifier(for: id)
      let bodyID = ToolCallView.bodyIdentifier(for: id)
      #expect(!store.isExpanded(id))

      try harness.press(identifier: toggleID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: bodyID) != nil }

      #expect(store.isExpanded(id))
      #expect(harness.element(identifier: bodyID) != nil)
      #expect(harness.element(identifier: ToolCallView.locationsIdentifier(for: id)) != nil)
      #expect(harness.element(identifier: ToolCallView.inputIdentifier(for: id)) != nil)
      #expect(harness.element(identifier: ToolCallView.contentIdentifier(for: id, index: 0)) != nil)
      #expect(harness.element(identifier: ToolCallView.outputIdentifier(for: id)) == nil)
      let labels = harness.accessibilityElements().compactMap(\.label)
      #expect(labels.contains("/project/README.md"))

      try harness.press(identifier: toggleID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: bodyID) == nil }

      #expect(!store.isExpanded(id))
      #expect(harness.element(identifier: bodyID) == nil)
    }

    // MARK: - Content

    @Test func theTextOfAnExecuteCallShowsAsCommandOutput() {
      let id = "execute-call"
      let call = ToolCallRecord(
        id: id, title: "Build", kind: .execute, status: .completed,
        content: [.block(ContentBlock(text: "Build complete!"))],
        rawInput: .object(["command": .string(Self.command)]),
        rawOutput: .object(["exitCode": .number(0)]))
      let harness = HostedViewHarness(size: Self.tallSize) {
        ToolCallView(record: call)
          .environment(\.expandedBlocksStore, Self.makeExpandedStore(for: id))
      }
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: CommandOutputView.identifier) != nil)
      #expect(harness.element(identifier: CommandOutputView.footerIdentifier) != nil)
      #expect(harness.element(identifier: ToolCallView.outputIdentifier(for: id)) != nil)
    }

    @Test func aTerminalPartShowsTheTerminalOfTheThread() {
      let id = "terminal-call"
      let thread = AgentThread()
      thread.apply(
        .upsertTerminal(TerminalPatch(id: TerminalID(Self.terminalID), command: .value(Self.command))))
      let call = ToolCallRecord(
        id: id, title: "Build", kind: .execute, status: .inProgress,
        content: [.terminal(id: Self.terminalID), .terminal(id: "missing-terminal")])
      thread.apply(.insert(.toolCall(call), after: nil))
      let harness = HostedViewHarness(size: Self.tallSize) {
        ToolCallView(record: call)
          .environment(\.expandedBlocksStore, Self.makeExpandedStore(for: id))
          .environment(\.agentThread, thread)
      }
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: TerminalView.identifier) != nil)
      #expect(harness.element(identifier: TerminalView.commandIdentifier)?.label == Self.command)
      #expect(harness.element(identifier: CommandOutputView.identifier) == nil)
      let labels = harness.accessibilityElements().compactMap(\.label)
      #expect(labels.contains { $0.contains("missing-terminal") })
    }

    @Test func aDiffAndAnUnknownPartShowInTheBody() {
      let id = "diff-call"
      let call = ToolCallRecord(
        id: id, title: "Edit", kind: .edit, status: .completed,
        content: [
          .diff(patch: "--- a/x\n+++ b/x\n@@ -1 +1 @@\n-old\n+new\n"),
          .unknown(kind: "custom", raw: .object(["a": .number(1)])),
        ])
      let harness = HostedViewHarness(size: Self.tallSize) {
        ToolCallView(record: call)
          .environment(\.expandedBlocksStore, Self.makeExpandedStore(for: id))
      }
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ToolCallView.contentIdentifier(for: id, index: 0)) != nil)
      #expect(harness.element(identifier: DiffView.containerIdentifier) != nil)
      #expect(harness.element(identifier: DiffView.identifier(for: "x")) != nil)
      #expect(harness.element(identifier: CodeBlockView.identifier) == nil)
      #expect(harness.element(identifier: UnknownItemView.identifier) != nil)
    }

    // MARK: - Connection

    @Test func theConnectionChipShowsOnlyForACallThatWaitsForAuth() {
      let waitingID = "waiting-call"
      let freeID = "free-call"
      let waiting = ThreadFixtures.toolCall(id: waitingID, status: .pending)
      let free = ThreadFixtures.toolCall(id: freeID, status: .pending)
      let harness = HostedViewHarness {
        VStack {
          ToolCallView(record: waiting)
          ToolCallView(record: free)
        }
        .toolCallConnectionState { record in
          record.id == waitingID ? .needsAuth : nil
        }
      }
      defer { harness.close() }
      harness.pump()

      let chips = harness.accessibilityElements().filter {
        $0.identifier == ConnectionStatusChip.identifier(for: .needsAuth)
      }
      #expect(chips.count == 1)
    }
  }
#endif
