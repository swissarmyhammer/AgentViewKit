import AgentViewKitTestSupport
import SwiftUI
import Testing

// The unknown record of the old thread path has no transcript entry, so the
// tests read the internal identifier form of the store.
@testable import AgentViewKit

@Suite(.serialized, .hostedSerially) @MainActor struct UnknownItemViewHostedTests {
  /// Makes an unknown record.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: The record.
  static func unknownRecord(id: String) -> UnknownRecord {
    UnknownRecord(id: id, kind: "future_kind", raw: .object(["answer": .string("yes")]))
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

  // MARK: - Thread

  @Test func anUnknownItemShowsTheRawView() {
    let thread = Self.thread(with: .unknown(Self.unknownRecord(id: "unknown-default")))
    let harness = HostedViewHarness(AgentThreadView(thread: thread, actions: NoopThreadActions()))
    defer { harness.close() }
    harness.pump()

    #expect(UnknownItemView.identifier == "unknown-item")
    #expect(harness.element(identifier: UnknownItemView.identifier) != nil)
  }

  // MARK: - Views

  @Test func anExpandedUnknownViewShowsTheKindAndTheRawJSON() {
    let record = Self.unknownRecord(id: "unknown-expanded")
    let harness = HostedViewHarness(UnknownItemView(record: record, isExpanded: true))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains("future_kind") })
    #expect(labels.contains(record.raw.prettyPrinted))
  }

  @Test func aCollapsedUnknownViewHidesTheRawJSON() {
    let record = Self.unknownRecord(id: "unknown-collapsed")
    let harness = HostedViewHarness(UnknownItemView(record: record))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains("future_kind") })
    #expect(!labels.contains(record.raw.prettyPrinted))
  }

  @Test func theStoreOfTheEnvironmentKeepsTheExpandedState() {
    let record = Self.unknownRecord(id: "unknown-store")
    let store = ExpandedBlocksStore()
    store.expand(id: record.id)
    let harness = HostedViewHarness(
      UnknownItemView(record: record).environment(\.expandedBlocksStore, store))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains(record.raw.prettyPrinted))
  }
}
