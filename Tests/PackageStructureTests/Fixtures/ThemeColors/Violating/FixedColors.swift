// A fixture for FixedColorTests. The package build excludes this file.
// Each code line in the stack uses one fixed color form, so the scan must
// report each one, with this file and its line.
import SwiftUI

struct FixedColors: View {
  var body: some View {
    VStack {
      Text("named").background(Color.red)
      Text("rgb").background(Color(red: Channel.full, green: Channel.none, blue: Channel.none))
      Text("white").background(Color(white: Channel.half))
      Text("hue").background(Color(hue: Channel.half, saturation: Channel.full, brightness: Channel.full))
      Text("appkit").background(Color(nsColor: NSColor.systemRed))
      Text("uikit").background(Color(uiColor: UIColor.systemRed))
      Text("modifier").foregroundColor(editorTheme.accent)
      Text("style").foregroundStyle(.blue)
    }
  }
}

/// The fixed channel values of the colors in this fixture.
enum Channel {
  /// A channel with no value.
  static let none = 0.0

  /// A channel at half of its full value.
  static let half = 0.5

  /// A channel at its full value.
  static let full = 1.0
}
