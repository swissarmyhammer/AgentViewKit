import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The login card that a thread shows when the agent requires
/// authentication (update.md §9.4 "Error `-32000` does not start a login").
///
/// When a request of the session fails, `SessionModel` adds an error entry
/// with the JSON-RPC code of the failure to its transcript. The kit keeps no
/// error list. The body reads the last entry of `SessionModel.transcript`:
/// while it is an error entry with the code `-32000` (authentication
/// required), the view shows an ``AgentAuthView`` of the connection model.
/// The next entry of the transcript, for example the next prompt, removes
/// the card.
///
/// The card gets the session model in the
/// ``SwiftUI/EnvironmentValues/sessionModel`` environment value, so that a
/// failed auth call adds its error entry to this transcript.
struct AgentLoginPrompt: View {
  /// The session model whose transcript tells that a login is necessary.
  let session: SessionModel

  /// The connection model that the login card signs in to.
  let connection: ConnectionModel

  @Environment(\.agentTheme) private var theme

  var body: some View {
    if requiresAuthentication {
      AgentAuthView(connection: connection)
        .environment(\.sessionModel, session)
        .padding(theme.spacing.m)
    }
  }

  /// Whether the last entry of the transcript is an error entry with the
  /// code `-32000` (authentication required).
  private var requiresAuthentication: Bool {
    guard case .error(let entry)? = session.transcript.last else { return false }
    return entry.code == .authenticationRequired
  }
}
