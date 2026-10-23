import EditorCommands
import EditorCommandsUI
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
/// each time the menu shows, puts one `Divider` between two context menu
/// groups, and leaves out each command that is not available at the path
/// (``ContextMenuUnavailablePolicy/hostPath``). A chosen item runs its
/// command at the path, with the path as the clicked path, as an item of
/// `.commandContextMenu` does.
///
/// With no path, or with no agent command scope above the view, the modifier
/// attaches no context menu.
struct HostPathContextMenu: ViewModifier {
  /// The path of the host scope, or `nil` for no context menu.
  let path: FocusPath?

  @Environment(\.agentCommandSystem) private var system

  func body(content: Content) -> some View {
    if let path, let system {
      content.contextMenu {
        HostPathContextMenuItems(system: system, path: path)
      }
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
        Button(item.title) { run(item) }
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
  /// - Parameter path: The path of the host scope, or `nil` for no context
  ///   menu.
  /// - Returns: The view with the context menu of `path`.
  func hostPathContextMenu(_ path: FocusPath?) -> some View {
    modifier(HostPathContextMenu(path: path))
  }
}

extension ContextMenuUnavailablePolicy {
  /// The policy of the context menu of a host scope path
  /// (``HostPathContextMenu``): a command that is not available at the path
  /// does not show in the menu.
  static let hostPath: ContextMenuUnavailablePolicy = .hide
}
