import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Checks that each failure message of the kit names the failure severity,
/// so that its status bar shows the symbol with the error color of the
/// EditorKit theme, that each warning message names the warning severity, so
/// that its symbol has the warning color, and that each other message is
/// neutral, so that its symbol has the `.secondary` style.
///
/// The error and warning colors are status colors of the theme (D112). No
/// symbol of a status message is the selection or the focus, so none uses
/// the accent of the theme (card ^y2mrfxt).
///
/// The tests give ``DistinctRolesTheme``, which has a different color for each
/// role, so each color names its role.
@Suite @MainActor struct StatusBarColorTests {
  /// The role colors of ``DistinctRolesTheme``.
  typealias Role = DistinctRolesTheme.Role

  /// A theme with a different color for each role.
  static let theme = DistinctRolesTheme()

  /// A failure of the connection to the agent.
  struct ConnectionFailure: Error {}

  /// The text of the error of a failed reload.
  static let reloadErrorDescription = "The agent has no history for this session."

  /// The four failure messages: a failed turn, the `_error` stop reason, a
  /// failed connection and a failed reload of the session stream.
  static func failureMessages() throws -> [StatusBar.Message] {
    let failedTurn = StateBanner.message(for: try StateBannerStopReasonTests.idleUpdate(stopReason: "error"))
    let failedConnection = try #require(AgentConnectionBanner.makeMessage(for: .failed(ConnectionFailure())))
    let failedReload = SessionStreamBanner.makeReloadFailedMessage(errorDescription: reloadErrorDescription)
    return [failedTurn, StateBanner.message(forUnknownStopReason: "_error"), failedConnection, failedReload]
  }

  /// The warning messages: the missed updates of the session stream, as the
  /// stream banner of KanbanViewKit shows them.
  static let warningMessages = [SessionStreamBanner.missedUpdatesMessage]

  /// Messages that are neither failures nor warnings: a running agent, a
  /// complete turn and a closed session.
  static func otherMessages() throws -> [StatusBar.Message] {
    [
      StateBanner.message(for: try StateBannerStopReasonTests.decodeState(#"{"state": "running"}"#)),
      StateBanner.message(for: try StateBannerStopReasonTests.idleUpdate(stopReason: "end_turn")),
      SessionStreamBanner.closedMessage,
    ]
  }

  @Test func eachFailureMessageNamesTheFailureSeverity() throws {
    #expect(try Self.failureMessages().allSatisfy { $0.severity == .failure })
  }

  @Test func theReloadFailedMessageExplainsTheErrorOfTheReload() {
    let message = SessionStreamBanner.makeReloadFailedMessage(errorDescription: Self.reloadErrorDescription)

    #expect(message.explanation.contains(Self.reloadErrorDescription))
  }

  @Test func eachWarningMessageNamesTheWarningSeverity() {
    #expect(Self.warningMessages.allSatisfy { $0.severity == .warning })
  }

  @Test func aWarningBarTintsItsSymbolWithTheWarningColor() {
    for message in Self.warningMessages {
      #expect(StatusBar.symbolColor(for: message, in: Self.theme) == Role.warning, "\(message.identifier)")
    }
  }

  @Test func eachOtherMessageIsNeutral() throws {
    #expect(try Self.otherMessages().allSatisfy { $0.severity == .neutral })
  }

  @Test func aFailureBarTintsItsSymbolWithTheErrorColor() throws {
    for message in try Self.failureMessages() {
      #expect(StatusBar.symbolColor(for: message, in: Self.theme) == Role.error, "\(message.identifier)")
    }
  }

  @Test func aBarThatIsNotAFailureShowsItsSymbolWithTheSecondaryStyle() throws {
    for message in try Self.otherMessages() {
      #expect(StatusBar.symbolColor(for: message, in: Self.theme) == Color.secondary, "\(message.identifier)")
    }
  }
}
