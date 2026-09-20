import SwiftUI

/// The AgentViewKit demo app.
///
/// The app reads its launch arguments (``DemoLaunchOptions``) and shows one
/// window with a tab for each agent source.
@main
struct AgentViewKitDemoApp: App {
  /// The launch options of this process.
  private let options = DemoLaunchOptions()

  var body: some Scene {
    WindowGroup("AgentViewKit Demo") {
      DemoRootView(options: options)
    }
  }
}
