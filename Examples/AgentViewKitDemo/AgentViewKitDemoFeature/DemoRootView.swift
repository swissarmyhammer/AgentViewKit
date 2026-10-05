import SwiftUI

/// The root view of the demo window: one tab for each agent source.
///
/// The app opens on the ACP tab.
struct DemoRootView: View {
  /// The launch options of the app.
  let options: DemoLaunchOptions

  /// The selected tab.
  @State private var selectedTab = DemoTab.acp

  /// Makes the root view.
  ///
  /// - Parameter options: The launch options of the app.
  init(options: DemoLaunchOptions) {
    self.options = options
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("ACP", systemImage: "point.3.connected.trianglepath.dotted", value: .acp) {
        ACPTabView(options: options)
      }
    }
  }
}
