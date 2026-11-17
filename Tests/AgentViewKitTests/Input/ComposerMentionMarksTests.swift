import AgentViewKitTestSupport
import Foundation
import Testing

@testable import AgentViewKit

/// Tests for the marks of `@` tokens that name no session (AVK-15.4, D199
/// (h)).
@Suite @MainActor struct ComposerMentionMarksTests {
  /// The link of the resolved mention of the tests.
  static let link = URL(string: "testudo-session://01ABC")!

  // MARK: - Tokens to resolve

  @Test func eachTypedTokenIsResolvedOneTime() {
    let tokens = ComposerMentionMarks.tokensToResolve(
      in: "ask @planner and @someone now", caret: 29, fileRoot: nil, chips: [], known: ["someone"])

    #expect(tokens == ["planner"])
  }

  @Test func theTokenAtTheCaretIsNotResolvedWhileTheUserTypesIt() {
    let tokens = ComposerMentionMarks.tokensToResolve(
      in: "ask @plan", caret: 9, fileRoot: nil, chips: [], known: [])

    #expect(tokens.isEmpty)
  }

  @Test func aChipIsNotResolved() {
    let tokens = ComposerMentionMarks.tokensToResolve(
      in: "@claude-code @notes.txt ", caret: 24, fileRoot: nil, chips: ["claude-code", "notes.txt"], known: [])

    #expect(tokens.isEmpty)
  }

  @Test func aFileUnderTheRootIsNotResolved() throws {
    let root = try TemporaryFileRoot(files: ["notes.txt"])

    let tokens = ComposerMentionMarks.tokensToResolve(
      in: "see @notes.txt ", caret: 15, fileRoot: root.url, chips: [], known: [])

    #expect(tokens.isEmpty)
  }

  // MARK: - Marks

  @Test func anUnresolvedAndAnAmbiguousTokenGetAMarkWithTheirReason() {
    let states: [String: ComposerMentionState?] = [
      "foo": .unresolved(reason: "No session named foo"),
      "bar": .ambiguous(reason: "Two sessions named bar"),
      "ok": .resolved(link: Self.link),
      "quiet": nil,
    ]

    let marks = ComposerMentionMarks.marks(in: "@foo @bar @ok @quiet", states: states)

    #expect(marks.map(\.text) == ["@foo", "@bar"])
    #expect(marks.map(\.reason) == ["No session named foo", "Two sessions named bar"])
    #expect(marks.map(\.range) == [0..<4, 5..<9])
  }

  @Test func aResolvedTokenIsAMentionWithItsLink() {
    let states: [String: ComposerMentionState?] = [
      "ok": .resolved(link: Self.link), "foo": .unresolved(reason: "No session named foo"),
    ]

    #expect(ComposerMentionMarks.resolvedMentions(in: states) == ["ok": Self.link])
  }
}
