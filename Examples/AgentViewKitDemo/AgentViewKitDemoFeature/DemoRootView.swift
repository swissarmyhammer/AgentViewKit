import SwiftUI

/// The root view of the demo window: the ACP tab, and the Gallery tab of
/// the recorded sessions.
///
/// The app opens on the tab of the `--tab` launch argument, or on the ACP
/// tab.
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
      Tab(GalleryTabView.title, systemImage: "square.grid.2x2", value: .gallery) {
        GalleryTabView(options: options)
      }
    }
  }
}
