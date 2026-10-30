@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import Testing

/// Tests the commands of ``DefaultPromptAccessory`` while the agent runs.
///
/// No test reads a clock, polls, or has a time limit.
@MainActor struct ComposerProminentActionTests {
  // MARK: - The commands

  @Test func thePaletteShowsTheSendCommandAndTheCancelCommandWhileTheAgentRuns() {
    let session = CancelFixtures.makeSession(state: CancelAvailabilityTests.running)
    let fixture = AgentCommandsTests.makeFixture(session: session)

    let paletteIDs = Set(fixture.system.registry.eligible(path: fixture.path).filter(\.isVisible).map(\.id))

    #expect(paletteIDs.isSuperset(of: [AgentCommandVerb.send.id, AgentCommandVerb.cancel.id]))
  }
}
