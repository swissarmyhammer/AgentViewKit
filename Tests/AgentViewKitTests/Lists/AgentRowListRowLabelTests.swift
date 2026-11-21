import EditorCommands
import SwiftUI
import Testing

@testable import AgentViewKit

/// The accessibility label of the row elements of an ``AgentRowList``
/// (``AgentRowList/rowAccessibilityLabel(_:)``, Testudo 2026-11-20).
@MainActor @Suite struct AgentRowListRowLabelTests {
  /// The scope of the list of the tests.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "labelList"), rowKind: "labelRow")

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
}
