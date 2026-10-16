import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The text and the identifier of ``PendingRequestCountBadge``, with no
/// hosted view.
@Suite struct PendingRequestCountBadgeTests {
  @Test func oneRequestGivesTheSingularText() {
    #expect(PendingRequestCountBadge.openQuestionsLabel(count: 1) == "1 open question")
  }

  @Test(arguments: [2, 12])
  func twoOrMoreRequestsGiveThePluralText(count: Int) {
    #expect(PendingRequestCountBadge.openQuestionsLabel(count: count) == "\(count) open questions")
  }

  @Test func theIdentifierIsTheRowIdentifierWithThePendingSuffix() {
    #expect(PendingRequestCountBadge.identifier(for: SessionId(rawValue: "s1")) == "session-row-s1-pending")
  }
}
