import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

@Suite(.serialized) @MainActor struct StructuredAndUnknownItemViewHostedTests {
  /// The schema name that the tests use.
  static let schemaName = "Demo.Chart"

  /// The accessibility identifier of the registered chart view.
  static let registeredIdentifier = "registered-chart"

  /// Makes a structured record with a small payload.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: The record.
  static func structuredRecord(id: String) -> StructuredRecord {
    StructuredRecord(
      id: id, schemaName: schemaName,
      payload: .object(["title": .string("Sales"), "points": .array([.number(1), .number(2)])]))
  }

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

  @Test func anUnregisteredStructuredItemShowsTheJSONView() {
    let thread = Self.thread(with: .structured(Self.structuredRecord(id: "structured-default")))
    let harness = HostedViewHarness(AgentThreadView(thread: thread))
    defer { harness.close() }
    harness.pump()

    let identifier = StructuredItemView.identifier(for: Self.schemaName)
    #expect(identifier == "structured-item-Demo.Chart")
    #expect(harness.element(identifier: identifier) != nil)
  }

  @Test func aRegisteredStructuredItemShowsTheRegistration() {
    let thread = Self.thread(with: .structured(Self.structuredRecord(id: "structured-registered")))
    let view = AgentThreadView(thread: thread)
      .structuredItem(Self.schemaName) { content in
        Text("Chart \(content.payload["title"]?.stringValue ?? "")")
          .accessibilityIdentifier(Self.registeredIdentifier)
      }
    let harness = HostedViewHarness(view)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: Self.registeredIdentifier)?.label == "Chart Sales")
    #expect(harness.element(identifier: StructuredItemView.identifier(for: Self.schemaName)) == nil)
  }

  @Test func anUnknownItemShowsTheRawView() {
    let thread = Self.thread(with: .unknown(Self.unknownRecord(id: "unknown-default")))
    let harness = HostedViewHarness(AgentThreadView(thread: thread))
    defer { harness.close() }
    harness.pump()

    #expect(UnknownItemView.identifier == "unknown-item")
    #expect(harness.element(identifier: UnknownItemView.identifier) != nil)
  }

  // MARK: - Views

  @Test func anExpandedStructuredViewShowsTheSchemaNameAndThePrettyJSON() {
    let record = Self.structuredRecord(id: "structured-expanded")
    let harness = HostedViewHarness(StructuredItemView(record: record, isExpanded: true))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains(Self.schemaName))
    #expect(labels.contains(record.payload.prettyPrinted))
  }

  @Test func aCollapsedStructuredViewHidesThePayload() {
    let record = Self.structuredRecord(id: "structured-collapsed")
    let harness = HostedViewHarness(StructuredItemView(record: record))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains(Self.schemaName))
    #expect(!labels.contains(record.payload.prettyPrinted))
  }

  @Test func anExpandedUnknownViewShowsTheKindAndTheRawJSON() {
    let record = Self.unknownRecord(id: "unknown-expanded")
    let harness = HostedViewHarness(UnknownItemView(record: record, isExpanded: true))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains("future_kind") })
    #expect(labels.contains(record.raw.prettyPrinted))
  }

  @Test func theStoreOfTheEnvironmentKeepsTheExpandedState() {
    let record = Self.structuredRecord(id: "structured-store")
    let store = ExpandedBlocksStore()
    store.expand(record.id)
    let harness = HostedViewHarness(
      StructuredItemView(record: record).environment(\.expandedBlocksStore, store))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains(record.payload.prettyPrinted))
  }
}
