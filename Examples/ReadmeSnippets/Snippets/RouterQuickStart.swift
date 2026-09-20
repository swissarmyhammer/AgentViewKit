// readme:compile RouterQuickStart
import AgentViewKit
import AgentViewKitRouter
import FoundationModelsRouter
import SwiftUI

/// Binds a Router session to a thread.
@MainActor
final class RouterQuickStart {
  let source: RouterThreadSource
  let actions: RouterThreadActions
  private let run: Task<Void, Never>

  init(session: any RoutedSession) {
    let source = RouterThreadSource(session: session)
    self.source = source
    actions = RouterThreadActions(source: source)
    run = Task { await source.run() }
  }
}

struct RouterThread: View {
  let model: RouterQuickStart

  var body: some View {
    AgentThreadView(thread: model.source.thread, actions: model.actions)
  }
}
