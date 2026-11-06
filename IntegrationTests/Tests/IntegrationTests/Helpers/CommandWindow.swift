import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import SwiftUI
import Testing

/// The window of one hosted test of scopes: the content of the bed under a
/// command system, in the harness window, which is never ordered in and
/// never key.
///
/// Each bed of rows mounts its content through this one mount, and reads the
/// system and the harness from it: the content is the scope of the window
/// and its rows, as each bed builds them, and the mount waits for the beacons
/// of the scopes that the bed names.
@MainActor struct CommandWindow {
  /// The command system of the window.
  let system: CommandSystem

  /// The harness that shows the window.
  let harness: HostedViewHarness<AnyView>

  /// Mounts `content` under `system`, lets SwiftUI land the updates of the
  /// mount, and waits for the beacon of each scope in `beacons`.
  ///
  /// - Parameters:
  ///   - system: The command system of the window. A bed passes its own when
  ///     it registers commands before the mount, or reads the system in its
  ///     content.
  ///   - size: The size of the window.
  ///   - beacons: The paths of the scopes whose beacons the mount waits for.
  ///   - content: The content of the window.
  /// - Throws: The error of `#require` when a beacon is not live in time.
  init(
    system: CommandSystem = CommandSystem(), size: CGSize = HostedViewHarness<AnyView>.defaultSize,
    beacons: [FocusPath] = [], @ViewBuilder content: () -> some View
  ) async throws {
    self.system = system
    harness = HostedViewHarness(AnyView(content().commandSystem(system)), size: size)
    await RunLoopBlockFence.afterPendingBlocks()
    try #require(waitForLiveBeacons(beacons, in: system))
  }
}
