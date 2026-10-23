// A fixture for ContentFillTests. The package build excludes this file.
// .agentContentSurface(), AgentContentSurface, statusBarBackground and
// tabBarBackground are in this comment, so the scan must not report them.
import SwiftUI

/* .background(.quaternary, in: Capsule()), RoundedRectangle(cornerRadius: radius).fill(.quaternary)
   and .background(editorTheme.selection) are in a block comment, so the scan
   must not report them. */
struct ContentFillInText: View {
  @Environment(\.editorTheme) private var editorTheme

  /// The corner radius of the edge of the fixture.
  let radius: Double

  var body: some View {
    VStack {
      Text(".background(.background.secondary, in: ConcentricRectangle())")
      Text(#"Capsule().fill(.tint) and .agentContentSurface()"#)
      Text("""
        .background(editorTheme.statusBarBackground) is in a multi-line literal.
        """)
      Text("edge")
        .overlay(Capsule().strokeBorder(.separator))  // Rectangle().fill(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .background(.selection)
        .foregroundStyle(editorTheme.accent)
    }
  }
}
