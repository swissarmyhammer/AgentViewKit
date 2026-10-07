import FoundationModelsACPClient
import SwiftUI

/// The login card that a thread shows when the agent requires
/// authentication (update.md §9.4 "Error `-32000` does not start a login").
///
/// The view binds directly to `ConnectionModel.authState`. The model sets
/// `.required(authMethods)` from the `initialize` answer, after a logout, and
/// after each answer of the agent with the code `-32000` (authentication
/// required). The kit does not read the transcript to find that a sign-in is
/// necessary. While `authState` asks for a sign-in, the view shows an
/// ``AgentAuthView`` of the connection model:
///
/// - `.required`: the user must sign in.
/// - `.failed`: an auth operation failed, and the card shows its text.
/// - `.reconnectRequired`: a terminal sign-in needs a new connection.
///
/// The card gets the session model in the
/// ``SwiftUI/EnvironmentValues/sessionModel`` environment value, so that a
/// failed write to a terminal sign-in process adds its error entry to this
/// transcript.
struct AgentLoginPrompt: View {
  /// The session model of the thread.
  let session: SessionModel

  /// The connection model whose auth state tells that a login is necessary.
  let connection: ConnectionModel

  @Environment(\.agentTheme) private var theme

  var body: some View {
    if requiresSignIn {
      AgentAuthView(connection: connection)
        .environment(\.sessionModel, session)
        .padding(theme.spacing.m)
    }
  }

  /// Whether `authState` asks for a sign-in: `.required`, `.failed` or
  /// `.reconnectRequired`.
  private var requiresSignIn: Bool {
    switch connection.authState {
    case .required, .failed, .reconnectRequired: true
    case .unknown, .notRequired, .authenticated: false
    }
  }
}
