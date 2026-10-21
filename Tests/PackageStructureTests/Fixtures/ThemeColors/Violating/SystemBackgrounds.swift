// A fixture for FixedColorTests. The package build excludes this file.
// Each code line in the stack uses one system background form, so the scan
// must report each one, with this file and its line.
import SwiftUI

struct SystemBackgrounds: View {
  /// An AppKit color of a panel. Its name has no system background name.
  let panelColor: NSColor

  var body: some View {
    VStack {
      Text("window").background(Color(nsColor: .windowBackgroundColor))
      Text("control").background(Color(.controlBackgroundColor))
      Text("text").background(Color(nsColor: .textBackgroundColor))
      Text("page").background(Color(nsColor: .underPageBackgroundColor))
      Text("appkit").background(Color(nsColor: panelColor))
      Text("platform").background(Color(.quaternarySystemFill))
    }
  }
}
