import AgentViewKitStyle
import EditorStyle
import SwiftUI
import Testing

/// Checks one row of a completion list through its public API.
@Suite @MainActor struct CompletionRowTests {
  /// A row with no detail.
  static let row = CompletionRow(label: "Label", detail: nil, isSelected: false, identifier: "row")

  @Test func aDetailWidensTheRow() {
    let detailed = StyleViewHost.fittingSize(
      of: CompletionRow(label: "Label", detail: "Detail", isSelected: false, identifier: "row"))

    #expect(detailed.width > StyleViewHost.fittingSize(of: Self.row).width)
  }

  @Test func aSelectedRowHasTheSizeOfARowThatIsNotSelected() {
    let selected = StyleViewHost.fittingSize(
      of: CompletionRow(label: "Label", detail: nil, isSelected: true, identifier: "row"))

    #expect(selected == StyleViewHost.fittingSize(of: Self.row))
  }

  @Test func theRowFillsTheWidthOfTheList() {
    let width = 2 * StyleViewHost.fittingSize(of: Self.row).width

    #expect(StyleViewHost.size(of: Self.row, width: width).width == width)
  }
}
