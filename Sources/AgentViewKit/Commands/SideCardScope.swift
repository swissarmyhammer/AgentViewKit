import AppKit
import EditorCommands
import EditorCommandsUI
import FoundationModelsACPClient
import SwiftUI

/// The values that a side card gives to the target of its scope.
struct SideCardValues {
  /// The question of the card.
  let question: String

  /// The session model of the fork.
  let session: SessionModel

  /// The Open action of the host.
  let open: @MainActor () -> Void

  /// The Close action of the host.
  let close: @MainActor () -> Void

  /// The Send to Chat action of the host, or `nil` for the composer of the
  /// thread.
  let hostSend: (@MainActor (String) -> Void)?
}

/// The focus scope of one side card, with its commands (D205, D108).
///
/// The modifier adds the segment `agentSideCard:<sessionId>` to the path of
/// the enclosing scope, or starts a root path when there is none. It gives
/// the `SessionModel` of the fork as the subject of that segment, and
/// registers one ``SideCardVerb`` command for each verb at that path. It is
/// an item scope (``AgentItemScope``): it has the EditorKit context menu of
/// its path, a jump label, and the area of the card for the `nav.*`
/// commands. The card has a glass surface of its own, so it shows the focus
/// as the accent fill in the corners of a card.
///
/// When no ancestor installs a system with `.commandSystem(_:)`, the scope
/// uses a private system, as ``AgentAttachmentScope`` does. Thus the buttons
/// of a card work also outside a thread.
///
/// Send to Chat inserts the text in the composer of the agent command scope
/// around the card (``SwiftUI/EnvironmentValues/agentCommandTarget``), when
/// the host gives no action.
struct SideCardScope: ViewModifier {
  /// The target of the card.
  let target: SideCardTarget

  /// The values of the card.
  let values: SideCardValues

  @Environment(\.commandSystem) private var ambientSystem
  @Environment(\.commandScopePath) private var parentPath
  @Environment(\.agentCommandTarget) private var thread
  @Environment(\.agentCommandGroupsOff) private var groupsOff

  /// The system that the scope uses when no ancestor installs one.
  @State private var standaloneSystem = CommandSystem()

  func body(content: Content) -> some View {
    let segment = AgentScopeKind.sideCard(values.session.sessionId)
    let system = ambientSystem ?? standaloneSystem
    let registration = SideCardMount.Registration(
      system: system, path: parentPath?.appending(segment) ?? .root(segment), values: values,
      thread: thread, groupsOff: groupsOff)
    content
      .background(SideCardMount(target: target, registration: registration))
      .agentItemScope(segment, subject: values.session, focusLook: .fill(.card))
      .environment(\.agentCommandSystem, system)
      .commandSystem(system)
  }
}

/// The zero-size view that keeps the target of a side card scope current and
/// its commands registered.
///
/// SwiftUI calls `updateNSView` after each change to the values, so the
/// target always has the current fork, actions, system and path. The
/// coordinator is the ``AgentScopeMount`` that registers the commands at the
/// path, as for ``AgentAttachmentMount``.
struct SideCardMount: NSViewRepresentable {
  /// The values of the registration of a scope.
  struct Registration {
    /// The system to register in.
    let system: CommandSystem
    /// The path of the scope.
    let path: FocusPath
    /// The values of the card.
    let values: SideCardValues
    /// The target of the thread around the card, or `nil`.
    let thread: AgentCommandTarget?
    /// The groups of the commands that the scope does not register.
    let groupsOff: Set<AgentCommandGroup>
  }

  /// The target to keep current.
  let target: SideCardTarget

  /// The current registration of the scope.
  let registration: Registration

  func makeCoordinator() -> AgentScopeMount {
    AgentScopeMount(unregister: SideCardRegistration.deregister(at:from:))
  }

  func makeNSView(context: Context) -> NSView {
    apply(scopeMount: context.coordinator)
    return NSView(frame: .zero)
  }

  func updateNSView(_ anchor: NSView, context: Context) {
    apply(scopeMount: context.coordinator)
  }

  static func dismantleNSView(_ anchor: NSView, coordinator: AgentScopeMount) {
    coordinator.unmount()
  }

  /// Writes the values to the target, and registers the commands at the
  /// current path.
  ///
  /// - Parameter scopeMount: The coordinator, which holds the path.
  private func apply(scopeMount: AgentScopeMount) {
    let values = registration.values
    target.question = values.question
    target.session = values.session
    target.open = values.open
    target.close = values.close
    target.hostSend = values.hostSend
    target.thread = registration.thread
    scopeMount.mount(at: registration.path, in: registration.system) {
      [target, path = registration.path, groupsOff = registration.groupsOff] registry in
      SideCardRegistration.register(target, at: path, into: &registry, groupsOff: groupsOff)
    }
  }
}
