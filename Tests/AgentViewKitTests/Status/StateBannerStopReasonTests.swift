import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Tests of the bar for the extension stop reasons that an agent sends
/// (update.md §9.2).
@Suite(.serialized, .hostedSerially) @MainActor struct StateBannerStopReasonTests {
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

  /// Each stop reason that the hosted test shows: the known reasons and one
  /// unknown reason.
  nonisolated static let hostedReasons = knownReasons.map(\.0) + [customReason]

  @Test(arguments: knownReasons)
  func eachKnownExtensionReasonShowsItsOwnText(wireValue: String, title: String) throws {
    let message = try #require(StateBanner.message(for: .idle(StopReason(wireValue: wireValue))))

    #expect(message.title == title)
    #expect(message == StateBanner.extensionStopReasonMessages[wireValue])
  }

  @Test func theTableHoldsTheSevenKnownReasonsAndNoOther() {
    #expect(Set(StateBanner.extensionStopReasonMessages.keys) == Set(Self.knownReasons.map(\.0)))
  }

  @Test func anUnknownReasonShowsTheGeneralBarWithTheRawValue() throws {
    let message = try #require(
      StateBanner.message(for: .idle(StopReason(wireValue: Self.customReason))))

    #expect(message.identifier == StateBanner.unknownStopReasonIdentifier)
    #expect(message.explanation.contains(Self.customReason))
    #expect(StateBanner.extensionStopReasonMessages[Self.customReason] == nil)
  }

  @Test func endTurnShowsNoBar() {
    #expect(StateBanner.message(for: .idle(StopReason(wireValue: "end_turn"))) == nil)
  }

  @Test func eachStopReasonBarHasADistinctTitleAndIdentifier() {
    let messages = Self.hostedReasons.compactMap {
      StateBanner.message(for: .idle(StopReason(wireValue: $0)))
    }

    #expect(messages.count == Self.hostedReasons.count)
    #expect(Set(messages.map(\.title)).count == messages.count)
    #expect(Set(messages.map(\.identifier)).count == messages.count)
  }

  @Test(arguments: hostedReasons)
  func theHostedBarIsFoundByTheIdentifierOfItsReason(wireValue: String) throws {
    let state = ThreadState.idle(StopReason(wireValue: wireValue))
    let message = try #require(StateBanner.message(for: state))
    let harness = HostedViewHarness(StateBanner(state: state))
    defer { harness.close() }
    harness.pump()

    let element = try #require(harness.element(identifier: message.identifier))
    #expect(element.label?.contains(message.title) == true)
  }
}
