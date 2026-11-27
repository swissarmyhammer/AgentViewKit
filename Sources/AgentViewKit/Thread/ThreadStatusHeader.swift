import EditorCommands
import EditorStyle
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The header of the top bar of ``AgentThreadView``: the ``StatusLineView``
/// on floating glass, with the context menu of the host path (^2sg9taf).
///
/// The status line has no padding of its own (^rgsq3k4): the header insets
/// it in its glass with the steps of the style (``inset(in:)``). The whole
/// glass, with the inset, takes a click and opens the context menu. The glass
/// is one accessibility container with the identifier ``identifier`` and the
/// frame of the glass, inset included (^y43c2hw), so that a UI test can find
/// a point of the glass that is not on a module. The view
/// stands in the `FloatingGlassContainer` of the thread view.
struct ThreadStatusHeader: View {
  /// The accessibility identifier of the glass of the header.
  static let identifier = "agent-status-header"

  /// The session of the thread.
  let session: SessionModel

  /// The connection of the thread: the status line reads the name of the
  /// agent from it.
  let connection: ConnectionModel

  /// The title of the session that the host gives, or `nil` for the title
  /// of the session model.
  let sessionTitle: String?

  /// The path of a host scope whose context menu the header shows, or `nil`
  /// for no context menu.
  let contextMenuPath: FocusPath?

  /// Shows a session of the crumbs.
  let select: (SessionId) -> Void

  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    StatusLineView(
      session: session, connection: connection, sessionTitle: sessionTitle, select: select
    )
    .padding(Self.inset(in: editorStyle.spacing))
    // The glass takes no click. The whole shape of the glass takes a click,
    // so that a right click on the inset of the line opens the context menu
    // of the header, and does not go through the glass to the list (D193
    // (f)). The shape is the window shape of `floatingGlass()`.
    .contentShape(EditorSurface.windowShape(radius: editorStyle.radii.l))
    // The glass is one container of the line (^y43c2hw). The glass gives
    // its shape, and thus its frame, to the container.
    .keepsAccessibilityContainerSeparate()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.identifier)
    .floatingGlass()
    .hostPathContextMenu(contextMenuPath)
  }

  /// The inset of the status line in its glass: the medium spacing step on
  /// the leading and the trailing edge, and the small step on the top and
  /// the bottom edge.
  ///
  /// - Parameter spacing: The spacing steps of the style.
  /// - Returns: The inset.
  static func inset(in spacing: EditorStyle.Spacing) -> EdgeInsets {
    EdgeInsets(top: spacing.s, leading: spacing.m, bottom: spacing.s, trailing: spacing.m)
  }
}

extension View {
  /// Keeps the container element that the caller sets next on this view as
  /// a node of its own, above the one element of this view.
  ///
  /// SwiftUI merges an `.accessibilityElement(children: .contain)` container
  /// with its child when the child is the one element in the container: the
  /// two become one node, with the identifier of the outer container. A
  /// hidden element in the background is a second child for this check, and
  /// VoiceOver does not read it.
  ///
  /// - Returns: The view with the hidden element in its background.
  fileprivate func keepsAccessibilityContainerSeparate() -> some View {
    background { Color.clear.accessibilityElement().accessibilityHidden(true) }
  }
}
