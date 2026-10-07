// readme:compile HostApp
import AgentViewKit
import SwiftUI
import UniformTypeIdentifiers

// Add `@main` to make this the entry point of your app.
struct HostApp: App {
  init() {
    // Loads the bundled grammars now, so that the first code block does not wait.
    GrammarBundle.register()
  }

  var body: some Scene {
    WindowGroup {
      // A thread that no source drives takes the logging actions.
      HostThread(thread: AgentThread(), actions: LoggingThreadActions())
    }
  }
}

struct HostThread: View {
  let thread: AgentThread
  let actions: any AgentThreadActions

  var body: some View {
    AgentThreadView(thread: thread, actions: actions)
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
