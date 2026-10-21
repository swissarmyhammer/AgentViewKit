// A fixture for ContentFillTests. The package build excludes this file.
// Each code line in the stack puts a custom fill behind content, so the scan
// must report each one, with this file and the line where the fill starts.
import SwiftUI

struct ContentCards: View {
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    VStack {
      Text("card").background(.background.secondary, in: ConcentricRectangle(corners: .concentric))
      Text("panel").background(RoundedRectangle(cornerRadius: Radius.card).fill(.quaternary))
      RoundedRectangle(cornerRadius: Radius.card).fill(.background.secondary)
      Text("surface").agentContentSurface()
      Text("surface type").modifier(AgentContentSurface())
      Text("status").background(editorTheme.statusBarBackground)
      Divider().overlay(editorTheme.tabBarBackground)
      Text("gutter").foregroundStyle(editorTheme.gutterBackground)
      Text("theme").background(editorTheme.selection.opacity(Opacity.card))
      Text("header")
        .background(
          .quaternary,
          in: AgentSurface.shape(radius: Radius.card))
      Text("chip").background(
        Capsule()
          .fill(.tint))
    }
  }
}

/// The radii of this fixture.
enum Radius {
  /// The radius of a card.
  static let card = 8.0
}

/// The opacities of this fixture.
enum Opacity {
  /// The opacity of the fill of a card.
  static let card = 0.2
}
