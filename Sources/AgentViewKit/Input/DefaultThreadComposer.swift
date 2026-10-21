import FoundationModelsACPClient
import SwiftUI

/// The default view of the composer slot of ``AgentThreadView``.
///
/// The view is a ``PromptInputView`` with the stock editor and the default
/// accessory row. It keeps the text of the prompt itself, so the host gives
/// nothing. The thread view gives the composer its session model and its
/// connection model. To keep the text in the host, or to use another editor,
/// give a ``PromptInputView`` to ``AgentThreadView/init(session:connection:composer:)``.
public struct DefaultThreadComposer: View {
  /// The text of the prompt.
  @State private var draft = AttributedString()

  /// Makes the default composer of a thread.
  public init() {}

  public var body: some View {
    PromptInputView(text: text) {}
  }

  /// The binding that reads and writes the text of the prompt.
  private var text: Binding<AttributedString> {
    Binding(get: { draft }, set: { draft = $0 })
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
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - connection: The connection model that opened the session, or `nil`
  ///     when the host closes the session itself.
  public init(session: SessionModel, connection: ConnectionModel? = nil) {
    self.init(session: session, connection: connection) { DefaultThreadComposer() }
  }
}

#Preview("Default thread composer") {
  DefaultThreadComposer()
    .environment(\.sessionModel, .previewSample)
}
