import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The row element of an ``AgentRowList`` has the label that the host gives
/// with ``AgentRowList/rowAccessibilityLabel(_:)``, or else the text of its
/// content, so VoiceOver and a UI test read the row by its name (Testudo,
/// 2026-11-20).
///
/// A production change that fails these tests: the label goes on the content
/// of the row and not on the row element, which contains the content, or a
/// row element with no host label has no label.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListRowLabelHostedTests {
  /// The size of the host window.
  static let windowSize = CGSize(width: 320, height: 200)

  /// The scope of the list.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "labelList"), rowKind: "labelRow")

  /// The ids of the rows.
  static let ids = ["first", "second"]

  /// The label that the host gives to the row of `id`.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: The label.
  static func label(of id: String) -> String {
    "Row \(id)"
  }

  /// Shows the list, with a row label when `labelsRows` is `true`.
  ///
  /// - Parameter labelsRows: Whether the host gives a row label.
  /// - Returns: The harness.
  static func mount(labelsRows: Bool) -> HostedViewHarness<some View> {
    HostedViewHarness(size: windowSize) {
      Group {
        if labelsRows {
          AgentRowList(ids, id: \.self, scope: scope) { id in Text(verbatim: id) }
            .rowAccessibilityLabel { id in Text(verbatim: label(of: id)) }
        } else {
          AgentRowList(ids, id: \.self, scope: scope) { id in Text(verbatim: id) }
        }
      }
      .commandSystem(CommandSystem())
    }
  }

  @Test func eachRowElementHasTheLabelThatTheHostGives() {
    let harness = Self.mount(labelsRows: true)
    defer { harness.close() }

    for id in Self.ids {
      #expect(
        harness.element(identifier: Self.scope.rowIdentifier(for: id))?.label == Self.label(of: id))
    }
  }

  @Test func theContentOfALabeledRowKeepsItsOwnElement() {
    let harness = Self.mount(labelsRows: true)
    defer { harness.close() }

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains(Self.label(of: Self.ids[0])))
    #expect(
      harness.accessibilityElements().contains {
        $0.label == Self.ids[0] || $0.value == Self.ids[0]
      })
  }

  @Test func aRowElementWithNoHostLabelHasTheTextOfItsContent() {
    let harness = Self.mount(labelsRows: false)
    defer { harness.close() }

    let label = harness.element(identifier: Self.scope.rowIdentifier(for: Self.ids[0]))?.label
    #expect(label == Self.ids[0])
  }
}
