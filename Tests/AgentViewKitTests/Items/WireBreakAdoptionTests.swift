import Foundation
import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The checks for the wire changes of ACP schema alpha.13 that the kit shows:
/// the paused tool call status, a cost in a unit that is not a currency code,
/// and the participants of a session message.
@Suite @MainActor struct WireBreakAdoptionTests {
  /// The locale of the text checks.
  static let locale = Locale(identifier: "en_US")

  @Test func aPausedToolCallHasItsLabelAndItsSymbol() {
    #expect(ToolStatusSymbol.label(for: .paused) == "Paused")
    #expect(ToolStatusSymbol.name(for: .paused) == SharedSymbol.stalled)
  }

  @Test func aPausedToolCallIsNotLiveAndHasNoResult() {
    #expect(!ToolStatusSymbol.isLive(.paused))
    #expect(!ThreadAccessibility.hasResult(.paused))
  }

  @Test func aPausedToolCallHasAPlainTick() {
    #expect(ThreadMinimapView.tickMark(for: .paused) == .plain)
  }

  @Test func aCostInAnotherUnitShowsTheAmountAndTheUnit() {
    let text = ContextUsageView.costText(for: Cost(amount: 12, currency: "credits"), locale: Self.locale)

    #expect(text == "12 credits")
  }

  @Test func aSessionMessageNamesBothSessions() {
    let text = SessionMessageView.participantsText(
      sender: SessionId(rawValue: "s1"), recipient: SessionId(rawValue: "s2"))

    #expect(text == "From s1 to s2")
  }

  @Test func aSessionMessageWithNoNamedSessionSaysAnotherSession() {
    let text = SessionMessageView.participantsText(sender: nil, recipient: SessionId(rawValue: "s2"))

    #expect(text == "From another session to s2")
  }
}
