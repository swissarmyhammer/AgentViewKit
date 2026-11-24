import Foundation
import Testing

@testable import AgentViewKit

/// Tests for the text that the editor and the prompt agree on (^rd09ey6).
///
/// A host composer with an async submit hook clears the prompt after the
/// Return. The session must find that change, so that a late commit of the
/// editor does not give the old text back.
@Suite @MainActor struct PromptEditorSessionSyncTests {
  /// The text that the editor pushes in the tests.
  static let pushed = AttributedString("Go on")

  @Test func aPromptTextThatChangedAfterAPushIsAnOutsideChange() {
    let session = PromptEditorSession()
    session.didPush(Self.pushed)

    #expect(session.isChangedOutside(AttributedString("")))
  }

  @Test func thePushedTextIsNoOutsideChange() {
    let session = PromptEditorSession()
    session.didPush(Self.pushed)

    #expect(!session.isChangedOutside(Self.pushed))
  }

  @Test func thePulledTextIsNoOutsideChange() {
    let session = PromptEditorSession()
    session.didPush(Self.pushed)
    session.didPull(AttributedString(""))

    #expect(!session.isChangedOutside(AttributedString("")))
  }

  @Test func aPromptTextBeforeTheFirstPushOrPullIsNoOutsideChange() {
    #expect(!PromptEditorSession().isChangedOutside(Self.pushed))
  }
}
