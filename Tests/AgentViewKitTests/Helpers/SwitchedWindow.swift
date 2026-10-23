import AgentViewKitTestSupport
import EditorCommandsUI
import SwiftUI

/// The root of a ``SwitchedWindow``: its content while the switch is on,
/// under the command system that the windows of a test share.
///
/// The system stays installed when the switch goes off, so the teardown of
/// the content runs as SwiftUI removes the scopes of a window that closes.
struct SwitchedWindowRoot<Content: View>: View {
  /// The system that the windows of the test share.
  let system: CommandSystem

  /// The switch that shows and removes the content.
  let model: ScopeVisibilityModel

  /// The view of the window.
  let content: Content

  var body: some View {
    VStack {
      if model.isShown {
        content
      }
    }
    .commandSystem(system)
  }
}

/// One off-screen window of a test with two windows that show scopes at the
/// same paths, as a host shows one view in a second window.
///
/// ``close()`` removes the content and then closes the window, as a person
/// closes a window. The other window's root view does not change, so SwiftUI
/// does not update it.
@MainActor struct SwitchedWindow<Content: View> {
  /// The switch that shows and removes the content.
  let model = ScopeVisibilityModel()

  /// The harness of the window.
  let harness: HostedViewHarness<SwitchedWindowRoot<Content>>

  /// Mounts `content` under `system` and renders it once.
  ///
  /// - Parameters:
  ///   - content: The view of the window.
  ///   - system: The system that the windows of the test share.
  ///   - size: The size of the window.
  init(_ content: Content, system: CommandSystem, size: CGSize) {
    harness = HostedViewHarness(
      SwitchedWindowRoot(system: system, model: model, content: content), size: size)
    harness.render()
  }

  /// Removes the content, closes the window, and waits for the next pass of
  /// the main run loop, where the hand-back of a shared path runs.
  func close() async {
    model.isShown = false
    harness.render()
    harness.close()
    await RunLoopBlockFence.afterPendingBlocks()
  }
}
