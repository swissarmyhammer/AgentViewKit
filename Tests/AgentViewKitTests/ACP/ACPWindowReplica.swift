import AgentViewKit
import DemoSupport
import FoundationModelsACPClient
import SwiftUI

/// The window of the ACP tab of the demo app with its selected session, for
/// the hosted tests of the package.
///
/// The view has the columns and the toolbar of the ACP tab, and the size of
/// ``DemoWindowLayout``. The demo app is not a target of the package, so the
/// detail column holds the kit views of the `SessionThreadColumn` of the demo
/// app with a prompt composer, and the sidebar holds a text.
struct ACPWindowReplica: View {
  /// The style of the window of the demo app: a title bar and a toolbar, and
  /// content that fills the window under the title bar.
  static let titledStyle: NSWindow.StyleMask = [.titled, .closable, .resizable, .fullSizeContentView]

  /// The selected session.
  let session: SessionModel

  /// The connection model of the agent of the session.
  let connection: ConnectionModel

  var body: some View {
    NavigationSplitView {
      Text(verbatim: "Sessions")
        .navigationSplitViewColumnWidth(
          min: DemoWindowLayout.sidebarMinimumWidth, ideal: DemoWindowLayout.sidebarIdealWidth)
    } detail: {
      detail
    }
    .toolbar {
      ToolbarItemGroup {
        Button("Stop Agent", systemImage: "stop.circle") {}
        Button("Settings", systemImage: "gearshape") {}
      }
    }
  }

  /// The request deck of the connection model over the views of the
  /// `SessionThreadColumn` of the demo app: the usage, the request deck of
  /// the session and the composer are in the composer slot of the thread
  /// view.
  private var detail: some View {
    VStack(spacing: 0) {
      RequestDeck(connection: connection)
      AgentThreadView(session: session, connection: connection) {
        ContextUsageView(session: session)
          .frame(maxWidth: .infinity, alignment: .trailing)
        RequestDeck(session: session)
        PromptInputView(text: .constant(AttributedString())) {}
          .padding()
      }
      .messageFooter { entry in MessageActions(entry: entry) }
    }
  }
}
