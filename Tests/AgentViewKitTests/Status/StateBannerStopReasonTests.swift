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

  /// Each stop reason that a test shows: the known reasons and one unknown
  /// reason.
  nonisolated static let shownReasons = knownReasons.map(\.0) + [customReason]

  /// Decodes an idle state update with a stop reason.
  ///
  /// - Parameter wireValue: The raw wire value of the stop reason.
  /// - Returns: The state update.
  /// - Throws: The decoding error.
  static func idleUpdate(stopReason wireValue: String) throws -> StateUpdate {
    let json = #"{"state": "idle", "stopReason": "\#(wireValue)"}"#
    return try JSONDecoder().decode(StateUpdate.self, from: Data(json.utf8))
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

    #expect(Set(messages.map(\.title)).count == messages.count)
    #expect(Set(messages.map(\.identifier)).count == messages.count)
  }
}
