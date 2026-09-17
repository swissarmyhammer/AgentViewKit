import SwiftUI

/// The root view of the demo window: one tab for each agent source.
///
/// The ACP tab is here. The FoundationModels tab comes in its own task.
struct DemoRootView: View {
  /// The launch options of the app.
  let options: DemoLaunchOptions

  var body: some View {
    TabView {
      Tab("ACP", systemImage: "point.3.connected.trianglepath.dotted") {
        ACPTabView(options: options)
      }
    }
  }
}
