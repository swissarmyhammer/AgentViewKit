import AgentViewKitTestSupport
import FoundationModelsACP
import SwiftUI
import Testing

@testable import AgentViewKit

@Suite(.serialized, .hostedSerially) @MainActor struct UnknownItemViewHostedTests {
  /// The kind of the test value.
  static let kind = "future_kind"

  /// The raw value of the test value.
  static let raw = JSONValue.object(["answer": .string("yes")])

  /// Makes the view of the test value.
  ///
  /// - Parameters:
  ///   - id: The id that keys the expanded state.
  ///   - isExpanded: The start state of the view.
  /// - Returns: The view.
  static func makeView(id: String, isExpanded: Bool = false) -> UnknownItemView {
    UnknownItemView(kind: kind, raw: raw, id: id, isExpanded: isExpanded)
  }

  // MARK: - Views

  @Test func anExpandedUnknownViewShowsTheKindAndTheRawJSON() {
    let harness = HostedViewHarness(Self.makeView(id: "unknown-expanded", isExpanded: true))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains(Self.kind) })
    #expect(labels.contains(Self.raw.prettyPrinted))
  }

  @Test func aCollapsedUnknownViewHidesTheRawJSON() {
    let harness = HostedViewHarness(Self.makeView(id: "unknown-collapsed"))
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains(Self.kind) })
    #expect(!labels.contains(Self.raw.prettyPrinted))
  }
}
