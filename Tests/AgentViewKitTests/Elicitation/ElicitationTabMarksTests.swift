import AgentViewKit
import Testing

/// The accessibility value of a field tab, ``ElicitationTabMarks/text(required:answered:)``:
/// the two localized marks in the one catalog string that holds their order
/// and their separator.
@Suite struct ElicitationTabMarksTests {
  @Test func aRequiredAnsweredFieldReadsBothMarks() {
    #expect(ElicitationTabMarks.text(required: true, answered: true) == "Required, Answered")
  }

  @Test func anOptionalFieldWithNoAnswerReadsBothMarks() {
    #expect(ElicitationTabMarks.text(required: false, answered: false) == "Optional, No answer")
  }
}
