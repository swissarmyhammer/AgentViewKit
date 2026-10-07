// readme:compile HostApp
import AgentViewKit
import FoundationModelsACPClient
import SwiftUI
import UniformTypeIdentifiers

// Add `@main` to make this the entry point of your app.
struct HostApp: App {
  /// The connection to the agent. Connect it and open a session with a quick
  /// start above.
  @State private var connection = ConnectionModel()

  init() {
    // Loads the bundled grammars now, so that the first code block does not wait.
    GrammarBundle.register()
  }

  var body: some Scene {
    WindowGroup {
      // The window shows an open session of the connection model.
      if let session = connection.openSessions.values.first {
        HostThread(connection: connection, session: session)
      } else {
        ContentUnavailableView("No session", systemImage: "bubble.left.and.bubble.right")
      }
    }
  }
}

struct HostThread: View {
  let connection: ConnectionModel
  let session: SessionModel

  var body: some View {
    ACPThread(connection: connection, session: session)
      // One typed modifier for each transcript entry case. The closure gets
      // the entry object of the session model.
      .toolCallView { call in Text(call.title ?? "") }
      .reasoningView { _ in EmptyView() }
      // The open-ended kinds take a key: a block kind or a type.
      .contentBlockView(for: .resourceLink) { block in
        if case .resourceLink(let link) = block.content { Text(link.name) }
      }
      .attachmentView(for: .pdf) { url in Text(url.lastPathComponent) }
      // The footer slot of each message entry.
      .messageFooter { entry in MessageActions(entry: entry) }
  }
}
