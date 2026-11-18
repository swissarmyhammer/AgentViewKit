#if DEBUG
  import AgentViewKitTestSupport
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// Tests for the side cards of `/btw` in a thread (D205), through
  /// accessibility in the harness window, which is never ordered in and
  /// never key.
  ///
  /// Each fork is a preview session model, so each entry is in the model
  /// when the call returns. A press runs its action in the same step, so no
  /// test waits.
  @Suite(.serialized, .hostedSerially) @MainActor struct SideCardsHostedTests {
    /// The size of the harness window, in points.
    static let windowSize = CGSize(width: 900, height: 600)

    /// The question of the newest card.
    static let newestQuestion = "What does the parser do?"

    /// The question of the older card.
    static let olderQuestion = "Where is the lexer?"

    /// The calls of the actions of a card.
    final class ActionLog {
      /// The number of runs of Open.
      var opens = 0
      /// The number of runs of Close.
      var closes = 0
    }

    /// Makes the fork of a card: a preview session model with the question
    /// and an answer.
    ///
    /// - Parameters:
    ///   - question: The question of the card.
    ///   - id: The raw session id of the fork.
    /// - Returns: The session model.
    static func makeFork(question: String, id: String) -> SessionModel {
      .preview(
        sessionId: SessionId(rawValue: id),
        transcript: [.user(question), .agent("It reads the tokens.")])
    }

    /// The card of `question`, whose actions write to `log`.
    ///
    /// - Parameters:
    ///   - question: The question of the card.
    ///   - id: The raw session id of the fork.
    ///   - log: The log of the actions.
    /// - Returns: The card.
    static func card(question: String, id: String, log: ActionLog) -> SideQuestionCard {
      SideQuestionCard(
        question: question, session: makeFork(question: question, id: id),
        onOpen: { log.opens += 1 }, onClose: { log.closes += 1 })
    }

    /// The elements of the side cards in `harness`, depth first.
    ///
    /// - Parameter harness: The harness that shows the cards.
    /// - Returns: The elements with the identifier of a side card.
    static func cards(in harness: HostedViewHarness<some View>) -> [AccessibilityElementSnapshot] {
      harness.accessibilityElements().filter { $0.identifier == SideQuestionCard.identifier }
    }

    @Test func theCardIsOneGroupWithTheSideQuestionLabelAndTheQuestion() throws {
      let log = ActionLog()
      let harness = HostedViewHarness(size: Self.windowSize) {
        Self.card(question: Self.newestQuestion, id: "fork-1", log: log)
      }
      defer { harness.close() }
      harness.render()

      let card = try #require(harness.element(identifier: SideQuestionCard.identifier))
      #expect(card.label == "Side question")
      #expect(card.valueDescription == Self.newestQuestion)
    }

    @Test func theSideCardsOfAThreadShowTheNewestCardAtTheTop() {
      let log = ActionLog()
      let thread = SessionModel.preview(transcript: [.user("Fix the parser."), .agent("Done.")])
      let harness = HostedViewHarness(size: Self.windowSize) {
        AgentThreadView(session: thread) { EmptyView() }
          .sideCards {
            Self.card(question: Self.newestQuestion, id: "fork-new", log: log)
            Self.card(question: Self.olderQuestion, id: "fork-old", log: log)
          }
      }
      defer { harness.close() }
      harness.render()

      let questions = Self.cards(in: harness).map(\.valueDescription)

      #expect(questions == [Self.newestQuestion, Self.olderQuestion])
    }

    @Test func thePressOfOpenRunsTheOpenActionOfTheHost() throws {
      let log = ActionLog()
      let harness = HostedViewHarness(size: Self.windowSize) {
        Self.card(question: Self.newestQuestion, id: "fork-1", log: log)
      }
      defer { harness.close() }
      harness.render()

      try harness.press(identifier: SideCardVerb.openSideCard.identifier)

      #expect(log.opens == 1)
    }

    @Test func thePressOfCloseRunsTheCloseActionOfTheHost() throws {
      let log = ActionLog()
      let harness = HostedViewHarness(size: Self.windowSize) {
        Self.card(question: Self.newestQuestion, id: "fork-1", log: log)
      }
      defer { harness.close() }
      harness.render()

      try harness.press(identifier: SideCardVerb.closeSideCard.identifier)

      #expect(log.closes == 1)
    }
  }
#endif
