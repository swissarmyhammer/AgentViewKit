// A fixture for FixedColorTests. The package build excludes this file.
// The colors come from the theme, and the text on glass uses the vibrant
// foreground styles. Color.red, Color(red: full, green: none, blue: none)
// and .foregroundColor( are in this comment, so the scan must not report them.
import SwiftUI

/* NSColor.systemRed and UIColor.systemRed are in a block comment,
   so the scan must not report them. */
struct ThemeColors: View {
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    VStack {
      Text("Color.red").foregroundStyle(editorTheme.accent)
      Text("Color(white: half)").foregroundStyle(.secondary)
      Text(#"NSColor.systemRed"#).foregroundStyle(.tertiary)
      Text("""
        UIColor.systemRed and .foregroundColor( are in a multi-line literal.
        """).foregroundStyle(.primary)
      Text("hue").background(editorTheme.selection)  // Color(hue: half)
    }
  }
}
