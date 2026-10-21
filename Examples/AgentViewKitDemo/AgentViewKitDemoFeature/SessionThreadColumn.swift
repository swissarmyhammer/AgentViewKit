import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// The transcript of one session, with its usage, the request deck of the
/// session, and a composer in the composer slot of the thread view.
///
/// The ACP tab and the Gallery tab show a session with this view. The thread
/// view shows the connection banner and the agent header of the connection
/// model, and closes the session when it goes away. Each message has the
/// message actions. The ``RequestDeck`` shows the permission requests and the
/// elicitations of the session. The usage, the deck and the composer are in
/// the composer slot, directly below the chat (D36), in one glass container
/// with the scroll-to-bottom pill. The thread view puts the slot in its focus
/// scope, so that the VoiceOver focus goes from an answered card back to the
/// composer, and it gives the two models to the slot, so that the composer
/// can read them.
struct SessionThreadColumn<Composer: View>: View {
  /// The session model to show.
  let session: SessionModel

  /// The connection model of the agent of the session.
  let connection: ConnectionModel

  /// The view below the usage and the deck, such as a prompt composer.
  @ViewBuilder let composer: Composer

  var body: some View {
    AgentThreadView(session: session, connection: connection) {
      ContextUsageView(session: session)
        .frame(maxWidth: .infinity, alignment: .trailing)
      RequestDeck(session: session)
      composer
    }
    .messageFooter { entry in MessageActions(entry: entry) }
    .id(ObjectIdentifier(session))
  }
}
