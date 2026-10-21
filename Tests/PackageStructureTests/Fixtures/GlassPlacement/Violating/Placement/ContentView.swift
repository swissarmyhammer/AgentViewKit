// A fixture for GlassPlacementTests. The package build excludes this file.
// Each code line in the stack uses one glass form outside its allowed files,
// so the scan must report each one, with this file and its line.
import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack {
      Text("effect").glassEffect(.regular, in: .capsule)
      Text("floating").agentFloatingGlass()
      GlassEffectContainer { Text("container") }
      FloatingGlassContainer(spacing: Spacing.small) { Text("shared") }
      Button("Open") {}.buttonStyle(.glass)
      Text("morph").glassEffectID(Spacing.small, in: namespace)
    }
  }

  @Namespace private var namespace
}

/// The spacing of the stack in this fixture.
enum Spacing {
  /// The small spacing of the stack.
  static let small = 8.0
}
