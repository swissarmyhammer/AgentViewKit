// A fixture for FixedColorTests. The package build excludes this file.
// Each code line in the stack uses one fixed color form, so the scan must
// report each one, with this file and its line.
import SwiftUI

struct FixedColors: View {
  var body: some View {
    VStack {
      Text("named").background(Color.red)
      Text("rgb").background(Color(red: 1, green: 0, blue: 0))
      Text("white").background(Color(white: 0.5))
      Text("hue").background(Color(hue: 0.5, saturation: 1, brightness: 1))
      Text("appkit").background(Color(nsColor: NSColor.systemRed))
      Text("uikit").background(Color(uiColor: UIColor.systemRed))
      Text("modifier").foregroundColor(editorTheme.accent)
      Text("style").foregroundStyle(.blue)
    }
  }
}
