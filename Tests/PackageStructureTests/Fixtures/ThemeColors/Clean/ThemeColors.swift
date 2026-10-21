// A fixture for FixedColorTests. The package build excludes this file.
// The colors come from the theme, and the text on glass uses the vibrant
// foreground styles. Color.red, Color(red: full, green: none, blue: none),
// .foregroundColor( and Color(nsColor: are in this comment, so the scan must not report them.
import SwiftUI

/* NSColor.systemRed, UIColor.systemRed and windowBackgroundColor are in a
   block comment, so the scan must not report them. */
struct ThemeColors: View {
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    VStack {
      Text("Color.red").foregroundStyle(editorTheme.accent)
      Text("Color(white: half) on Color(.controlBackgroundColor)").foregroundStyle(.secondary)
      Text(#"NSColor.systemRed on underPageBackgroundColor"#).foregroundStyle(.tertiary)
      Text("""
        UIColor.systemRed, textBackgroundColor and .foregroundColor( are in a multi-line literal.
        """).foregroundStyle(.primary)
      Text("hue").background(editorTheme.selection)  // Color(hue: half)
    }
  }
}
