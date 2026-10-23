import EditorCommands
import FoundationModelsACPClient
import SwiftUI

/// The default view of the composer slot of ``AgentThreadView``.
///
/// The view is a ``PromptInputView`` with the EditorKit editor
/// (``EditorKitPromptEditor``) and the default accessory row. It keeps the
/// text of the prompt itself, so the host gives nothing. The thread view
/// gives the composer its session model and its connection model. To keep
/// the text in the host, or to use another editor, give a
/// ``PromptInputView`` to
/// ``AgentThreadView/init(session:connection:sessionTitle:headerContextMenuPath:composer:)``.
///
/// The unsent text is the draft of the session model, which the kit keeps
/// out of the view (^f41brfh). So a thread view that the host rebuilds for
/// the same session, for example when it moves the view to another column,
/// shows the draft again, and a thread view of another session shows the
/// draft of that session. Each change of the text sets the draft, and Send
/// clears it. With no session model in the environment, the composer keeps
/// the text in its own state.
public struct DefaultThreadComposer: View {
  /// The draft while the environment has no session model.
  @State private var ownDraft = PromptDraft()

  @Environment(\.sessionModel) private var session

  /// The model and the completion engine of the editor, or `nil` to let the
  /// editor make its own.
  private let editorSession: PromptEditorSession?

  /// Makes the default composer of a thread.
  public init() {
    editorSession = nil
  }

  /// Makes the default composer of a thread over an editor session that the
  /// caller holds, for example a test that reads the model of the editor.
  ///
  /// - Parameter editorSession: The model and the completion engine of the
  ///   editor.
  init(editorSession: PromptEditorSession) {
    self.editorSession = editorSession
  }

  public var body: some View {
    PromptInputView(text: text, onSubmit: {}, editor: editor(_:))
  }

  /// The EditorKit editor of the composer.
  ///
  /// - Parameter context: The values that the composer gives.
  /// - Returns: The editor over the editor session of the caller, or over a
  ///   session of its own.
  private func editor(_ context: PromptEditorContext) -> EditorKitPromptEditor {
    editorSession.map { EditorKitPromptEditor(context: context, session: $0) }
      ?? EditorKitPromptEditor(context: context)
  }

  /// The binding that reads and writes the text of the prompt: the text of
  /// the draft of the session model, or of the own draft with no session
  /// model.
  private var text: Binding<AttributedString> {
    let draft = session.map(PromptDraftStore.shared.draft(for:)) ?? ownDraft
    return Binding(get: { draft.text }, set: { draft.text = $0 })
  }
}

extension AgentThreadView where Composer == DefaultThreadComposer {
  /// Makes the view of the transcript of a session model, with the default
  /// composer (``DefaultThreadComposer``) in the composer slot.
  ///
  /// When the host gives the connection model of the session, the view
  /// closes the session when the view goes away (plan.md §3.8 "Close"): it
  /// calls `ConnectionModel.close(_:)` when `canCloseSessions` is true and
  /// the session is not closed. A close that fails adds an error entry to
  /// the transcript of the session.
  ///
  /// With the connection model, the missed-updates banner of
  /// ``SessionStreamBanner`` also shows its Reload button. The button
  /// resumes the session with the `cwd` and the additional directories of
  /// the session model.
  ///
  /// The host can name the session in the header, after the agent, with
  /// `sessionTitle`, and give the path of one of its own command scopes with
  /// `headerContextMenuPath`. A right click on the header then shows the
  /// EditorKit context menu of that path, with no command that is not
  /// available there.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - connection: The connection model that opened the session, or `nil`
  ///     when the host closes the session itself.
  ///   - sessionTitle: The title of the session that the header shows after
  ///     the agent, such as the title of a tab, or `nil` for the agent alone.
  ///   - headerContextMenuPath: The path of a host scope whose context menu
  ///     a right click on the header shows, or `nil` for no context menu.
  public init(
    session: SessionModel, connection: ConnectionModel? = nil, sessionTitle: String? = nil,
    headerContextMenuPath: FocusPath? = nil
  ) {
    self.init(
      session: session, connection: connection, sessionTitle: sessionTitle,
      headerContextMenuPath: headerContextMenuPath
    ) { DefaultThreadComposer() }
  }
}

#Preview("Default thread composer") {
  DefaultThreadComposer()
    .environment(\.sessionModel, .previewSample)
}
