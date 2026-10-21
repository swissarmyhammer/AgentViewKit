@testable import AgentViewKit
import EditorCommands
import FoundationModelsACPClient
import Testing

/// Tests for the one prominent action of ``DefaultPromptAccessory`` (D110 (c)).
///
/// Only one action of the composer is prominent at a time. While the agent
/// runs, Stop uses `.glassProminent` and Send uses `.glass`. While the agent is
/// idle, Send uses `.glassProminent`, and Stop, if it shows, uses `.glass`.
///
/// A render cannot show a glass button style, because the cache of a window
/// shows no glass (``GlassRenderProbeHostedTests``). Thus the tests read the
/// value that selects the style, and a scan of the source makes sure that each
/// button gets its style from that value. Each test makes a preview session
/// model in a fixed order and then asserts. No test reads a clock, polls, or
/// has a time limit.
@MainActor struct ComposerProminentActionTests {
  /// The styles of the two buttons of the accessory row.
  struct Styles: Equatable {
    /// The style of the Send button.
    let send: DefaultPromptAccessory.ActionStyle

    /// The style of the Stop button.
    let stop: DefaultPromptAccessory.ActionStyle
  }

  /// The styles while the agent runs: Stop is the prominent action.
  static let stopIsProminent = Styles(send: .glass, stop: .glassProminent)

  /// The styles while the agent is idle: Send is the prominent action.
  static let sendIsProminent = Styles(send: .glassProminent, stop: .glass)

  /// The path of the source of the accessory row, relative to the package
  /// root.
  static let accessoryPath = "Sources/AgentViewKit/Input/DefaultPromptAccessory.swift"

  /// The number of buttons of the accessory row that have an action style:
  /// Send and Stop.
  static let styledButtonCount = 2

  /// The styles of the two buttons for `session`.
  ///
  /// - Parameter session: The session model of the composer, or `nil`.
  /// - Returns: The style of each button.
  static func styles(for session: SessionModel?) -> Styles {
    Styles(
      send: DefaultPromptAccessory.style(of: .send, for: session),
      stop: DefaultPromptAccessory.style(of: .stop, for: session))
  }

  /// The lines of the source of the accessory row that match `pattern`.
  ///
  /// - Parameter pattern: The pattern of the source text.
  /// - Returns: The lines that match.
  /// - Throws: An error when the pattern is not valid or the file cannot be
  ///   read.
  static func accessoryLines(matching pattern: String) throws -> [String] {
    try SourceLines.matching(Regex(pattern), inPackageFiles: [accessoryPath])
  }

  // MARK: - The two states

  @Test func whileTheAgentRunsStopIsTheOneProminentAction() {
    let session = CancelAvailabilityTests.makeSession(state: CancelAvailabilityTests.running)

    #expect(Self.styles(for: session) == Self.stopIsProminent)
  }

  @Test func whileTheAgentIsIdleSendIsTheOneProminentAction() {
    let session = CancelAvailabilityTests.makeSession(state: CancelAvailabilityTests.idle)

    #expect(Self.styles(for: session) == Self.sendIsProminent)
  }

  @Test func anIdleSessionWithAPendingPermissionKeepsSendAsTheOneProminentAction() {
    let session = CancelAvailabilityTests.makeSession(
      state: CancelAvailabilityTests.idle, pendingPermissions: [CancelAvailabilityTests.permissionRequest])

    #expect(Self.styles(for: session) == Self.sendIsProminent)
  }

  @Test func withNoSessionSendIsTheOneProminentAction() {
    #expect(Self.styles(for: nil) == Self.sendIsProminent)
  }

  // MARK: - The source

  @Test func eachButtonGetsItsStyleFromTheProminentAction() throws {
    let styled = try Self.accessoryLines(matching: #"\.actionStyle\(\s*Self\.style\(of:"#)

    #expect(styled.count == Self.styledButtonCount, "\(styled)")
  }

  @Test func onlyTheActionStyleWritesAGlassButtonStyle() throws {
    let prominent = try Self.accessoryLines(matching: #"\.buttonStyle\(\s*\.glassProminent\s*\)"#)
    let glass = try Self.accessoryLines(matching: #"\.buttonStyle\(\s*\.glass\s*\)"#)

    #expect(prominent.count == 1, "\(prominent)")
    #expect(glass.count == 1, "\(glass)")
  }

  // MARK: - The commands

  @Test func thePaletteShowsTheSendCommandAndTheCancelCommandWhileTheAgentRuns() {
    let session = CancelAvailabilityTests.makeSession(state: CancelAvailabilityTests.running)
    let fixture = AgentCommandsTests.makeFixture(session: session)

    let paletteIDs = Set(fixture.system.registry.eligible(path: fixture.path).filter(\.isVisible).map(\.id))

    #expect(paletteIDs.isSuperset(of: [AgentCommandVerb.send.id, AgentCommandVerb.cancel.id]))
  }
}
