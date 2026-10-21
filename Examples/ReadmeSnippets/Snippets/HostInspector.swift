// readme:compile HostInspector
import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// A window with a sidebar, a thread, and its own inspector.
struct InspectorWindow: View {
  let connection: ConnectionModel
  let session: SessionModel

  /// The file that the inspector of the window shows, or `nil`.
  @State private var selection: AgentAttachmentSelection?

  var body: some View {
    NavigationSplitView {
      Text("Threads")
    } detail: {
      AgentThreadView(session: session, connection: connection)
    }
    .inspector(isPresented: isInspectorPresented) {
      if let selection {
        AttachmentInspector(selection.attachment)
      }
    }
    // One time at the root of the window: the thread views apply no
    // inspector, and a tap writes the file and its session to `selection`.
    .agentAttachmentInspector(.host($selection))
  }

  /// `true` while the window has a selection. The close of the inspector
  /// writes `false`, and that removes the selection.
  private var isInspectorPresented: Binding<Bool> {
    Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })
  }
}
