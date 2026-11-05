import AgentViewKitStyle
import Testing

/// The accessibility label of a status text, ``StatusTitleText/label(title:explanation:)``:
/// one catalog string that holds the order and the separator of the title
/// and the explanation.
@Suite struct StatusTitleTextTests {
  @Test func theLabelHasTheTitleAndThenTheExplanation() {
    #expect(StatusTitleText.label(title: "Offline", explanation: "The agent stopped.") == "Offline, The agent stopped.")
  }

  @Test func theLabelOfATextWithNoExplanationIsTheTitle() {
    #expect(StatusTitleText.label(title: "Offline", explanation: "") == "Offline")
  }
}
