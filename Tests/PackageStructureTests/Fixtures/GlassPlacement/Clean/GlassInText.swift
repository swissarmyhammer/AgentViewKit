// A fixture for GlassPlacementTests. The package build excludes this file.
// .floatingGlassID(, .floatingGlass() and FloatingGlassContainer are in this
// comment, so the scan must not report them.
import SwiftUI

/* .buttonStyle(.glass) is in a block comment, so the scan must not report
   it. */
struct GlassInText: View {
  var body: some View {
    VStack {
      Text(#".floatingGlass()"#)
      Text("""
        FloatingGlassContainer( and .floatingGlassID( are in a multi-line literal.
        """)
      Button(".buttonStyle(.glass)") {}.buttonStyle(.bordered)  // .buttonStyle(.glass)
    }
  }
}
