@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import Testing

/// Tests that ``DefaultPromptAccessory`` has no prominent action.
///
/// The accent is only for the selection and the focus (the user decision of
/// 2026-10-24, card ^k06v4gt). A prominent button style gives the accent
/// tint, so Send and Stop each use the `.glass` style, while the agent runs
/// and while it is idle.
///
/// The pixel tests capture a real window from the window server
/// (``GlassRenderProbeTests``), which shows Liquid Glass, but a capture cannot
/// tell `.glass` from a prominent glass style with no tint. Thus a scan of the
/// source makes sure that each button writes the `.glass` style.
/// ``GlassPlacementTests`` checks that `Input/` has no prominent glass style.
/// No test reads a clock, polls, or has a time limit.
@MainActor struct ComposerProminentActionTests {
  /// The path of the source of the accessory row, relative to the package
  /// root.
  static let accessoryPath = "Sources/AgentViewKit/Input/DefaultPromptAccessory.swift"

  /// The number of buttons of the accessory row with a glass style of their
  /// own: Send and Stop.
  static let glassButtonCount = 2

  /// The lines of the source of the accessory row that match `pattern`.
  ///
  /// - Parameter pattern: The pattern of the source text.
  /// - Returns: The lines that match.
  /// - Throws: An error when the pattern is not valid or the file cannot be
  ///   read.
  static func accessoryLines(matching pattern: String) throws -> [String] {
    try SourceLines.matching(Regex(pattern), inPackageFiles: [accessoryPath])
  }

  // MARK: - The source

  @Test func sendAndStopEachUseTheGlassButtonStyle() throws {
    let glass = try Self.accessoryLines(matching: #"\.buttonStyle\(\s*\.glass\s*\)"#)

    #expect(glass.count == Self.glassButtonCount, "\(glass)")
  }

  // MARK: - The commands

  @Test func thePaletteShowsTheSendCommandAndTheCancelCommandWhileTheAgentRuns() {
    let session = CancelFixtures.makeSession(state: CancelAvailabilityTests.running)
    let fixture = AgentCommandsTests.makeFixture(session: session)

    let paletteIDs = Set(fixture.system.registry.eligible(path: fixture.path).filter(\.isVisible).map(\.id))

    #expect(paletteIDs.isSuperset(of: [AgentCommandVerb.send.id, AgentCommandVerb.cancel.id]))
  }
}
