// readme:compile HostTheme
import AgentViewKit
import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// Gives the kit views in `content` one theme.
struct ThemedHost<Content: View>: View {
  /// The kit views to theme.
  @ViewBuilder let content: Content

  var body: some View {
    content
      // The layout tokens of the kit: spacing, radii, symbol weight, density.
      // The theme gives a style too. This one is closer to the content, so it
      // wins.
      .editorStyle(.default)
      // Every color and each font of the kit views come from this
      // EditorKit theme. `.system` follows the system appearance.
      .editorTheme(.system)
  }
}
