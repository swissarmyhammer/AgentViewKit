import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI

/// The focus scope that registers the agent commands of a thread
/// (plan.md §4.1, §11 decision 14).
///
/// The scope registers one command for each ``AgentCommandVerb``, and the keys
/// of ``AgentKeymap``, in the ambient `CommandSystem` of EditorKit. The scope
/// adds the segment `agentThread:<identity>` to the focus path. When no
/// ancestor installs a system with `.commandSystem(_:)`, the scope uses a
/// private system, so that the views in the scope still run the commands.
///
/// Each command reads its eligibility from ``AgentThread/state`` and the
/// pending lists of the thread. The views in the scope give the parts that
/// only they have: ``ConversationView`` in an ``AgentThreadView`` gives its
/// scroll anchors, ``AgentThreadView`` gives its store of the expanded items,
/// ``PromptInputView`` gives its submit and its focus, and ``PermissionView``
/// answers through the approve and reject commands.
///
/// ``AgentThreadView`` applies a scope for its thread. To put a composer in
/// the same scope, apply ``SwiftUI/View/agentCommandScope(thread:)`` to a view
/// that holds both. A thread view in a scope for the same thread adds its
/// parts to that scope and does not make a second scope.
struct AgentCommandScope: ViewModifier {
  /// The thread that the commands act on.
  let thread: AgentThread

  /// The scroll anchors of the thread list, or `nil`.
  let anchors: ScrollAnchorManager?

  @Environment(\.commandSystem) private var ambientSystem
  @Environment(\.commandScopePath) private var parentPath
  @Environment(\.agentCommandTarget) private var enclosingTarget
  @Environment(\.agentCommandScopeThread) private var enclosingThread
  @Environment(\.threadActions) private var actions
  @Environment(\.pasteboard) private var pasteboard
  @Environment(\.expandedBlocksStore) private var expandedBlocks

  /// The target of this scope.
  @State private var ownTarget = AgentCommandTarget()

  /// The system that the scope uses when no ancestor installs one.
  @State private var standaloneSystem = CommandSystem()

  /// The segment of this scope.
  private var segment: FocusSegment {
    AgentCommandTarget.segment(for: thread)
  }

  func body(content: Content) -> some View {
    if let enclosingTarget, enclosingThread == ObjectIdentifier(thread) {
      content.background(
        AgentCommandMount(
          target: enclosingTarget, scope: nil, anchors: anchors, expandedBlocks: expandedBlocks))
    } else {
      let segment = segment
      let path = parentPath?.appending(segment) ?? .root(segment)
      let scope = AgentCommandMount.Scope(
        system: ambientSystem ?? standaloneSystem, path: path, thread: thread,
        actions: actions, pasteboard: pasteboard)
      content
        .environment(\.agentCommandTarget, ownTarget)
        .environment(\.agentCommandScopeThread, ObjectIdentifier(thread))
        .background(
          AgentCommandMount(
            target: ownTarget, scope: scope, anchors: anchors, expandedBlocks: expandedBlocks))
        .commandScope(segment: segment)
    }
  }
}

extension View {
  /// Registers the agent commands of `thread` for this view and each view in
  /// it (plan.md §4.1, §11 decision 14).
  ///
  /// Apply the scope to a view that holds an ``AgentThreadView`` and a
  /// ``PromptInputView``, so that the commands submit and focus the composer.
  /// See ``AgentCommandVerb`` and ``AgentKeymap``.
  ///
  /// - Parameter thread: The thread that the commands act on.
  /// - Returns: A view in the scope of the commands.
  public func agentCommandScope(thread: AgentThread) -> some View {
    modifier(AgentCommandScope(thread: thread, anchors: nil))
  }

  /// Registers the agent commands of `thread`, with the scroll anchors of
  /// the thread list.
  ///
  /// - Parameters:
  ///   - thread: The thread that the commands act on.
  ///   - anchors: The scroll anchors of the thread list.
  /// - Returns: A view in the scope of the commands.
  func agentCommandScope(thread: AgentThread, anchors: ScrollAnchorManager) -> some View {
    modifier(AgentCommandScope(thread: thread, anchors: anchors))
  }
}

// MARK: - Registration

/// Registers and removes the agent commands of a scope in a registry.
///
/// The mount of a scope and the headless tests use the same calls.
enum AgentCommandRegistration {
  /// Registers the scope node, the commands, and the keys of `target` at
  /// `path`.
  ///
  /// A second call for the same path replaces the first registration. The
  /// call keeps the layer flag and the context contribution of a node that
  /// `.commandScope` registered at the same path.
  ///
  /// - Parameters:
  ///   - target: The target that the commands act on.
  ///   - path: The path of the scope.
  ///   - registry: The registry to register into.
  static func register(
    _ target: AgentCommandTarget, at path: FocusPath, into registry: inout CommandRegistry
  ) {
    let prior = registry.tree.nodes.first { $0.path == path }
    let node = ScopeNode(
      path: path, isLayer: prior?.isLayer ?? false, contribution: prior?.contribution)
    registry.tree = ScopeTree(registry.tree.nodes.filter { $0.path != path } + [node])
    for definition in AgentCommand.definitions(for: target) {
      registry.register(definition, at: path)
    }
    AgentKeymap.bind(into: &registry, at: path)
  }

  /// Removes the scope node at `path`.
  ///
  /// With no node, the resolution walk does not get to the commands and the
  /// keys of the path.
  ///
  /// - Parameters:
  ///   - path: The path of the scope.
  ///   - registry: The registry to remove the node from.
  static func deregister(at path: FocusPath, from registry: inout CommandRegistry) {
    registry.tree = ScopeTree(registry.tree.nodes.filter { $0.path != path })
  }
}

/// The zero-size view that keeps a target current and its registration
/// live.
///
/// SwiftUI calls `updateNSView` after each change to the values, so the
/// target always has the current thread, actions, and parts. The teardown
/// removes the registration and the parts that this mount gave.
struct AgentCommandMount: NSViewRepresentable {
  /// The values of a scope that the mount owns.
  struct Scope {
    /// The system to register in.
    let system: CommandSystem
    /// The path of the scope.
    let path: FocusPath
    /// The thread of the scope.
    let thread: AgentThread
    /// The actions that the commands call.
    let actions: any AgentThreadActions
    /// The pasteboard of the copy command.
    let pasteboard: any Pasteboard
  }

  /// The target to keep current.
  let target: AgentCommandTarget

  /// The scope that the mount owns, or `nil` when the mount only adds parts
  /// to the scope of an ancestor.
  let scope: Scope?

  /// The scroll anchors to add, or `nil`.
  let anchors: ScrollAnchorManager?

  /// The store of the expanded items to add, or `nil`.
  let expandedBlocks: ExpandedBlocksStore?

  /// The values that the teardown needs.
  final class Coordinator {
    /// The target of the mount.
    let target: AgentCommandTarget
    /// The system and the path of the owned scope, or `nil`.
    var registration: (system: CommandSystem, path: FocusPath)?
    /// The scroll anchors that the mount added.
    weak var anchors: ScrollAnchorManager?
    /// The store that the mount added.
    weak var expandedBlocks: ExpandedBlocksStore?

    /// Makes a coordinator for `target`.
    ///
    /// - Parameter target: The target of the mount.
    init(target: AgentCommandTarget) {
      self.target = target
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(target: target)
  }

  func makeNSView(context: Context) -> NSView {
    apply(to: context.coordinator)
    return NSView(frame: .zero)
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    apply(to: context.coordinator)
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    let target = coordinator.target
    if let registration = coordinator.registration {
      AgentCommandRegistration.deregister(
        at: registration.path, from: &registration.system.registry)
    }
    if let anchors = coordinator.anchors, target.anchors === anchors {
      target.anchors = nil
    }
    if let store = coordinator.expandedBlocks, target.expandedBlocks === store {
      target.expandedBlocks = nil
    }
  }

  /// Writes the values to the target, and registers the owned scope.
  ///
  /// - Parameter coordinator: The coordinator that records the values for
  ///   the teardown.
  private func apply(to coordinator: Coordinator) {
    if let scope {
      target.thread = scope.thread
      target.actions = scope.actions
      target.pasteboard = scope.pasteboard
      target.system = scope.system
      target.path = scope.path
      AgentCommandRegistration.register(target, at: scope.path, into: &scope.system.registry)
      coordinator.registration = (scope.system, scope.path)
    }
    if let anchors {
      target.anchors = anchors
      coordinator.anchors = anchors
    }
    if let expandedBlocks {
      target.expandedBlocks = expandedBlocks
      coordinator.expandedBlocks = expandedBlocks
    }
  }
}

// MARK: - Composer

/// The view behind the editor of a composer that gives the composer to the
/// agent commands.
///
/// The view is an EditorKit `GeometryProbeView` with the size of the editor.
/// ``AgentCommandVerb/focusComposer`` asks the probe to focus the view at its
/// center, which is the editor.
struct ComposerCommandProbe: NSViewRepresentable {
  /// The target of the scope.
  let target: AgentCommandTarget

  /// Tells if a submit sends or queues the text now.
  let canSubmit: @MainActor () -> Bool

  /// Submits the text of the composer.
  let submit: @MainActor () -> Void

  /// Replaces the text of the composer with the argument.
  let load: @MainActor (String) -> Void

  /// The values that the teardown needs.
  final class Coordinator {
    /// The target that the probe registered in.
    var target: AgentCommandTarget

    /// Makes a coordinator for `target`.
    ///
    /// - Parameter target: The target of the scope.
    init(target: AgentCommandTarget) {
      self.target = target
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(target: target)
  }

  func makeNSView(context: Context) -> GeometryProbeView {
    let probe = GeometryProbeView(frame: .zero)
    register(probe, coordinator: context.coordinator)
    return probe
  }

  func updateNSView(_ probe: GeometryProbeView, context: Context) {
    register(probe, coordinator: context.coordinator)
  }

  func sizeThatFits(
    _ proposal: ProposedViewSize, nsView: GeometryProbeView, context: Context
  ) -> CGSize? {
    proposal.replacingUnspecifiedDimensions(by: .zero)
  }

  static func dismantleNSView(_ probe: GeometryProbeView, coordinator: Coordinator) {
    coordinator.target.removeComposer(owner: ObjectIdentifier(probe))
  }

  /// Registers the composer hook of `probe` in the target.
  ///
  /// - Parameters:
  ///   - probe: The probe view.
  ///   - coordinator: The coordinator that records the target.
  private func register(_ probe: GeometryProbeView, coordinator: Coordinator) {
    if coordinator.target !== target {
      coordinator.target.removeComposer(owner: ObjectIdentifier(probe))
      coordinator.target = target
    }
    target.composer = AgentComposerHook(
      owner: ObjectIdentifier(probe), canSubmit: canSubmit, submit: submit, load: load,
      focus: { [weak probe] in probe?.requestFocus() ?? false })
  }
}
