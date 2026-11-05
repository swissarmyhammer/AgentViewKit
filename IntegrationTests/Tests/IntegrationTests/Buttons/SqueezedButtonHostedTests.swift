@testable import AgentViewKit
import AgentViewKitStyle
import AppKit
import EditorTestSupport
import SwiftUI
import Testing

/// Hosted tests of each button family of the kit at a squeezed width: the
/// button hides its caption and keeps its icon, and its name stays as its
/// accessibility label and as its tooltip (EditorKit `style.md`, "Buttons").
///
/// Each family is one of the button components of EditorKit: the action
/// button of a bar (``StatusBar``), the action buttons of a request card
/// (``ElicitationFooter``), and the bare toolbar button of a row of content
/// (``OutputCapRow``). The tests read the accessibility tree, which carries
/// the tooltip as the help of the element, never pixels or frames.
@Suite(.serialized, .hostedSerially) @MainActor struct SqueezedButtonHostedTests {
  /// A width that holds the icon of a button and not its caption, in points.
  static let squeezedWidth: CGFloat = 60

  /// The size of the hosted window: wider and taller than each view under
  /// test.
  static let windowSize = CGSize(width: 480, height: 320)

  /// The identifier of the button of the bar of the tests.
  static let barActionIdentifier = "squeezed-reload"

  /// The identifier of the text of the capped output row.
  static let capIdentifier = "squeezed-cap"

  /// The identifier of the Show All button of the capped output row.
  static let showAllIdentifier = "squeezed-show-all"

  /// The output of the capped row: more rows than its limit.
  static let cappedOutput = "one\ntwo\nthree\nfour"

  /// The row limit of the capped row.
  static let cappedRowLimit = 2

  /// Mounts `content` at ``squeezedWidth`` and renders it until the tooltip
  /// that a hidden caption sets has landed: the caption hides in one layout,
  /// and the tooltip follows in the next update.
  ///
  /// - Parameter content: The view under test.
  /// - Returns: The harness, which the test closes.
  static func mountSqueezed(_ content: some View) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(
      content.frame(width: squeezedWidth, alignment: .leading), size: windowSize)
    harness.render()
    harness.render()
    return harness
  }

  /// The accessibility element of the button with `identifier`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the button.
  ///   - harness: The harness that mounts it.
  /// - Returns: The element.
  /// - Throws: The issue of `#require` when no element has the identifier.
  static func button(
    _ identifier: String, in harness: HostedViewHarness<some View>
  ) throws -> AccessibilityElementSnapshot {
    try #require(harness.element(identifier: identifier))
  }

  /// A production change that fails this test: the button of a bar keeps a
  /// caption it has no room for, so the bar cuts it and sets no tooltip.
  @Test func aSqueezedBarButtonKeepsItsNameAsItsLabelAndItsTooltip() throws {
    let action = StatusBarFixtures.reloadAction(identifier: Self.barActionIdentifier)
    let harness = Self.mountSqueezed(
      StatusBar(message: StatusBarTests.message(.failure), action: action))
    defer { harness.close() }
    let element = try Self.button(Self.barActionIdentifier, in: harness)

    #expect(element.label == action.title)
    #expect(element.hint == action.title)
  }

  /// A production change that fails this test: an answer of a request card
  /// keeps a caption it has no room for, so the card cuts it and sets no
  /// tooltip.
  @Test func aSqueezedRequestActionKeepsItsNameAsItsLabelAndItsTooltip() throws {
    let footer = ElicitationFooter(
      context: ElicitationFooterContext(canSubmit: true, submit: {}, decline: {}, cancel: {}))
    let harness = Self.mountSqueezed(footer)
    defer { harness.close() }
    let element = try Self.button(ElicitationView.submitIdentifier, in: harness)

    #expect(element.label == "Submit")
    #expect(element.hint == "Submit")
  }

  /// A production change that fails this test: the bare button of a row of
  /// content keeps a caption it has no room for, so the row cuts it and sets
  /// no tooltip.
  @Test func aSqueezedRowButtonKeepsItsNameAsItsLabelAndItsTooltip() throws {
    let rows = CommandOutputView.VisibleRows(output: Self.cappedOutput, limit: Self.cappedRowLimit)
    let row = OutputCapRow(
      rows: rows, capIdentifier: Self.capIdentifier, showAllIdentifier: Self.showAllIdentifier, showAll: {})
    let harness = Self.mountSqueezed(row)
    defer { harness.close() }
    let element = try Self.button(Self.showAllIdentifier, in: harness)

    #expect(element.label == "Show all 4 lines")
    #expect(element.hint == "Show all 4 lines")
  }
}
