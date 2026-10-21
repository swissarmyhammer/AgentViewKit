// A fixture for GlassPlacementTests. The package build excludes this file.
// Two buttons use the prominent glass style, so the scan must report the
// second one too, with this file and its line.
import SwiftUI

struct TwoProminentActions: View {
  var body: some View {
    HStack {
      Button("Send") {}.buttonStyle(.glassProminent)
      Button("Stop") {}.buttonStyle(.glassProminent)
    }
  }
}
