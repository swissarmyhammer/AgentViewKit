import AppKit
import EditorCommands
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The accessibility label of the row elements of an ``AgentRowList``
/// (``AgentRowList/rowAccessibilityLabel(_:)``, Testudo 2026-11-20).
@MainActor @Suite struct AgentRowListRowLabelTests {
  /// The scope of the list of the tests.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "labelList"), rowKind: "labelRow")

  /// The size of the hosting view of the tests that read the accessibility
  /// tree.
  static let hostSize = CGSize(width: 320, height: 200)

  /// A list of two rows, with no row label.
  static var list: AgentRowList<String, Text, EmptyView> {
    AgentRowList(["first", "second"], id: \.self, scope: scope) { id in Text(verbatim: id) }
  }

  @Test func aListWithNoRowLabelGivesNoLabel() {
    #expect(Self.list.rowLabel == nil)
  }

  @Test func theRowLabelOfAnItemIsTheLabelThatTheHostGives() {
    let list = Self.list.rowAccessibilityLabel { id in Text(verbatim: "Row \(id)") }

    #expect(list.rowLabel?("second") == Text(verbatim: "Row second"))
  }

  @Test func aRowWrapperKeepsTheRowLabel() {
    let list = Self.list
      .rowAccessibilityLabel { id in Text(verbatim: "Row \(id)") }
      .wrappingRows { row, _ in row }

    #expect(list.rowLabel?("first") == Text(verbatim: "Row first"))
  }

  /// A production change that fails this test: the row element of a list
  /// with no row label has no label, and does not take the text of its
  /// content.
  @Test func aRowElementWithNoRowLabelHasTheTextOfItsContent() async {
    let label = await Self.label(ofRow: "first", in: Self.list)

    #expect(label == "first")
  }

  /// A production change that fails this test: the text of the content
  /// takes the place of the row label that the host gives.
  @Test func aRowElementWithARowLabelHasThatLabel() async {
    let list = Self.list.rowAccessibilityLabel { id in Text(verbatim: "Row \(id)") }

    let label = await Self.label(ofRow: "first", in: list)

    #expect(label == "Row first")
  }

  /// The accessibility label of the row element of `id`, read from a hosting
  /// view with no window, so the test shows no window and takes no focus.
  ///
  /// - Parameters:
  ///   - id: The id of the row.
  ///   - list: The list to lay out.
  /// - Returns: The label, or `nil` when no single row element has the
  ///   identifier of the row, or the element has no label.
  static func label(ofRow id: String, in list: some View) async -> String? {
    let hosting = NSHostingView(
      rootView: list.frame(width: hostSize.width, height: hostSize.height))
    hosting.frame = NSRect(origin: .zero, size: hostSize)
    hosting.layoutSubtreeIfNeeded()
    return await withAccessibilityTree {
      let elements = accessibilityElements(
        identifiedAs: scope.rowIdentifier(for: id), under: hosting, includingScrollAreas: true)
      return elements.count == 1 ? elements.first.flatMap(accessibilityLabel(of:)) : nil
    }
  }
}
