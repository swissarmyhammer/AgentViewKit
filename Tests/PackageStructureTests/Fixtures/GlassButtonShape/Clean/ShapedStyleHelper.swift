// A fixture for GlassButtonShapeTests. The package build excludes this file.
// The style helper has two glass styles. It counts as one style call, and its
// one caller sets the shape, so the scan must not report this file.
// .buttonStyle(.glass) in this comment does not count.
import SwiftUI

struct ShapedStyleHelper: View {
  var body: some View {
    Button(".buttonStyle(.glassProminent)") {}
      .actionStyle(isProminent: true)
      .buttonBorderShape(.circle)
  }
}

extension View {
  @ViewBuilder func actionStyle(isProminent: Bool) -> some View {
    if isProminent {
      self.buttonStyle(.glassProminent)
    } else {
      self.buttonStyle(.glass)
    }
  }
}
