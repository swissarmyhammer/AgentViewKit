import AgentViewKit
import Foundation
import FoundationModelsACP
import Testing

/// Tests of the bar for the extension stop reasons that an agent sends
/// (plan.md §3.8 "Agent state and stop reasons").
@Suite @MainActor struct StateBannerStopReasonTests {
  /// Each extension stop reason of the FoundationModels ACP agent, with the
  /// title that the bar must show for it.
  nonisolated static let knownReasons: [(String, String)] = [
    ("_truncated", "The response was cut off"),
    ("_ended_in_reasoning", "The model stopped during its reasoning"),
    ("_repeated", "The model repeated itself"),
    ("_reasoning_limit", "The reasoning was too long"),
    ("_error", "The agent had an error"),
    ("_no_output", "The model gave no answer"),
    ("_stalled", "The response stopped"),
  ]

  /// A stop reason that no agent of the kit sends.
  nonisolated static let customReason = "_custom"

  /// The ACP stop reason of a turn that failed (schema alpha.8).
  nonisolated static let errorReason = "error"

  /// The title of the bar for the ACP stop reason `error`.
  nonisolated static let failedTurnTitle = "The response failed"

  /// The `message` of the idle error object in the failure tests.
  nonisolated static let idleErrorMessage = "The model server closed the connection."

  /// The ACP stop reason of a response that used its maximum number of model
  /// requests.
  nonisolated static let maxTurnRequestsReason = "max_turn_requests"

  /// Each stop reason that a test shows: the known reasons, one unknown
  /// reason, and the ACP stop reasons `error` and `max_turn_requests`.
  nonisolated static let shownReasons = knownReasons.map(\.0) + [customReason, errorReason, maxTurnRequestsReason]

  /// Decodes an idle state update with a stop reason.
  ///
  /// - Parameter wireValue: The raw wire value of the stop reason.
  /// - Returns: The state update.
  /// - Throws: The decoding error.
  static func idleUpdate(stopReason wireValue: String) throws -> StateUpdate {
    try decodeState(#"{"state": "idle", "stopReason": "\#(wireValue)"}"#)
  }

  /// Decodes a state update.
  ///
  /// - Parameter json: The JSON text of the update.
  /// - Returns: The state update.
  /// - Throws: The decoding error.
  static func decodeState(_ json: String) throws -> StateUpdate {
    try JSONDecoder().decode(StateUpdate.self, from: Data(json.utf8))
  }

  @Test func theErrorReasonWithNoErrorObjectShowsTheFailedTurnBar() throws {
    let message = StateBanner.message(for: try Self.idleUpdate(stopReason: Self.errorReason))

    #expect(message.title == Self.failedTurnTitle)
    #expect(message.identifier == StateBanner.failedTurnIdentifier)
    #expect(!message.explanation.isEmpty)
  }

  @Test func theErrorReasonShowsTheMessageOfTheIdleErrorObject() throws {
    let state = try Self.decodeState(
      #"{"state": "idle", "stopReason": "error", "error": {"code": -32603, "message": "\#(Self.idleErrorMessage)"}}"#)

    let message = StateBanner.message(for: state)

    #expect(message.title == Self.failedTurnTitle)
    #expect(message.identifier == StateBanner.failedTurnIdentifier)
    #expect(message.explanation.contains(Self.idleErrorMessage))
  }

  @Test(arguments: knownReasons)
  func eachKnownExtensionReasonShowsItsOwnText(wireValue: String, title: String) throws {
    let message = StateBanner.message(for: try Self.idleUpdate(stopReason: wireValue))

    #expect(message.title == title)
    #expect(message == StateBanner.extensionStopReasonMessages[wireValue])
  }

  @Test func theTableHoldsTheSevenKnownReasonsAndNoOther() {
    #expect(Set(StateBanner.extensionStopReasonMessages.keys) == Set(Self.knownReasons.map(\.0)))
  }

  @Test func anUnknownReasonShowsTheGeneralBarWithTheRawValue() throws {
    let message = StateBanner.message(for: try Self.idleUpdate(stopReason: Self.customReason))

    #expect(message.identifier == StateBanner.unknownStopReasonIdentifier)
    #expect(message.explanation.contains(Self.customReason))
    #expect(StateBanner.extensionStopReasonMessages[Self.customReason] == nil)
  }

  @Test func eachStopReasonBarHasADistinctTitleAndIdentifier() throws {
    let messages = try Self.shownReasons.map {
      StateBanner.message(for: try Self.idleUpdate(stopReason: $0))
    }

    NameChecks.expectDistinctNames(messages.map(\.title))
    NameChecks.expectDistinctNames(messages.map(\.identifier))
  }
}
