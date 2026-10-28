import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Checks that each failure message of the kit names the failure severity,
/// so that its status bar shows the symbol with the error color of the
/// EditorKit theme, and that each other message is neutral, so that its
/// symbol has the `.secondary` style.
///
/// The error color is a status color of the theme (D112). The symbol of a
/// message that is not a failure is not the selection or the focus, so it
/// does not use the accent of the theme (card ^y2mrfxt).
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

  /// The three failure messages: a failed turn, the `_error` stop reason and a
  /// failed connection.
  static func failureMessages() throws -> [StatusBar.Message] {
    let failedTurn = StateBanner.message(for: try StateBannerStopReasonTests.idleUpdate(stopReason: "error"))
    let failedConnection = try #require(AgentConnectionBanner.makeMessage(for: .failed(ConnectionFailure())))
    return [failedTurn, StateBanner.message(forUnknownStopReason: "_error"), failedConnection]
  }

  /// Messages that are not failures: a running agent, a complete turn and a
  /// closed session.
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
