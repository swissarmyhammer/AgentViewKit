import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// The transcript of one session with its usage, and a composer below them.
///
/// The ACP tab and the Gallery tab show a session with this view. The thread
/// view shows the connection banner and the agent header of the connection
/// model, and closes the session when it goes away. Each message has the
/// message actions. The view gives the two models to the environment, so that
/// the composer can read them.
struct SessionThreadColumn<Composer: View>: View {
  /// The session model to show.
  let session: SessionModel

  /// The connection model of the agent of the session.
  let connection: ConnectionModel

  /// The view below the usage, such as a prompt composer.
  @ViewBuilder let composer: Composer

  var body: some View {
    VStack(spacing: 0) {
      AgentThreadView(session: session, connection: connection)
        .messageFooter { entry in MessageActions(entry: entry) }
      ContextUsageView(session: session)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal)
      composer
    }
    .environment(\.sessionModel, session)
    .environment(\.connectionModel, connection)
    .id(ObjectIdentifier(session))
  }
}
