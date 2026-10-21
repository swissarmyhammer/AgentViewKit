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
  /// The width of the window of the Gallery tab in the failed CI run, in
  /// points.
  static let windowWidth: CGFloat = 1475

  /// The height of the window of the Gallery tab in the failed CI run, in
  /// points.
  static let windowHeight: CGFloat = 587

  /// The size of the window of the Gallery tab in the failed CI run.
  static let windowSize = CGSize(width: windowWidth, height: windowHeight)

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

  /// The views of the `SessionThreadColumn` of the demo app, with no composer:
  /// the usage is in the composer slot of the thread view.
  private var detail: some View {
    AgentThreadView(session: session, connection: connection) {
      ContextUsageView(session: session)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .messageFooter { entry in MessageActions(entry: entry) }
  }
}
