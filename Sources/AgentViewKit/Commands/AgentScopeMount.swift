import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI

/// The registration of one mount of a scope at its path, through
/// `CommandSystem.mount(at:by:register:)` (EditorKit §9.12).
///
/// ``AgentCommandMount`` and each ``AgentScopeAnchor`` keep one in their
/// coordinator, and the object is the holder of the path. Two mounts can
/// register at one path: SwiftUI makes a newer view before it dismantles the
/// older view, and two windows that show one scope have the same paths. The
/// newest mount registers. When it unmounts while an older mount still holds
/// the path, EditorKit gives the path back to the older mount on the next
/// pass of the main run loop, with no update of the older view.
///
/// A mount whose path or system changes leaves the old place first, so no
/// stale registration stays there for a later hand-back to run.
@MainActor final class AgentScopeMount {
  /// Removes what a registration wrote at a path.
  typealias Unregister = @MainActor (FocusPath, inout CommandRegistry) -> Void

  /// Removes what the mount wrote at its path.
  private let unregister: Unregister

  /// The system and the path of the current registration, or `nil`.
  private var place: (system: CommandSystem, path: FocusPath)?

  /// Makes a mount with no registration yet.
  ///
  /// - Parameter unregister: Removes what the mount wrote at a path.
  init(unregister: @escaping Unregister) {
    self.unregister = unregister
  }

  /// Registers at `path` in `system`, as the newest mount of the path.
  ///
  /// A mount calls this each time its view mounts or updates. A newer mount
  /// of the same path keeps the path, and `register` then runs only when the
  /// path comes back to this mount.
  ///
  /// - Parameters:
  ///   - path: The path of the scope.
  ///   - system: The system to register in.
  ///   - register: What the mount writes at `path`.
  func mount(
    at path: FocusPath, in system: CommandSystem,
    register: @escaping @MainActor (inout CommandRegistry) -> Void
  ) {
    if let place, place.path != path || place.system !== system {
      unmount()
    }
    system.mount(at: path, by: self, register: register)
    place = (system, path)
  }

  /// Ends the registration. With no registration, the call does nothing.
  ///
  /// The last mount of a path removes its registration at once. A mount that
  /// leaves an older mount at the path hands the path back on the next pass
  /// of the main run loop.
  func unmount() {
    guard let place else {
      return
    }
    self.place = nil
    let unregister = unregister
    place.system.unmount(at: place.path, by: self) { registry in
      unregister(place.path, &registry)
    }
  }
}

/// The zero-size view that keeps the target of a scope current and the
/// commands of the scope registered at its path.
///
/// SwiftUI calls `updateNSView` after each change to the values, so the
/// target always has the current values, system and path. The coordinator
/// is the ``AgentScopeMount`` that registers the commands at the path, so
/// the newest anchor of a path registers, and the teardown of an older
/// anchor does not remove the commands of a newer anchor.
///
/// A scope gives only its own steps: what it writes to its target, and what
/// it registers at its path. The attachment scope (``AgentAttachmentMount``)
/// and the side card scope (``SideCardMount``) use this view.
struct AgentScopeAnchor<Target: AnyObject>: NSViewRepresentable {
  /// The target to keep current.
  let target: Target

  /// The system to register in.
  let system: CommandSystem

  /// The path of the scope.
  let path: FocusPath

  /// Removes what ``register`` wrote at a path.
  let unregister: AgentScopeMount.Unregister

  /// Writes the current values to the target. The second argument is the
  /// view of the anchor, for a presenter that shows at the anchor.
  let write: @MainActor (Target, NSView) -> Void

  /// Registers the commands of the target at the path of the scope.
  let register: @MainActor (Target, FocusPath, inout CommandRegistry) -> Void

  /// Makes the scope mount that holds the path of this anchor.
  func makeCoordinator() -> AgentScopeMount {
    AgentScopeMount(unregister: unregister)
  }

  /// Makes the view of the anchor, writes the values and registers.
  func makeNSView(context: Context) -> NSView {
    let anchor = NSView(frame: .zero)
    apply(anchor: anchor, scopeMount: context.coordinator)
    return anchor
  }

  /// Writes the values and registers again. While a newer anchor holds the
  /// path, the registration waits until the path comes back to this anchor.
  func updateNSView(_ anchor: NSView, context: Context) {
    apply(anchor: anchor, scopeMount: context.coordinator)
  }

  /// Ends the registration of the anchor.
  static func dismantleNSView(_ anchor: NSView, coordinator: AgentScopeMount) {
    coordinator.unmount()
  }

  /// Writes the values to the target, and registers the commands at the
  /// current path.
  ///
  /// A change of the path or of the system ends the registration at the old
  /// place first.
  ///
  /// - Parameters:
  ///   - anchor: The view of the anchor.
  ///   - scopeMount: The coordinator, which holds the path.
  private func apply(anchor: NSView, scopeMount: AgentScopeMount) {
    write(target, anchor)
    scopeMount.mount(at: path, in: system) { [target, path, register] registry in
      register(target, path, &registry)
    }
  }
}
