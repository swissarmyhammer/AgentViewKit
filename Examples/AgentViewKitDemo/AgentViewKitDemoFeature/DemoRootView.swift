import SwiftUI

/// The root view of the demo window: one tab for each agent source.
///
/// The app opens on ``DemoLaunchOptions/initialTab``.
struct DemoRootView: View {
  /// The launch options of the app.
  let options: DemoLaunchOptions

  /// The selected tab.
  @State private var selectedTab: DemoTab

  /// Makes the root view.
  ///
  /// - Parameter options: The launch options of the app.
  init(options: DemoLaunchOptions) {
    self.options = options
    _selectedTab = State(initialValue: options.initialTab)
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("ACP", systemImage: "point.3.connected.trianglepath.dotted", value: .acp) {
        ACPTabView(options: options)
      }
      Tab("FoundationModels", systemImage: "apple.intelligence", value: .foundationModels) {
        FoundationModelsTabView(options: options)
      }
    }
  }
}
