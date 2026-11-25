import EditorCommands
import EditorCommandsUI
import SwiftUI

/// The context menu of the host path on the whole top bar of
/// ``AgentThreadView``: the status line, the header of the host, each banner
/// and each gap between two parts (^2sg9taf, ^tsr28g, ^z7r9tk).
///
/// The full frame of the stack of the parts takes a click, with the spacing
/// between the parts. Thus a right click on a part, on the empty space of a
/// part or in the gap between two parts opens the menu, and does not go
/// through the bar to the list (D193 (f)). A control of a part, such as a
/// button, keeps its own action. Each point of the bar shows the same menu
/// (``HostPathContextMenu``), so that each action is a command and the menu
/// is the same at each point of the bar (D108).
///
/// With no path, or with no agent command scope above the bar, the bar has
/// no context menu and the gaps take no click: a click in a gap goes to the
/// list.
struct TopBarContextMenu: ViewModifier {
  /// The path of the host scope, or `nil` for no context menu.
  let path: FocusPath?

  @Environment(\.agentCommandSystem) private var system

  func body(content: Content) -> some View {
    if let path, system != nil {
      content
        .contentShape(Rectangle())
        .hostPathContextMenu(path)
    } else {
      content
    }
  }
}

extension View {
  /// Gives the stack of the parts of the top bar of the thread the context
  /// menu of the host path on its full frame.
  ///
  /// See ``TopBarContextMenu``.
  ///
  /// - Parameter path: The path of the host scope, or `nil` for no context
  ///   menu.
  /// - Returns: The stack with the context menu of `path`.
  func topBarContextMenu(_ path: FocusPath?) -> some View {
    modifier(TopBarContextMenu(path: path))
  }
}
