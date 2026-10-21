// A fixture for GlassButtonShapeTests. The package build excludes this file.
// The chip has a glass button style and no border shape, so the scan must
// report the style with this file and its line.
import SwiftUI

struct ChipWithoutShape: View {
  var body: some View {
    Button("Suggestion") {}
      .buttonStyle(.glass)
  }
}
