import AppKit
import EditorCommands
import EditorCommandsUI
import OSLog
import QuickLook
import SwiftUI

/// The focus scope of one attachment, with its commands (AVK-11, D108).
///
/// The modifier adds the segment `agentAttachment:<id>` to the path of the
/// enclosing scope, or starts a root path when there is none. It gives the
/// ``Attachment`` as the subject of that segment, and registers one
/// ``AgentAttachmentVerb`` command for each verb at that path. It is an item
/// scope (``AgentItemScope``): it has the EditorKit context menu of its path,
/// a jump label, and the area of the view for the `nav.*` commands.
///
/// When no ancestor installs a system with `.commandSystem(_:)`, the scope
/// uses a private system, as ``AgentCommandScope`` does. Thus the buttons and
/// the context menu of an attachment work also in the inspector of a host,
/// outside each thread scope.
///
/// The commands run on the service of
/// ``SwiftUI/EnvironmentValues/attachmentFileService``, or on the
/// ``AttachmentPresenter`` of the scope when the environment has none. The
/// scope applies the file exporter and the Quick Look panel of its presenter.
///
/// A scope inside a scope for the same attachment, for example the chip of
/// an ``AttachmentView``, does not make a second scope.
struct AgentAttachmentScope: ViewModifier {
  /// The attachment of the scope.
  let attachment: Attachment

  /// The corners of the surface of the attachment, which the focus ring of
  /// the scope follows.
  let focusRingCorners: AgentSurfaceCorners

  @Environment(\.commandSystem) private var ambientSystem
  @Environment(\.commandScopePath) private var parentPath
  @Environment(\.agentAttachmentScopeSegment) private var enclosingSegment
  @Environment(\.attachmentFileService) private var hostService
  @Environment(\.agentCommandGroupsOff) private var groupsOff

  /// The target of this scope.
  @State private var target = AgentAttachmentTarget()

  /// The system service of this scope.
  @State private var presenter = AttachmentPresenter()

  /// The system that the scope uses when no ancestor installs one.
  @State private var standaloneSystem = CommandSystem()

  func body(content: Content) -> some View {
    let segment = AgentScopeKind.attachment(attachment.id)
    if enclosingSegment == segment {
      content
    } else {
      let system = ambientSystem ?? standaloneSystem
      let registration = AgentAttachmentMount.Registration(
        system: system, path: parentPath?.appending(segment) ?? .root(segment),
        service: hostService ?? presenter, groupsOff: groupsOff)
      content
        .environment(\.agentAttachmentTarget, target)
        .environment(\.agentAttachmentScopeSegment, segment)
        .background(AgentAttachmentMount(target: target, presenter: presenter, registration: registration))
        .modifier(AttachmentPresentation(presenter: presenter))
        .agentItemScope(segment, subject: attachment, focusRingCorners: focusRingCorners)
        .environment(\.agentCommandSystem, system)
        .commandSystem(system)
    }
  }
}

extension View {
  /// Puts this view in the scope of `attachment`, with the attachment
  /// commands at the path of the scope.
  ///
  /// The focus ring of the scope follows the corners of the surface of the
  /// view, which `focusRingCorners` names. A scope inside a scope for the
  /// same attachment makes no scope, so the corners of the outer scope hold.
  ///
  /// - Parameters:
  ///   - attachment: The attachment of the scope, or `nil` for no scope, for
  ///     example an artifact with no file.
  ///   - focusRingCorners: The corners of the surface of the view. The
  ///     default is the corners of a card.
  /// - Returns: A view in the scope of the attachment, or this view.
  @ViewBuilder
  func agentAttachmentScope(
    _ attachment: Attachment?, focusRingCorners: AgentSurfaceCorners = .card
  ) -> some View {
    if let attachment {
      modifier(AgentAttachmentScope(attachment: attachment, focusRingCorners: focusRingCorners))
    } else {
      self
    }
  }
}

extension EnvironmentValues {
  /// The target of the nearest ``AgentAttachmentScope``, or `nil`.
  /// ``AttachmentActions`` dispatches its buttons through it.
  @Entry var agentAttachmentTarget: AgentAttachmentTarget? = nil

  /// The segment of the nearest ``AgentAttachmentScope``, or `nil`.
  @Entry var agentAttachmentScopeSegment: FocusSegment? = nil
}

// MARK: - Presentation

/// Applies the file exporter and the Quick Look panel of an
/// ``AttachmentPresenter``.
///
/// The Save command writes the attachment to save, and the Quick Look command
/// writes the file to show. Each panel clears its value when it closes.
private struct AttachmentPresentation: ViewModifier {
  /// The presenter of the scope.
  @Bindable var presenter: AttachmentPresenter

  /// The log of a save that fails.
  private let logger = Logger(subsystem: "AgentViewKit", category: "AttachmentPresentation")

  func body(content: Content) -> some View {
    // The body reads the attachment itself, so that a new value evaluates
    // the body again. A read in a binding closure is not tracked.
    let exported = presenter.exportedAttachment
    content
      .fileExporter(
        isPresented: Binding(
          get: { exported != nil }, set: { if !$0 { presenter.exportedAttachment = nil } }),
        document: exported.map { AttachmentDocument(url: $0.url) },
        contentType: exported?.type ?? .data,
        defaultFilename: exported?.name,
        onCompletion: { FileExportLog.record($0, of: exported?.name ?? "", to: logger) }
      )
      .quickLookPreview($presenter.quickLookURL)
  }
}

// MARK: - Mount

/// The zero-size view that keeps the target of an attachment scope current
/// and its commands registered.
///
/// SwiftUI calls `updateNSView` after each change to the values, so the
/// target always has the current service, system and path. The view is also
/// the place where the share picker of the ``AttachmentPresenter`` shows: it
/// is in the background of the attachment, with its size.
///
/// The mount holds its path in `CommandSystem.mountHolders`. SwiftUI can make
/// a newer view at the same path before it removes the older view, so the
/// older mount does not register again, and its teardown does not remove the
/// commands of the newer mount.
struct AgentAttachmentMount: NSViewRepresentable {
  /// The values of the registration of a scope.
  struct Registration {
    /// The system to register in.
    let system: CommandSystem
    /// The path of the scope.
    let path: FocusPath
    /// The service that runs the verbs.
    let service: any AttachmentFileService
    /// The groups of the commands that the scope does not register.
    let groupsOff: Set<AgentCommandGroup>
  }

  /// The target to keep current.
  let target: AgentAttachmentTarget

  /// The presenter whose share picker shows at this view.
  let presenter: AttachmentPresenter

  /// The current registration of the scope.
  let registration: Registration

  /// The system and the path that the mount registered at, for the teardown.
  final class Coordinator {
    /// The system and the path of the last registration, or `nil`.
    var registered: (system: CommandSystem, path: FocusPath)?
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSView {
    let anchor = NSView(frame: .zero)
    apply(anchor: anchor, coordinator: context.coordinator)
    return anchor
  }

  func updateNSView(_ anchor: NSView, context: Context) {
    apply(anchor: anchor, coordinator: context.coordinator)
  }

  static func dismantleNSView(_ anchor: NSView, coordinator: Coordinator) {
    release(coordinator)
  }

  /// Removes the commands of the last registration of `coordinator`, when
  /// no newer mount holds its path.
  ///
  /// - Parameter coordinator: The coordinator of the mount.
  private static func release(_ coordinator: Coordinator) {
    guard let registered = coordinator.registered else { return }
    coordinator.registered = nil
    guard registered.system.mountHolders.release(at: registered.path, by: coordinator) else { return }
    AgentAttachmentRegistration.deregister(at: registered.path, from: &registered.system.registry)
  }

  /// Writes the values to the target and the presenter, and registers the
  /// commands at the current path.
  ///
  /// A change of the path or of the system removes the registration at the
  /// old place first.
  ///
  /// - Parameters:
  ///   - anchor: The view of the mount.
  ///   - coordinator: The coordinator that records the registration.
  private func apply(anchor: NSView, coordinator: Coordinator) {
    presenter.anchor = anchor
    target.service = registration.service
    target.system = registration.system
    target.path = registration.path
    if let registered = coordinator.registered,
      registered.path != registration.path || registered.system !== registration.system
    {
      Self.release(coordinator)
    }
    let system = registration.system
    guard !system.mountHolders.isHeld(at: registration.path, byOtherThan: coordinator) else { return }
    system.mountHolders.hold(at: registration.path, by: coordinator)
    AgentAttachmentRegistration.register(
      target, at: registration.path, into: &system.registry, groupsOff: registration.groupsOff)
    coordinator.registered = (system, registration.path)
  }
}
