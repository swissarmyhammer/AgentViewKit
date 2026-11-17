@testable import AgentViewKit
import AppKit
import EditorSwiftUI
import EditorTestSupport
import SwiftUI
import Testing

/// The plain texts of a thread have one selection
/// (Docs/decisions/text-selection.md).
///
/// Each plain text is an EditorKit `EditorLabel`, which joins the
/// ``ThreadTextSelection`` of the environment. A selection in one label
/// clears the selection of the label that had it.
@Suite(.serialized, .hostedSerially) @MainActor struct PlainTextSelectionHostedTests {
  /// The text of the first label.
  static let firstText = "The first text."

  /// The text of the second label.
  static let secondText = "The second text."

  /// The type name of the text view of an `EditorLabel` (EditorKit
  /// `EditorLabelTextView.swift`).
  static let labelViewTypeName = "EditorLabelTextView"

  /// Mounts two labels in the one selection of a thread.
  static func mount() -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: CGSize(width: 400, height: 200)) {
      VStack(alignment: .leading) {
        EditorLabel(verbatim: firstText)
        EditorLabel(verbatim: secondText)
      }
      .threadTextSelection()
      .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  /// The text view of each label under the hosting view, in the order of
  /// the views.
  static func labelViews(in harness: HostedViewHarness<some View>) -> [NSView] {
    harness.hostingView.descendants.filter { String(describing: type(of: $0)) == labelViewTypeName }
  }

  @Test func aSelectionInTheSecondTextClearsTheFirstText() throws {
    let harness = Self.mount()
    defer { harness.close() }
    let labels = Self.labelViews(in: harness)
    try #require(labels.count == 2)

    labels[0].selectAll(nil)
    try #require(labels[0].accessibilitySelectedText() == Self.firstText)
    labels[1].selectAll(nil)

    #expect(labels[0].accessibilitySelectedText() == nil)
    #expect(labels[1].accessibilitySelectedText() == Self.secondText)
  }
}
