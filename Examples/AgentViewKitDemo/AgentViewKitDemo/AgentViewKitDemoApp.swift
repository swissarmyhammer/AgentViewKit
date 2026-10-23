import AgentViewKit
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The AgentViewKit demo app.
///
/// The app reads its launch arguments (``DemoLaunchOptions``) and shows one
/// window with a tab for each agent source.
@main
struct AgentViewKitDemoApp: App {
  /// The launch options of this process.
  private let options = DemoLaunchOptions()

  /// Makes the app and registers the code block grammars, so that the first
  /// code block does not wait for the load.
  init() {
    GrammarBundle.register()
  }

  var body: some Scene {
    WindowGroup("AgentViewKit Demo") {
      DemoRootView(options: options)
        // Every color of the kit views comes from this EditorKit theme. A
        // host can give an imported Zed or VS Code theme here.
        .editorTheme(.system)
    }
    // The ideal size of the first content is too small for the bars of the
    // ACP tab (see DemoWindowLayout).
    .defaultSize(DemoWindowLayout.defaultSize)
  }
}
