@testable import AgentViewKit
import EditorSwiftUI
import Testing

/// Tests of the one submit-on-commit rule of the one-line fields of the kit
/// (`EditorCommit.submittedText`): the rule that ``AgentOneLineField`` and the
/// one-line ``ElicitationTextField`` both read through
/// `SingleLineField.onFieldSubmit(_:)`.
///
/// Return (`.submit`) and Command-Return (`.submitNow`) submit the text of
/// the commit. Esc (`.leave`) and a focus loss (`.focusLoss`) submit
/// nothing. The hosted tests of each field press the keys:
/// ``PermissionCommentFieldHostedTests`` and
/// ``ElicitationTextFieldEditingHostedTests``.
struct OneLineFieldSubmitTests {
  /// The text of the commits of the tests.
  static let text = "Ada"

  /// The commit reasons that submit a field. It is not isolated to the main
  /// actor, because a `@Test(arguments:)` list reads it.
  nonisolated static let submittingReasons: [EditorCommitReason] = [.submit, .submitNow]

  /// The commit reasons that end an edit and submit nothing. It is not
  /// isolated to the main actor, because a `@Test(arguments:)` list reads it.
  nonisolated static let keepingReasons: [EditorCommitReason] = [.leave, .focusLoss]

  @Test(arguments: submittingReasons)
  func returnAndCommandReturnSubmitTheTextOfTheCommit(reason: EditorCommitReason) {
    let commit = EditorCommit(reason: reason, text: Self.text, isChanged: true)

    #expect(commit.submittedText == Self.text)
  }

  @Test(arguments: keepingReasons)
  func escapeAndAFocusLossSubmitNothing(reason: EditorCommitReason) {
    let commit = EditorCommit(reason: reason, text: Self.text, isChanged: true)

    #expect(commit.submittedText == nil)
  }

  /// A Return with no change still submits: a person can press Return on an
  /// answer that the field already shows.
  @Test func aReturnWithNoChangeSubmitsTheText() {
    let commit = EditorCommit(reason: .submit, text: Self.text, isChanged: false)

    #expect(commit.submittedText == Self.text)
  }
}
