// A fixture for ThemeInjectionTests. The package build excludes this file.
// Each code line in the stack uses a tint, a prominent button style, the
// theme accent or a theme of its own, so the scan must report each one, with
// this file and the line where the form starts.
import SwiftUI

struct TintAndTheme: View {
  @Environment(\.editorTheme) private var editorTheme
  let accent: Color

  var body: some View {
    VStack {
      Text("tint").tint(.blue)
      Text("glass").glassEffect(.regular.tint(accent), in: .capsule)
      Text("style").foregroundStyle(.tint)
      Text("accent").foregroundStyle(editorTheme.accent)
      Text("theme").editorTheme(.system)
      Text("next line")
        .tint(
          .blue)
    }
  }

  /// A theme of the fixture's own.
  let ownTheme = DefaultTheme.dark
}

struct OwnTheme: Theme {
}

struct ProminentActions: View {
  var body: some View {
    Button("Send") {}.buttonStyle(.glassProminent)
    Button("Allow") {}.buttonStyle(.borderedProminent)
  }
}
