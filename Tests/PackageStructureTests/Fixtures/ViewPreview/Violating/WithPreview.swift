// A fixture for ViewPreviewTests. The package build excludes this file.
// The file declares a view and has a #Preview, so the scan must not report it.
import SwiftUI

public struct Badge: View {
  public var body: some View { Text("Badge") }
}

#Preview("Badge") {
  Badge()
}
