import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// Tests for the submit hook of the composer (AVK-15.3, D199).
@Suite @MainActor struct ComposerSubmitTests {
  /// The link of the mention of the tests.
  static let link = URL(string: "testudo-session://01ABC")!

  // MARK: - Submission

  @Test func theSubmissionListsEachTokenWithItsLink() throws {
    let root = try TemporaryFileRoot(files: ["notes.txt"])
    let text = EditorKitPromptEditor.attributedText(
      "ask @claude-code about @notes.txt and @someone", references: ["notes.txt"], root: root.url,
      mentions: ["claude-code": Self.link])

    let submission = ComposerSubmission(text, fileRoot: root.url)

    #expect(submission.text == "ask @claude-code about @notes.txt and @someone")
    #expect(submission.mentions.map(\.token) == ["claude-code", "notes.txt", "someone"])
    #expect(submission.mentions.map(\.link) == [Self.link, root.url.appending(path: "notes.txt"), nil])
    #expect(submission.mentions.map { String(submission.text[$0.range]) } == ["@claude-code", "@notes.txt", "@someone"])
  }

  @Test func aTypedTokenThatIsAFileUnderTheRootGetsTheFileURL() throws {
    let root = try TemporaryFileRoot(files: ["notes.txt"])

    let submission = ComposerSubmission(AttributedString("see @notes.txt"), fileRoot: root.url)

    #expect(submission.mentions.map(\.link) == [root.url.appending(path: "notes.txt")])
  }

  @Test func aTypedTokenWithNoRootHasNoLink() {
    let submission = ComposerSubmission(AttributedString("ask @someone"), fileRoot: nil)

    #expect(submission.mentions.map(\.token) == ["someone"])
    #expect(submission.mentions.map(\.link) == [nil])
  }

  @Test func aTokenThatGoesUpOutOfTheRootHasNoLink() throws {
    let root = try TemporaryFileRoot(files: ["notes.txt"])

    let submission = ComposerSubmission(AttributedString("see @../notes.txt"), fileRoot: root.url)

    #expect(submission.mentions.map(\.link) == [nil])
  }

  // MARK: - Result

  @Test func theDefaultResultSendsWithNothingAdded() {
    let result = ComposerSubmitResult.send

    #expect(!result.isCancelled)
    #expect(result.addedText.isEmpty)
    #expect(result.meta == nil)
  }

  @Test func aCancelSendsNothing() {
    #expect(ComposerSubmitResult.cancel.isCancelled)
  }

  @Test func theResultCarriesTheAddedTextAndTheMeta() {
    let result = ComposerSubmitResult.send(addingText: ["Sent to planner: delivered"], meta: ["a": .bool(true)])

    #expect(result.addedText == ["Sent to planner: delivered"])
    #expect(result.meta == ["a": .bool(true)])
    #expect(result.requestMeta == .object(["a": .bool(true)]))
  }

  // MARK: - Blocks

  @Test func theAddedTextGoesAfterThePromptTextAndBeforeTheFiles() throws {
    let root = try TemporaryFileRoot(files: ["notes.txt"])
    let input = UserInput(text: "hi", attachments: [root.url.appending(path: "notes.txt")])

    let blocks = PromptContent.makeBlocks(for: input, accepting: nil, addingText: ["first", "second"])

    #expect(blocks.map(ContentBlockWireType.wireType(of:)) == ["text", "text", "text", "resource_link"])
    let texts: [String] = blocks.compactMap { if case .text(let text) = $0 { text.text } else { nil } }
    #expect(texts == ["hi", "first", "second"])
  }
}
