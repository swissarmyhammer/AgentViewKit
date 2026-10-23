@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The thread of a scripted session in a hosted window, the command system of
/// the window, and the window undo stack.
struct MountedThread<Content: View> {
  /// The harness that shows the thread.
  let harness: HostedViewHarness<Content>

  /// The command system of the window.
  let system: CommandSystem

  /// The root path of the window.
  let path: FocusPath

  /// The undo stack of the window.
  let stack: WindowUndoStack
}

/// The setup that the hosted composer suites share: a thread view in a window
/// under a command system, and a prompt typed into the editor of its composer.
@MainActor enum ComposerHarness {
  /// The size of a window that shows a thread and its composer.
  static let windowSize = CGSize(width: 480, height: 480)

  /// Shows the view that `content` builds under a new command system, with no
  /// animations, and renders it.
  ///
  /// The view is a thread view of `session`, which applies the agent command
  /// scope of the session at the root of the window, so EditorKit gives the
  /// window its undo stack at the path of `session`.
  ///
  /// - Parameters:
  ///   - session: The session model of the thread that the view shows.
  ///   - sourceLocation: The location of the caller, for the failure report.
  ///   - content: The builder of the view to host.
  /// - Returns: The mounted thread.
  /// - Throws: An error when the window has no undo stack.
  static func mountThread(
    of session: SessionModel, sourceLocation: SourceLocation = #_sourceLocation,
    @ViewBuilder _ content: () -> some View
  ) throws -> MountedThread<some View> {
    let system = CommandSystem()
    let view = content()
    let harness = HostedViewHarness(size: windowSize) {
      view
        .commandSystem(system)
        .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    let path = AgentCommandScopeHostedTests.path(of: session)
    let stack = try #require(system.undo.stack(for: path), sourceLocation: sourceLocation)
    return MountedThread(harness: harness, system: system, path: path, stack: stack)
  }

  /// Focuses the editor, types `prompt` into it, requires that the editor
  /// shows it, and waits until `typed` gives it.
  ///
  /// The editor gives its text to its binding after the key event, so the
  /// wait reads the value that the test observes behind the binding.
  ///
  /// - Parameters:
  ///   - prompt: The text to type.
  ///   - harness: The harness that shows the editor.
  ///   - sourceLocation: The location of the caller, for the failure report.
  ///   - typed: The value to wait for: the text that the binding of the
  ///     editor holds.
  /// - Throws: An error when the editor cannot get the focus or does not show
  ///   `prompt`.
  static func typePrompt(
    _ prompt: String, in harness: HostedViewHarness<some View>,
    sourceLocation: SourceLocation = #_sourceLocation, until typed: () -> String
  ) async throws {
    try #require(harness.focusFirstEditableTextView(of: NSTextView.self), sourceLocation: sourceLocation)
    harness.type(prompt)
    try harness.requireTextViewShows(prompt, sourceLocation: sourceLocation)
    await ObservationWait.until { typed() == prompt }
  }
}
