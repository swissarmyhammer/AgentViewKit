// A fixture for GlassPlacementTests. The package build excludes this file.
// The first code line in the stack names the regular glass. Each other code
// line in the stack makes a glass that does not name it, so the variant scan
// must report each other line, with this file and its line.
import SwiftUI

struct GlassVariants: View {
  var body: some View {
    VStack {
      Text("regular").glassEffect(.regular, in: .capsule)
      Text("clear").glassEffect(.clear, in: .capsule)
      Text("no variant").glassEffect(in: .capsule)
    }
  }
}
