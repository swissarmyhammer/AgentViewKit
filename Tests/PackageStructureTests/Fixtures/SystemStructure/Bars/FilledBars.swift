// A fixture for SystemStructureTests. The package build excludes this file.
// The content of each bar has one `.background(` fill, so the bar scan must
// count one fill in each bar.
import SwiftUI

struct FilledBars: View {
  var body: some View {
    List {}
      .safeAreaBar(edge: .top) {
        Text("Header")
          .background(Color.red)
      }
      .safeAreaBar(edge: .bottom) { floatingControls }
  }

  /// The content of the bottom bar.
  private var floatingControls: some View {
    Text("Composer")
      .background(.tint)
  }
}
