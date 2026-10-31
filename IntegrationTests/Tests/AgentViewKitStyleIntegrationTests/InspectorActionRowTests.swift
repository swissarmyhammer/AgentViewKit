import AgentViewKitStyle
import EditorStyle
import SwiftUI
import Testing

/// Checks the row of the actions of an inspector through its public API.
@Suite @MainActor struct InspectorActionRowTests {
  /// The title of a button, long enough that a shown title widens the button.
  static let title = "A title that is much wider than one symbol"

  /// A button with ``title`` and a shared symbol.
  static var button: some View {
    Button(title, systemImage: SharedSymbol.reload) {}
  }

  @Test func theRowShowsOnlyTheSymbolOfAButton() {
    let row = StyleViewHost.fittingSize(of: InspectorActionRow { Self.button })
    let titled = StyleViewHost.fittingSize(of: Self.button)

    #expect(row.width < titled.width)
  }

  @Test func theRowPutsTheControlSpacingBetweenItsButtons() {
    let one = StyleViewHost.fittingSize(of: InspectorActionRow { Self.button })
    let two = StyleViewHost.fittingSize(
      of: InspectorActionRow {
        Self.button
        Self.button
      })

    #expect(two.width == 2 * one.width + EditorStyle.default.controlSpacing)
  }
}
