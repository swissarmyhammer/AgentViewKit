import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks that a status bar animates the symbol of a message only while the
/// work of the message goes on: a running turn, or a history that loads
/// again.
@Suite @MainActor struct StatusBarEffectTests {
  /// The messages of work that goes on: the running banner and the replaying
  /// banner.
  static func ongoingMessages() throws -> [StateBanner.Message] {
    [
      StateBanner.message(for: try StateBannerStopReasonTests.decodeState(#"{"state": "running"}"#)),
      SessionStreamBanner.replayingMessage,
    ]
  }

  /// Messages of work that does not go on: a complete turn, a cancelled turn,
  /// a request to the user, a failed turn and the other session stream
  /// banners.
  static func settledMessages() throws -> [StateBanner.Message] {
    [
      StateBanner.message(for: try StateBannerStopReasonTests.idleUpdate(stopReason: "end_turn")),
      StateBanner.message(for: try StateBannerStopReasonTests.idleUpdate(stopReason: "cancelled")),
      StateBanner.message(for: try StateBannerStopReasonTests.idleUpdate(stopReason: "error")),
      StateBanner.message(for: try StateBannerStopReasonTests.decodeState(#"{"state": "requires_action"}"#)),
      SessionStreamBanner.closedMessage,
      SessionStreamBanner.missedUpdatesMessage,
      SessionStreamBanner.partialHistoryMessage,
    ]
  }

  @Test func eachOngoingMessageAnimatesItsSymbol() throws {
    for message in try Self.ongoingMessages() {
      #expect(message.isOngoing, "\(message.identifier)")
    }
  }

  @Test func noSettledMessageAnimatesItsSymbol() throws {
    for message in try Self.settledMessages() {
      #expect(!message.isOngoing, "\(message.identifier)")
    }
  }
}
