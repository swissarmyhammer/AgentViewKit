// readme:compile FoundationModelsQuickStart
import AgentViewKit
import AgentViewKitFoundationModels
import FoundationModels
import SwiftUI

/// Binds a live `LanguageModelSession` to a thread.
@MainActor
final class FoundationModelsQuickStart {
  let source: SessionThreadSource
  let actions: SessionThreadActions

  init() {
    let session = LanguageModelSession(instructions: "You are the assistant of MyApp.")
    source = SessionThreadSource(session: session)
    actions = SessionThreadActions(source: source)
    source.start()
  }
}

struct FoundationModelsThread: View {
  let model: FoundationModelsQuickStart

  var body: some View {
    AgentThreadView(thread: model.source.thread, actions: model.actions)
  }
}
