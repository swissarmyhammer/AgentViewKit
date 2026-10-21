// A fixture for ThemeInjectionTests. The package build excludes this file.
// .tint(.blue), .regular.tint(accent), .foregroundStyle(.tint),
// .foregroundStyle(editorTheme.accent), .editorTheme(.system),
// DefaultTheme.dark and struct OwnTheme: Theme { are in this comment, so the
// scan must not report them.
import SwiftUI

/* glass.tint(accent), .environment(\.editorTheme, theme) and
   Color.accentColor are in a block comment, so the scan must not report
   them. */
struct ThemeInText: View {
  @Environment(\.editorTheme) private var editorTheme

  /// The severity of the notice of the fixture.
  let severity: NoticeSeverity

  var body: some View {
    VStack {
      Text(".tint(.blue) and .regular.tint(accent)")
      Text(#".foregroundStyle(.tint) and .foregroundStyle(editorTheme.accent)"#)
      Text("""
        .editorTheme(.system), DefaultTheme.dark and struct OwnTheme: Theme {
        are in a multi-line literal.
        """)
      StatusSymbolImage(name: "bell", color: editorTheme.tint(for: severity))
      Tick(tint: editorTheme.statusRunning)  // .foregroundStyle(.tint)
        .foregroundStyle(.secondary)
    }
  }
}
