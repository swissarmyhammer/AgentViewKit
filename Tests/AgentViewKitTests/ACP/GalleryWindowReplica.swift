import AgentViewKit
import DemoSupport
import FoundationModelsACPClient
import SwiftUI

/// The window of the Gallery tab of the demo app with one open session, for
/// the hosted tests of the package.
///
/// The view uses the ``GalleryColumns`` of the Gallery tab. The demo app is
/// not a target of the package, so the detail column holds the kit views of
/// the `SessionThreadColumn` of the demo app with no composer, and the
/// sidebar and the look controls hold a text.
struct GalleryWindowReplica: View {
  /// The size of the window of the Gallery tab in the failed CI run.
  static let windowSize = CGSize(width: 1475, height: 587)

  /// The minimum width of the sidebar of the demo app.
  static let sidebarMinimumWidth: CGFloat = 200

  /// The ideal width of the sidebar of the demo app.
  static let sidebarIdealWidth: CGFloat = 240

  /// The open session.
  let session: SessionModel

  /// The connection model of the session.
  let connection: ConnectionModel

  var body: some View {
    GalleryColumns {
      Text(verbatim: "Sessions")
        .navigationSplitViewColumnWidth(min: Self.sidebarMinimumWidth, ideal: Self.sidebarIdealWidth)
    } detail: {
      detail
    } lookControls: {
      Text(verbatim: "Look")
    }
  }

  /// The views of the `SessionThreadColumn` of the demo app, with no composer.
  private var detail: some View {
    VStack(spacing: 0) {
      AgentThreadView(session: session, connection: connection)
        .messageFooter { entry in MessageActions(entry: entry) }
      ContextUsageView(session: session)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal)
    }
    .environment(\.sessionModel, session)
    .environment(\.connectionModel, connection)
  }
}
