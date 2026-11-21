import EditorCommands
import EditorCommandsUI
import FoundationModelsACPClient
import SwiftUI

/// Gives the first responder to the composer of a thread with no transcript
/// entry (Testudo, 2026-11-20).
///
/// The view stands in the background of ``AgentThreadView``, inside the agent
/// command scope of the thread. It calls
/// ``AgentCommandTarget/focusComposerInEmptyThread(after:)`` at two times:
///
/// - When the thread shows a session with no transcript entry: after the
///   scope of the thread is focusable (EditorKit
///   `GeometryRegistry.focusable(at:within:)`), so the views of the thread
///   are in the window.
/// - At each focus move of the command system
///   (`GeometryRegistry.lastFocusMove`), such as a click on the empty space
///   of the thread (`.focusesScopeOnClick(.emptySpaceOnly)`). The target
///   moves the focus only for a move to the scope of the thread.
///
/// In a thread with messages, or with no composer, the composer does not
/// take the focus. The view gives the result of each call to
/// ``SwiftUI/EnvironmentValues/emptyThreadFocusReport``.
struct EmptyThreadComposerFocus: View {
  /// The session that the thread shows.
  let session: SessionModel

  /// The target of the agent command scope of the thread.
  @Environment(\.agentCommandTarget) private var target

  /// The command system of the agent command scope of the thread.
  @Environment(\.agentCommandSystem) private var system

  /// The report that gets the result of each call, or `nil`.
  @Environment(\.emptyThreadFocusReport) private var report

  var body: some View {
    Color.clear
      .accessibilityHidden(true)
      .task(id: ObjectIdentifier(session)) { await threadDidShow() }
      .onChange(of: system?.geometry.lastFocusMove) { _, move in focusDidMove(move) }
  }

  /// Gives the focus to the composer when the thread shows a session with no
  /// transcript entry, after the scope of the thread is focusable.
  private func threadDidShow() async {
    guard session.transcript.isEmpty, let system, let path = target?.path,
      await system.geometry.focusable(at: path)
    else { return }
    focusComposer(after: nil)
  }

  /// Gives the focus to the composer when `move` gave the focus to the scope
  /// of a thread with no transcript entry.
  ///
  /// - Parameter move: The newest focus move of the command system, or
  ///   `nil` when the system has made no move.
  private func focusDidMove(_ move: FocusMove?) {
    guard let move else { return }
    focusComposer(after: move)
  }

  /// Calls the target, and gives the result to the report.
  ///
  /// - Parameter move: The focus move, or `nil` when the thread shows.
  private func focusComposer(after move: FocusMove?) {
    report?(target?.focusComposerInEmptyThread(after: move) ?? false)
  }
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets the result of each composer focus
  /// of a thread with no transcript entry, or `nil`: `true` when the
  /// composer took the focus.
  ///
  /// The thread calls the report in the same step as the focus request, when
  /// the thread shows and at each focus move of its command system. A test
  /// reads the report to learn that the request ran.
  @Entry var emptyThreadFocusReport: ObservationReport<Bool>? = nil
}
