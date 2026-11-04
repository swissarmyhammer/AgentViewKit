import AgentViewKitTestSupport
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks that each failure message of the kit names the failure severity,
/// so that its status bar shows the symbol with the error color of the
/// EditorKit theme, that each warning message names the warning severity, so
/// that its symbol has the warning color, and that each other message is
/// neutral, so that its symbol has the `.secondary` style.
///
/// The error and warning colors are severity tokens of the theme (D112),
/// which the EditorKit tone of the severity reads. No symbol of a status
/// message is the selection or the focus, so none uses the accent of the
/// theme (card ^y2mrfxt).
@Suite @MainActor struct StatusBarColorTests {
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
      #expect(message.severity.tone == .warning, "\(message.identifier)")
    }
  }

  @Test func eachOtherMessageIsNeutral() throws {
    #expect(try Self.otherMessages().allSatisfy { $0.severity == .neutral })
  }

  @Test func aFailureBarTintsItsSymbolWithTheErrorColor() throws {
    for message in try Self.failureMessages() {
      #expect(message.severity.tone == .error, "\(message.identifier)")
    }
  }

  @Test func aBarThatIsNotAFailureShowsItsSymbolWithTheSecondaryStyle() throws {
    for message in try Self.otherMessages() {
      #expect(message.severity.tone == .neutral, "\(message.identifier)")
    }
  }

  @Test func eachNoticeSeverityGivesTheSeverityOfItsBar() {
    let severities: [(NoticeSeverity, StatusBar.Message.Severity)] = [
      (.info, .information), (.warning, .warning), (.error, .failure), (.unknown("custom"), .information),
    ]

    for (notice, bar) in severities {
      #expect(StatusBar.Message.Severity(notice: notice) == bar, "\(notice)")
    }
  }
}
