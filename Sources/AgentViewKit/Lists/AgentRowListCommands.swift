import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI

// MARK: - Target

/// The live values of one ``AgentRowList``: the kind and the order of its
/// rows, its open action and the scroll proxy of its stack.
///
/// The mount of the list keeps the values current. The open command reads
/// the row of its invocation path from the target, and the `nav.*` commands
/// of the list ask the target to reveal a row that the lazy stack has not
/// made (`NavScroller`).
@MainActor
final class AgentRowListTarget: NavScroller {
  /// The segment kind of each row of the list, such as `session`.
  var rowKind = ""

  /// The path of the scope of the list, or `nil` before the mount gives it.
  var listPath: FocusPath?

  /// The id of each row, in list order.
  var rowIDs: [String] = []

  /// The action that opens the row with an id, or `nil` for a list whose
  /// rows do not open.
  var open: ((String) -> Void)?

  /// The proxy of the scroll view of the list, or `nil` before the list
  /// shows.
  var proxy: ScrollViewProxy?

  /// The id of the row on `path`.
  ///
  /// - Parameter path: The invocation path of a command.
  /// - Returns: The id of the last row segment of the path, or `nil` when
  ///   the path is not in a row.
  func rowID(on path: FocusPath) -> String? {
    path.segments.last { $0.kind == rowKind }?.id
  }

  /// Tells if the row on `path` can open.
  ///
  /// - Parameter path: The invocation path of a command.
  /// - Returns: `true` when the list opens its rows and `path` is in a row.
  func canOpen(at path: FocusPath) -> Bool {
    open != nil && rowID(on: path) != nil
  }

  /// Opens the row on `path`.
  ///
  /// - Parameter path: The invocation path of a command.
  /// - Returns: `true` when the list opened a row.
  func openRow(at path: FocusPath) -> Bool {
    guard let open, let id = rowID(on: path) else { return false }
    open(id)
    return true
  }

  /// Scrolls the stack to the row after or before the row on `path`, so the
  /// lazy stack makes it, and names the scope of that row (EditorKit
  /// §9.11 stay-put reveal).
  ///
  /// - Parameters:
  ///   - direction: The direction of the stalled move: down for the next
  ///     row, up for the row before. Left and right reveal nothing.
  ///   - path: The focused scope that the stay-put was decided from.
  /// - Returns: `.target` with the path of the neighbouring row, or `.none`
  ///   past either end of the list, off a row, or across.
  func reveal(toward direction: Direction, from path: FocusPath) async -> NavReveal {
    guard let offset = Self.rowOffset(of: direction), let listPath, let id = rowID(on: path),
      let index = rowIDs.firstIndex(of: id), rowIDs.indices.contains(index + offset)
    else { return .none }
    let next = rowIDs[index + offset]
    proxy?.scrollTo(next)
    return .target(listPath.appending(FocusSegment(kind: rowKind, id: next)))
  }

  /// How many rows a move in `direction` goes.
  ///
  /// - Parameter direction: The direction of a move.
  /// - Returns: One on down, minus one on up, or `nil` for a move across the
  ///   rows.
  private static func rowOffset(of direction: Direction) -> Int? {
    switch direction {
    case .down: 1
    case .up: -1
    case .left, .right: nil
    }
  }
}

// MARK: - Open command

/// The command that opens the row of its invocation path: Return on a
/// selected row of an ``AgentRowList``.
///
/// The list registers the command at its own scope, before its `nav.*`
/// commands, so Return reaches it before `nav.drillIn`. At a row of a list
/// that opens its rows, the command is available and opens the row. Off a
/// row, or in a list whose rows do not open, it is unavailable, and Return
/// goes on to `nav.drillIn`. The command holds its target weakly, so a
/// registry that outlives the list does not keep the target.
nonisolated struct AgentRowListOpenCommand: Command {
  /// The id of the command.
  static let commandID: CommandID = "agentRowList.open"

  /// The target of the list that registered the command.
  weak let target: AgentRowListTarget?

  var id: CommandID { Self.commandID }

  var title: String { String(localized: "Open", bundle: .module) }

  func availability(in context: CommandContext) -> Availability {
    MainActor.assumeIsolated {
      guard target?.canOpen(at: context.path) == true else {
        return .unavailable(reason: String(localized: "Select a row first.", bundle: .module))
      }
      return .available
    }
  }

  func run(in context: CommandContext) -> Bool {
    MainActor.assumeIsolated {
      target?.openRow(at: context.path) ?? false
    }
  }

  /// The EditorKit definition of the command for `target`, bound to Return
  /// in the CUA and the Vim keymap, as `nav.drillIn` is.
  ///
  /// - Parameter target: The target of the list.
  /// - Returns: The definition.
  static func definition(for target: AgentRowListTarget) -> CommandDefinition {
    CommandDefinition(
      id: commandID,
      title: .static(String(localized: "Open", bundle: .module)),
      keys: [.cua: KeyChord.return, .vim: KeyChord.return],
      make: { [weak target] _ in
        AgentRowListOpenCommand(target: target)
      })
  }
}

// MARK: - Registration

/// Registers and removes the commands of one ``AgentRowList`` at the path of
/// its scope: the open command and the `nav.*` commands of EditorKit, with
/// the list as their layer.
///
/// The list registers the `nav.*` commands itself, so that the arrow keys,
/// Return and Esc move the selection in each host, as the keys of a native
/// list did. A host that registers the `nav.*` commands at the root of its
/// window keeps them for each other scope: the commands of the list are
/// nearer to a row, so a key on a row reaches them first.
enum AgentRowListRegistration {
  /// Registers the scope node, the open command and the `nav.*` commands at
  /// `path`.
  ///
  /// The open command registers first. `CommandRegistry.register` binds the
  /// keys of a definition after the keys that stand at the path, and the
  /// first binding of a key that is available wins, so Return reaches the
  /// open command before `nav.drillIn`. A second call removes the bindings
  /// of the first one and binds them again in the same order.
  ///
  /// - Parameters:
  ///   - target: The target of the list.
  ///   - nav: The nav controller of the list, which reveals the rows of the
  ///     lazy stack through `target`.
  ///   - path: The path of the scope of the list.
  ///   - registry: The registry to register into.
  static func register(
    _ target: AgentRowListTarget, nav: NavModeController, at path: FocusPath,
    into registry: inout CommandRegistry
  ) {
    registry.tree = registry.tree.merging(nil, by: .host, at: path)
    registry.register(AgentRowListOpenCommand.definition(for: target), at: path)
    registerNavCommands(controller: nav, layer: path, into: &registry)
  }

  /// Removes the open command, the `nav.*` commands and the `.host` part of
  /// the scope node at `path`, which ``register(_:nav:at:into:)`` wrote.
  ///
  /// `CommandRegistry.unregister` also removes each key of a command. The
  /// `.scope` part that `.commandScope` wrote at the same path stays.
  ///
  /// - Parameters:
  ///   - nav: A nav controller, which names the `nav.*` commands.
  ///   - path: The path of the scope of the list.
  ///   - registry: The registry to remove the commands from.
  static func deregister(nav: NavModeController, at path: FocusPath, from registry: inout CommandRegistry) {
    registry.unregister(AgentRowListOpenCommand.commandID, at: path)
    for definition in makeNavCommands(controller: nav, layer: path) {
      registry.unregister(definition.id, at: path)
    }
    registry.tree = registry.tree.removing(.host, at: path)
  }
}

// MARK: - Mount

/// The zero-size view that keeps the target of an ``AgentRowList`` current,
/// and its commands registered.
///
/// SwiftUI calls `updateNSView` after each change of the values, so the
/// target has the current rows and the current open action. The mount
/// registers through an ``AgentScopeMount``, so the newest mount of a path
/// registers, and the teardown of an older mount does not remove the
/// commands of a newer one.
struct AgentRowListMount: NSViewRepresentable {
  /// The values of the list that the mount writes to its target.
  struct Values {
    /// The system to register in.
    let system: CommandSystem
    /// The path of the scope of the list.
    let path: FocusPath
    /// The segment kind of each row.
    let rowKind: String
    /// The id of each row, in list order.
    let rowIDs: [String]
    /// The action that opens the row with an id, or `nil`.
    let open: ((String) -> Void)?
    /// The proxy of the scroll view of the list.
    let proxy: ScrollViewProxy
  }

  /// The target to keep current.
  let target: AgentRowListTarget

  /// The values of the list.
  let values: Values

  /// The registration of the list at its path, and the nav controller of the
  /// system that the list registers in.
  final class Coordinator {
    /// The nav controller of the list.
    var nav: NavModeController

    /// The system of ``nav``.
    var navSystem: CommandSystem

    /// The registration of the list at its path.
    let scopeMount: AgentScopeMount

    /// Makes a coordinator with a nav controller over `system` that reveals
    /// the rows through `target`.
    ///
    /// - Parameters:
    ///   - system: The system that the list registers in.
    ///   - target: The target of the list.
    init(system: CommandSystem, target: AgentRowListTarget) {
      let nav = NavModeController(system: system, scroller: target)
      self.nav = nav
      navSystem = system
      scopeMount = AgentScopeMount { path, registry in
        AgentRowListRegistration.deregister(nav: nav, at: path, from: &registry)
      }
    }

    /// The nav controller of `system`, made again when the system of the
    /// list changes.
    ///
    /// - Parameters:
    ///   - system: The system that the list registers in.
    ///   - target: The target of the list.
    /// - Returns: The nav controller.
    func nav(for system: CommandSystem, target: AgentRowListTarget) -> NavModeController {
      if navSystem !== system {
        nav = NavModeController(system: system, scroller: target)
        navSystem = system
      }
      return nav
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(system: values.system, target: target)
  }

  func makeNSView(context: Context) -> NSView {
    apply(to: context.coordinator)
    return NSView(frame: .zero)
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    apply(to: context.coordinator)
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.scopeMount.unmount()
  }

  /// Writes the values to the target, and registers the commands of the
  /// list at its path.
  ///
  /// - Parameter coordinator: The coordinator, which holds the path.
  private func apply(to coordinator: Coordinator) {
    target.rowKind = values.rowKind
    target.listPath = values.path
    target.rowIDs = values.rowIDs
    target.open = values.open
    target.proxy = values.proxy
    let nav = coordinator.nav(for: values.system, target: target)
    coordinator.scopeMount.mount(at: values.path, in: values.system) { [target, path = values.path] registry in
      AgentRowListRegistration.register(target, nav: nav, at: path, into: &registry)
    }
  }
}

// MARK: - Keys

/// Routes each key press that reaches an ``AgentRowList`` to the command
/// registry, at the focused scope of the window, when that scope is the list
/// or a scope in it.
///
/// A `nav.*` move, a jump and a click focus a row through the geometry of
/// EditorKit. Without Keyboard Navigation, SwiftUI gives the focusable view
/// of a row no AppKit responder, so the beacon of the row scope takes the
/// first responder. The beacon is a background of the scope, so a key goes
/// up from the beacon past the scope, and an `.onKeyPress` on the content of
/// the row never sees it. The modifier stands outside the scope of the list,
/// over each beacon of the list, and routes at the path that the beacon
/// publishes (`FocusedValues.commandPath`). Thus the arrow keys, Return and
/// Esc reach the `nav.*` commands and the open command of the list. A key
/// that the registry does not take goes on, so Space still presses a focused
/// button, and a key with the focus outside the list goes on to the host.
struct AgentRowListKeys: ViewModifier {
  /// The path of the scope of the list.
  let listPath: FocusPath

  /// The path of the leaf-most focused command scope of the window, or `nil`
  /// when no scope has the focus.
  let focusedPath: FocusPath?

  @Environment(\.commandSystem) private var system

  func body(content: Content) -> some View {
    content.onKeyPress(phases: [.down, .repeat], action: route)
  }

  /// Spells `press` as a chord with the EditorKit translator, and performs
  /// it at the focused path when the list encloses it.
  ///
  /// - Parameter press: The key press.
  /// - Returns: `.handled` when the registry took the key.
  private func route(_ press: KeyPress) -> KeyPress.Result {
    guard let system, let focusedPath, listPath.isAncestor(of: focusedPath),
      let chord = KeyChordTranslator.chord(for: press)
    else { return .ignored }
    return system.registry.performKey(chord.asSequence, at: focusedPath) ? .handled : .ignored
  }
}

extension View {
  /// Routes each key press that reaches this view to the command registry at
  /// the focused scope, when the list at `listPath` encloses that scope.
  ///
  /// - Parameters:
  ///   - listPath: The path of the scope of the list.
  ///   - focusedPath: The path of the focused scope of the window, or `nil`.
  /// - Returns: A view whose key presses run the commands of the focused
  ///   scope of the list.
  func agentRowListKeys(listPath: FocusPath, focusedPath: FocusPath?) -> some View {
    modifier(AgentRowListKeys(listPath: listPath, focusedPath: focusedPath))
  }
}
