import EditorCommands
import EditorStyle
import SwiftUI

/// The context menu of the host path on one part of the top bar of
/// ``AgentThreadView``: the status line, the header of the host or a banner
/// (^2sg9taf, ^tsr28g).
///
/// The full bar of the part takes a click, in the shape of the floating
/// glass of the kit (`EditorSurface.shape(radius:)` with the large radius of
/// the style). Thus a right click on the inset or on the empty space of the
/// part opens the menu, and does not go through the part to the list (D193
/// (f)). A control of the part, such as a button, keeps its own action. Each
/// part shows the same menu (``HostPathContextMenu``), so that each action
/// is a command and the menu is the same at each point of the bar (D108).
/// With no path, the part has no context menu.
struct TopBarPartContextMenu: ViewModifier {
  /// The path of the host scope, or `nil` for no context menu.
  let path: FocusPath?

  /// The style of the kit, which gives the radius of the shape of the bar.
  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    content
      .contentShape(EditorSurface.shape(radius: editorStyle.radii.l))
      .hostPathContextMenu(path)
  }
}

extension View {
  /// Gives this part of the top bar of the thread the context menu of the
  /// host path on its full bar.
  ///
  /// See ``TopBarPartContextMenu``.
  ///
  /// - Parameter path: The path of the host scope, or `nil` for no context
  ///   menu.
  /// - Returns: The part with the context menu of `path`.
  func topBarPartContextMenu(_ path: FocusPath?) -> some View {
    modifier(TopBarPartContextMenu(path: path))
  }
}
