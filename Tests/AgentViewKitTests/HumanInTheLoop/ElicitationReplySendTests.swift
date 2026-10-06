import AgentViewKitTestSupport
import Testing

@testable import AgentViewKit

/// The shared function that sends the answer of an elicitation card to the
/// model in ``SwiftUI/EnvironmentValues/elicitationReplies``.
///
/// ``ElicitationView`` and ``ElicitationURLConsentView`` both call this
/// function, so each card sends the answer in the same way.
@MainActor struct ElicitationReplySendTests {
  /// A model that records each answer it gets.
  @MainActor
  private final class RecordingReplies: ElicitationReplying {
    /// The answers, in the order that the model got them.
    private(set) var answers: [(request: ElicitationRequest, result: ElicitationResult)] = []

    func reply(to request: ElicitationRequest, _ result: ElicitationResult) {
      answers.append((request, result))
    }
  }

  @Test func sendGivesTheRequestAndTheResultToTheModel() throws {
    let model = RecordingReplies()
    let replies: (any ElicitationReplying)? = model
    let request = ThreadFixtures.formElicitationRequest()

    replies.send(.decline, to: request)

    let answer = try #require(model.answers.first)
    #expect(model.answers.count == 1)
    #expect(answer.request == request)
    #expect(answer.result == .decline)
  }
}
