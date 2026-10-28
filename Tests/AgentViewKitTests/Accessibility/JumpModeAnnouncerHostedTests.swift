@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// A hosted test of the one announcement path of a host (EditorKit ^gfv7042).
///
/// A host sets the environment value `announcer` above `.commandSystem(_:)`.
/// The command system gives that announcer to its overlays, so jump mode in a
/// thread announces through the same announcer as the views of the kit.
@Suite(.serialized, .hostedSerially) @MainActor struct JumpModeAnnouncerHostedTests {
  /// The size of the host window.
  static let windowSize = CGSize(width: 480, height: 600)

  @Test func jumpModeInAThreadAnnouncesThroughTheAnnouncerAboveTheCommandSystem() throws {
    let session = SessionModel.preview()
    let system = CommandSystem()
    let announcer = RecordingAnnouncer()
    let harness = HostedViewHarness(size: Self.windowSize) {
      AgentThreadView(session: session)
        .commandSystem(system)
        .environment(\.announcer, announcer)
    }
    defer { harness.close() }
    harness.render()
    let jump = JumpModeController(system: system)

    try #require(jump.activate(layer: AgentCommandScopeHostedTests.path(of: session)))

    let targetCount = try #require(jump.overlayState?.jumpState.candidates.count)
    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(
          message: JumpModeAnnouncement.activated(targetCount: targetCount), priority: .high)
      ])
  }
}
