@testable import AgentViewKit
import FoundationModelsACP
import Testing

/// The title line and the explanation that a notice of the agent gives its bar.
@Suite struct NoticeBannerLinesTests {
  /// A short title of an agent.
  static let title = "Quota low"

  /// A description of an agent.
  static let description = "Half of the quota is used."

  /// A whole sentence that an agent puts in the title of a notice.
  static let sentence = "The workspace index is out of date, so the agent can miss files that you changed today."

  @Test func aShortTitleStaysTheTitle() {
    let lines = NoticeBanner.lines(severity: .warning, title: Self.title, description: Self.description)

    #expect(lines == NoticeBanner.Lines(title: Self.title, explanation: Self.description))
  }

  @Test func aShortTitleWithNoDescriptionHasNoExplanation() {
    let lines = NoticeBanner.lines(severity: .warning, title: Self.title, description: nil)

    #expect(lines == NoticeBanner.Lines(title: Self.title, explanation: ""))
  }

  @Test func aLongTitleWithADescriptionStaysTheTitle() {
    let lines = NoticeBanner.lines(severity: .warning, title: Self.sentence, description: Self.description)

    #expect(lines == NoticeBanner.Lines(title: Self.sentence, explanation: Self.description))
  }

  @Test func aSentenceWithNoDescriptionMovesBelowTheTitleOfTheSeverity() {
    let lines = NoticeBanner.lines(severity: .warning, title: Self.sentence, description: nil)

    #expect(lines == NoticeBanner.Lines(title: "Warning", explanation: Self.sentence))
  }

  @Test func aSentenceWithAnEmptyDescriptionMovesBelowTheTitleOfTheSeverity() {
    let lines = NoticeBanner.lines(severity: .error, title: Self.sentence, description: "")

    #expect(lines == NoticeBanner.Lines(title: "Error", explanation: Self.sentence))
  }

  @Test func anEmptyTitleTakesTheTitleOfTheSeverity() {
    let lines = NoticeBanner.lines(severity: .info, title: "  ", description: Self.description)

    #expect(lines == NoticeBanner.Lines(title: "Information", explanation: Self.description))
  }

  @Test func aNoticeWithNoTextStillHasATitle() {
    let lines = NoticeBanner.lines(severity: .info, title: "", description: nil)

    #expect(lines == NoticeBanner.Lines(title: "Information", explanation: ""))
  }
}
