import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``CompactionMarkerView``.
@Suite(.serialized, .hostedSerially) @MainActor struct CompactionMarkerViewHostedTests {
  /// The longest time that a test waits for the view to change, in seconds.
  static let waitTimeout: TimeInterval = 2

  /// The summary text of the test marker.
  static let summary = "The agent read three files and fixed the build."

  /// Makes a thread with two tool calls and a reasoning item, and then
  /// compacts them into a marker with the id `k1`.
  ///
  /// - Parameter summary: The summary of the marker.
  /// - Returns: The thread and the marker.
  static func compactedThread(summary: String? = summary) -> (AgentThread, CompactionMarker) {
    let thread = AgentThread()
    let items: [ThreadItem] = [
      .toolCall(ToolCallRecord(id: "t1", title: "Read file")),
      .reasoning(Reasoning(id: "r1", segments: ["Think"])),
      .toolCall(ToolCallRecord(id: "t2", title: "Edit file")),
    ]
    for item in items {
      thread.apply(.insert(item, after: nil))
    }
    let marker = CompactionMarker(id: "k1", summary: summary)
    thread.apply(.compact(marker: marker, removing: ["t1", "r1", "t2"]))
    return (thread, marker)
  }

  @Test func theLabelOfTheMarkerHasTheCount() {
    #expect(
      CompactionMarkerView.accessibilityText(removedCount: 3)
        == "Conversation compacted, 3 items summarized")
    #expect(
      CompactionMarkerView.accessibilityText(removedCount: 1)
        == "Conversation compacted, 1 item summarized")
  }

  @Test func anItemRowShowsTheMarkerWithTheCountInItsLabel() async {
    let (thread, _) = Self.compactedThread()
    let harness = HostedViewHarness(AgentThreadView(thread: thread, actions: NoopThreadActions()))
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: CompactionMarkerView.identifier) != nil
    }

    let marker = harness.element(identifier: CompactionMarkerView.identifier)
    #expect(marker?.label == "Conversation compacted, 3 items summarized")
    #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: "k1")) == nil)
    #expect(harness.accessibilityElements().contains { $0.label == Self.summary })
  }

  @Test func theDisclosureIsClosedAndAPressListsTheRemovedKinds() async throws {
    let (_, marker) = Self.compactedThread()
    let harness = HostedViewHarness(CompactionMarkerView(record: marker))
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: CompactionMarkerView.toggleIdentifier) != nil
    }

    #expect(harness.element(identifier: CompactionMarkerView.removedIdentifier) == nil)

    try harness.press(identifier: CompactionMarkerView.toggleIdentifier)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: CompactionMarkerView.removedIdentifier) != nil
    }

    #expect(harness.element(identifier: CompactionMarkerView.removedIdentifier) != nil)
    let toolCalls = harness.element(identifier: CompactionMarkerView.kindIdentifier(for: "tool-call"))
    let reasoning = harness.element(identifier: CompactionMarkerView.kindIdentifier(for: "reasoning"))
    #expect(toolCalls?.label == CompactionMarkerView.kindText(kind: "tool-call", count: 2))
    #expect(reasoning?.label == CompactionMarkerView.kindText(kind: "reasoning", count: 1))

    try harness.press(identifier: CompactionMarkerView.toggleIdentifier)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: CompactionMarkerView.removedIdentifier) == nil
    }
    #expect(harness.element(identifier: CompactionMarkerView.removedIdentifier) == nil)
  }

  @Test func aMarkerWithNoRemovedItemsHasNoDisclosure() async {
    let marker = CompactionMarker(id: "k2", summary: nil)
    let harness = HostedViewHarness(CompactionMarkerView(record: marker))
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: CompactionMarkerView.identifier) != nil
    }

    #expect(
      harness.element(identifier: CompactionMarkerView.identifier)?.label
        == "Conversation compacted, 0 items summarized")
    #expect(harness.element(identifier: CompactionMarkerView.toggleIdentifier) == nil)
  }

  @Test func aSummaryPatchChangesTheShownSummary() async {
    let (thread, _) = Self.compactedThread(summary: nil)
    let harness = HostedViewHarness(AgentThreadView(thread: thread, actions: NoopThreadActions()))
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: CompactionMarkerView.identifier) != nil
    }
    #expect(harness.element(identifier: CompactionMarkerView.summaryIdentifier) == nil)

    thread.apply(.patch(id: "k1", .compaction(summary: .value(Self.summary))))
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: CompactionMarkerView.summaryIdentifier) != nil
    }

    #expect(harness.element(identifier: CompactionMarkerView.summaryIdentifier) != nil)
    #expect(harness.accessibilityElements().contains { $0.label == Self.summary })
  }
}
