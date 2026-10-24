import AgentViewKit
import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The AgentViewKit demo app.
///
/// The app reads its launch arguments (``DemoLaunchOptions``) and shows one
/// window with a tab for each agent source. The menu bar mirrors the agent
/// commands of the scope that has the focus.
@main
struct AgentViewKitDemoApp: App {
  /// The top-level menus that the menu bar mirrors: the system File, Edit
  /// and View menus, and the Session menu of the agent commands.
  private static let menuPaths: [MenuPath] = [.file, .edit, .view, .session]

  /// The width of a new window, in points, when the screen is wide enough.
  /// It is more than the minimum widths of the sidebar and the detail of each
  /// tab.
  private static let preferredWindowWidth: CGFloat = 1100

  /// The height of a new window, in points, when the screen is tall enough.
  private static let preferredWindowHeight: CGFloat = 800

  /// The launch options of this process.
  private let options = DemoLaunchOptions()

  /// The one command system of the app. Each window installs it, so the agent
  /// command scopes register into it, and the menu bar reads it. SwiftUI's
  /// `Commands` cannot read the environment, so the app owns the system.
  @State private var commands = CommandSystem()

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
        .commandSystem(commands)
    }
    // With no placement, a new window takes the ideal size of its content,
    // which can be taller than the screen. A new window takes the preferred
    // size, and a zoomed window the visible part of the screen, so that the
    // composer and the request deck at the bottom of the window stay on the
    // screen.
    .defaultWindowPlacement { _, context in
      WindowPlacement(size: Self.newWindowSize(in: context.defaultDisplay.visibleRect))
    }
    .windowIdealSize(.maximum)
    .commands {
      EditorMenuCommands(commands, menuPaths: Self.menuPaths)
    }
  }

  /// The size of a new window: the preferred size, no larger than the
  /// visible part of the screen that the window opens on.
  ///
  /// - Parameter visibleRect: The visible rectangle of the screen, without
  ///   the menu bar and the Dock.
  /// - Returns: The size of the window.
  private static func newWindowSize(in visibleRect: CGRect) -> CGSize {
    CGSize(
      width: min(preferredWindowWidth, visibleRect.width),
      height: min(preferredWindowHeight, visibleRect.height))
  }
}
