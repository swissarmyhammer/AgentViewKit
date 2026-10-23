import EditorCommands
import EditorCommandsUI

/// The registration of one mount of a scope at its path, through
/// `CommandSystem.mount(at:by:register:)` (EditorKit §9.12).
///
/// ``AgentCommandMount`` and ``AgentAttachmentMount`` each keep one in their
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
