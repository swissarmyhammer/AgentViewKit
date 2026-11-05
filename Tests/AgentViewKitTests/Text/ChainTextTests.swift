import Foundation
import Testing

@testable import AgentViewKit

/// The chains of parts that the catalog joins with one two-part pattern: the
/// visible path "A › B › C", the spoken path "A, then B, then C", and a run
/// of sentences. The texts are for the English locale of the United States.
@Suite @MainActor struct ChainTextTests {
  /// The locale of the texts of the tests.
  static let locale = Locale(identifier: "en_US")

  /// Three names of a path.
  static let names = ["Agent", "Reviewer", "Linter"]

  @Test func theVisiblePathPutsAnAngleQuoteBetweenTwoNames() {
    #expect(ChainText.visiblePath(Self.names, locale: Self.locale) == "Agent › Reviewer › Linter")
  }

  @Test func theSpokenPathPutsThenBetweenTwoNames() {
    #expect(ChainText.spokenPath(Self.names, locale: Self.locale) == "Agent, then Reviewer, then Linter")
  }

  @Test func theSentencesHaveASpaceBetweenTwoSentences() {
    #expect(ChainText.sentences(["It is short.", "It is wrong."], locale: Self.locale) == "It is short. It is wrong.")
  }

  @Test func aChainOfOnePartIsThePart() {
    #expect(ChainText.visiblePath(["Agent"], locale: Self.locale) == "Agent")
  }

  @Test func aChainOfNoPartIsEmpty() {
    #expect(ChainText.sentences([], locale: Self.locale).isEmpty)
  }

  @Test func theErrorTextOfAFieldNamesTheFieldThenEachMessage() {
    let validation = FieldValidationState(errors: ["It is short.", "It is wrong."])

    let text = ElicitationView.fieldErrorText(title: "Name", validation: validation, locale: Self.locale)

    #expect(text == "“Name”: It is short. It is wrong.")
  }

  @Test func theSpokenPathOfTheHeaderStartsWithPath() {
    #expect(SessionPathText.label(Self.names, locale: Self.locale) == "Path: Agent, then Reviewer, then Linter")
  }
}
