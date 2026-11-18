import EditorSwiftUI
import SwiftUI
import Testing

@testable import AgentViewKitStyle

/// The foreground of a ``PlacedLabel``: in content the theme role gives the
/// color, and on glass and chrome the label has the vibrant foreground of the
/// role (EditorKit `style.md`, rule 6, and D110).
@Suite @MainActor struct PlacedLabelTests {
  @Test func onGlassTheSecondaryLabelHasTheVibrantSecondaryForeground() {
    #expect(PlacedLabel.foreground(of: .secondary, isVibrant: true) == .vibrant(.secondary))
  }

  @Test func onGlassThePrimaryLabelHasTheVibrantPrimaryForeground() {
    #expect(PlacedLabel.foreground(of: .primary, isVibrant: true) == .vibrant(.primary))
  }

  @Test func inContentTheLabelKeepsTheThemeForeground() {
    #expect(PlacedLabel.foreground(of: .secondary, isVibrant: false) == .theme)
  }

  @Test func theStatusExplanationIsAPlacedLabel() {
    let layout = StatusTitleLayout(
      title: "Offline", explanation: "The agent stopped.", identifier: "status",
      symbol: { EmptyView() }, action: { EmptyView() })

    #expect(String(describing: type(of: layout.body)).contains("PlacedLabel"))
  }
}
