// A fixture for GlassPlacementTests. The package build excludes this file.
// .glassEffect(, .glassEffectID(, .floatingGlassID(, .floatingGlass(),
// GlassEffectContainer and FloatingGlassContainer are in this comment, so the
// scan must not report them.
import SwiftUI

/* .buttonStyle(.glass) and .buttonStyle(.glassProminent) are in a block
   comment, so the scan must not report them. */
struct GlassInText: View {
  var body: some View {
    VStack {
      Text(".glassEffect(.regular)")
      Text(#".floatingGlass()"#)
      Text("""
        GlassEffectContainer and FloatingGlassContainer( are in a multi-line literal.
        """)
      Button(".buttonStyle(.glassProminent)") {}.buttonStyle(.bordered)  // .buttonStyle(.glass)
    }
  }
}
