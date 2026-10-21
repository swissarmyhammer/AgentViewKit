// A fixture for SystemStructureTests. The package build excludes this file.
// Each code line in the stack uses one form that puts a custom background on
// the system structure, or that extends a view under the sidebar, so the scan
// must report each one, with this file and its line.
import AppKit
import SwiftUI

struct CustomBackgrounds: View {
  var body: some View {
    VStack {
      Text("toolbar").toolbarBackground(Color.red, for: .windowToolbar)
      Text("visibility").toolbarBackgroundVisibility(.visible, for: .windowToolbar)
      Text("container").containerBackground(Color.red, for: .navigation)
      Text("sheet").presentationBackground(Color.red)
      EffectHost(view: NSVisualEffectView())
      Text("ultra thin").background(.ultraThinMaterial)
      Text("thin").background(.thinMaterial)
      Text("regular").background(.regularMaterial)
      Text("thick").background(.thickMaterial)
      Text("ultra thick").background(.ultraThickMaterial)
      Text("bar").background(.bar)
      Image("hero").backgroundExtensionEffect()
    }
  }
}

/// Holds an AppKit view in this fixture.
struct EffectHost: View {
  /// The AppKit view.
  let view: NSView

  var body: some View { EmptyView() }
}
