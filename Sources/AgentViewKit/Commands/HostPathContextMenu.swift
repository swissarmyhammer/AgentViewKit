import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import SwiftUI

/// The EditorKit context menu of a scope path that the host gives, such as
/// the `session:<tab id>` scope of TestudoApp on the thread header
/// (^2sg9taf).
///
/// EditorKit's `.commandContextMenu` builds its menu at the path of the
/// enclosing `.commandScope`. The host scope is not an ancestor of the view,
/// so this modifier builds the menu at the given path itself. It reads
/// `contextMenuMirror(at:mode:unavailable:)` of the command system of the
/// nearest ``AgentCommandScope`` (``SwiftUI/EnvironmentValues/agentCommandSystem``)
/// each time the menu shows, shows each command as an EditorKit
/// `EditorMenuItem`, puts one `Divider` between two context menu groups, and
/// leaves out each command that is not available at the path
/// (``ContextMenuUnavailablePolicy/hostPath``). A chosen item runs its
/// command at the path, with the path as the clicked path, as an item of
/// `.commandContextMenu` does.
///
/// With ``hitArea``, the full frame of the view takes a click, with its empty
/// space, such as the top bar of ``AgentThreadView`` and the gaps between its
/// parts (^z7r9tk). Thus a right click on the empty space opens the menu, and
/// does not go through the view to the view below it (D193 (f)). A control
/// in the view, such as a button, keeps its own action.
///
/// With no path, or with no agent command scope above the view, the modifier
/// attaches no context menu and adds no hit area: a click on the empty space
/// goes to the view below it.
struct HostPathContextMenu: ViewModifier {
  /// The path of the host scope, or `nil` for no context menu.
  let path: FocusPath?

  /// When `true`, the full frame of the view takes a click when the menu
  /// shows. When `false`, the view keeps its own hit area.
  let hitArea: Bool

  @Environment(\.agentCommandSystem) private var system

  func body(content: Content) -> some View {
    if let path, let system {
      hitShape(of: content).contextMenu {
        HostPathContextMenuItems(system: system, path: path)
      }
    } else {
      content
    }
  }

  /// The view with the hit area of the menu.
  ///
  /// - Parameter content: The view of the modifier.
  /// - Returns: `content` with a rectangle content shape of its full frame
  ///   when ``hitArea`` is `true`, else `content` with no change.
  @ViewBuilder private func hitShape(of content: Content) -> some View {
    if hitArea {
      content.contentShape(Rectangle())
    } else {
      content
    }
  }
}

/// The items of a ``HostPathContextMenu``: one section for each context
/// menu group of the commands at the path, in group order.
struct HostPathContextMenuItems: View {
  /// The command system whose registry gives the commands.
  let system: CommandSystem

  /// The path of the host scope.
  let path: FocusPath

  var body: some View {
    let sections = Self.sections(
      of: system.registry.contextMenuMirror(at: path, unavailable: .hostPath))
    ForEach(sections.indices, id: \.self) { index in
      if index > 0 {
        Divider()
      }
      ForEach(sections[index], id: \.id) { item in
        EditorMenuItem(item.title) { run(item) }
      }
    }
  }

  /// Splits a context menu list into one section for each group, in group
  /// order. Each section keeps the order of the list.
  ///
  /// - Parameter items: The items, ordered by group and order, as
  ///   `contextMenuMirror(at:mode:unavailable:)` returns them.
  /// - Returns: The sections. No section is empty.
  static func sections(of items: [ContextMenuMirrorItem]) -> [[ContextMenuMirrorItem]] {
    Dictionary(grouping: items, by: \.group)
      .sorted { $0.key < $1.key }
      .map(\.value)
  }

  /// Runs the command of `item` at the path of the host scope.
  ///
  /// - Parameter item: The chosen item.
  private func run(_ item: ContextMenuMirrorItem) {
    _ = system.registry.perform(item.id, at: path, clicked: path)
  }
}

extension View {
  /// Attaches the EditorKit context menu of a host scope path to this view.
  ///
  /// See ``HostPathContextMenu``.
  ///
  /// - Parameters:
  ///   - path: The path of the host scope, or `nil` for no context menu.
  ///   - hitArea: When `true`, the full frame of the view takes a click when
  ///     the menu shows, with its empty space. The default is `false`: the
  ///     view keeps its own hit area.
  /// - Returns: The view with the context menu of `path`.
  func hostPathContextMenu(_ path: FocusPath?, hitArea: Bool = false) -> some View {
    modifier(HostPathContextMenu(path: path, hitArea: hitArea))
  }
}

extension ContextMenuUnavailablePolicy {
  /// The policy of the context menu of a host scope path
  /// (``HostPathContextMenu``): a command that is not available at the path
  /// does not show in the menu.
  static let hostPath: ContextMenuUnavailablePolicy = .hide
}
