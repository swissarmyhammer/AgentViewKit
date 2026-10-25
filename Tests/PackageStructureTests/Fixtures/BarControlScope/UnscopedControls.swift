// A fixture for ThreadBarControlScopeStructureTests. The package build excludes this file.
// The scan must report the button, the picker and the toggle with no scope.
import SwiftUI

struct UnscopedControls: View {
  @State private var isOn = false
  var body: some View {
    VStack {
      Button {
        isOn.toggle()
      } label: {
        Text("Button(") // a bracket in a literal
      }
      .buttonStyle(.glass)
      Picker("Mode", selection: $isOn) { Text("On").tag(true) }
        .pickerStyle(.segmented)
        .help("Mode")
      Toggle("On", isOn: $isOn)
      Button("Send") {}
        .buttonStyle(.glass)
        .agentControlScope("send")
    }
  }
}
