import AgentViewKitStyle
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

/// Tests that a `FloatingGlassContainer` counts as glass for the text in it.
@Suite(.serialized, .hostedSerially) @MainActor struct PlacedSecondaryHostedTests {
  /// Records what its environment says about the place.
  private struct PlaceProbe: View {
    @Environment(\.showsVibrantText) private var showsVibrantText

    /// Takes the value of the environment.
    let record: (Bool) -> Void

    var body: some View {
      Color.clear.onAppear { record(showsVibrantText) }
    }
  }

  @Test func textInAFloatingGlassContainerKeepsTheVibrantStyles() {
    var recorded: Bool?
    let harness = HostedViewHarness(
      FloatingGlassContainer(spacing: .zero) { PlaceProbe { recorded = $0 } })
    defer { harness.close() }
    harness.render()
    #expect(recorded == true)
  }
}
