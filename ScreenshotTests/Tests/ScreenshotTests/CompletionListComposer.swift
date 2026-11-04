@testable import AgentViewKit
import AppKit
import EditorComplete
import EditorStyle
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The composer of the `composer-completion-list` images: the composer of
/// ``SnapshotFixtures/commandsSession`` with its completion list open on a
/// slash, as a person sees it after typing `/`.
///
/// The gallery mounts the composer one time for each look, so each look gets
/// a new session and a new editor session (``makeComposer()``). The settle
/// step (``openList(in:)``) types the slash into the editor of that mount, as
/// a key press does, and waits until the completion engine lists each
/// command of the session.
final class CompletionListComposer {
  /// The session of the composer that the gallery mounted last.
  private var session = SnapshotFixtures.commandsSession

  /// The editor session of the composer that the gallery mounted last.
  private var editorSession = PromptEditorSession()

  /// A new composer over a new session and a new editor session, on the
  /// glass of the composer slot of a thread, over text.
  ///
  /// - Returns: The view to mount.
  func makeComposer() -> some View {
    session = SnapshotFixtures.commandsSession
    editorSession = PromptEditorSession()
    let composer = FloatingGlassContainer(spacing: GlassSnapshotTests.spacing) {
      DefaultThreadComposer(editorSession: editorSession).environment(\.sessionModel, session)
    }
    return GlassSnapshotTests.overText(composer)
  }

  /// Types a slash into the editor of `mount`, and waits until the completion
  /// list shows a row for each command of the session.
  ///
  /// - Parameter mount: The window and the hosting view of the composer.
  /// - Throws: An issue when the mount has no editable text view, the text
  ///   view does not take the focus, or AppKit builds no key event.
  func openList(in mount: ReviewMount) async throws {
    let textViews = mount.hostingView.descendants.compactMap { $0 as? NSTextView }
    let textView = try #require(textViews.first { $0.isEditable })
    try #require(mount.window.makeFirstResponder(textView))
    for type in [NSEvent.EventType.keyDown, .keyUp] {
      let event = try #require(
        NSEvent.makeKeyEvent(
          type, characters: SlashCommandSource.trigger, keyCode: HostedKey.letterKeyCode,
          windowNumber: mount.window.windowNumber))
      mount.window.sendEvent(event)
    }
    let commandCount = session.availableCommands?.count
    await mount.render { completion.listedItems.count == commandCount }
  }

  /// The completion session of the editor of the composer that the gallery
  /// mounted last.
  private var completion: CompletionSessionState {
    editorSession.model.state.value(CompletionSessionField.self)
  }
}
