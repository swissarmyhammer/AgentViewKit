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
///
/// The scope of a file view that selects its file for the inspector
/// (``InspectorSelectable``) gets the select action of the view, and then
/// also registers the ``AgentFileSelectionVerb`` commands, which the
/// Command-click and the Shift-click of the view run (card ^se9sxxe). Such a
/// scope also gives the selected files to the context of its commands while
/// its file is selected, so each attachment command on a selected file acts
/// on every selected file, in transcript order, and a command on a file
/// that is not selected acts on that file alone (card ^zsr2pbf,
/// ``AttachmentCommandFiles``).
struct AgentAttachmentScope: ViewModifier {
  /// The attachment of the scope.
  let attachment: Attachment

  /// The corners of the surface of the attachment, which the focus ring of
  /// the scope follows.
  let focusRingCorners: SurfaceCorners

  /// The action that changes the file selection for a press on the file
  /// view, or `nil` for a view that selects no file.
  let select: ((AttachmentSelectionChange) -> Void)?

  @Environment(\.commandSystem) private var ambientSystem
  @Environment(\.commandScopePath) private var parentPath
  @Environment(\.agentAttachmentScopeSegment) private var enclosingSegment
  @Environment(\.attachmentFileService) private var hostService
  @Environment(\.agentCommandGroupsOff) private var groupsOff
  @Environment(\.attachmentSelect) private var fileSelection

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
        service: hostService ?? presenter, groupsOff: groupsOff, select: select, selection: commandFiles)
      content
        .environment(\.agentAttachmentScopeSegment, segment)
        .background(AgentAttachmentMount(target: target, presenter: presenter, registration: registration))
        .modifier(AttachmentPresentation(presenter: presenter))
        .agentItemScope(segment, subject: attachment, focusRingCorners: focusRingCorners)
        .environment(\.agentCommandSystem, system)
        .commandSystem(system)
    }
  }

  /// Reads the selected files that a command at the scope acts on, or `nil`
  /// for a view that selects no file.
  private var commandFiles: (() -> [Attachment])? {
    guard select != nil else { return nil }
    return { [attachment, fileSelection] in fileSelection.commandFiles(at: attachment) }
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
  ///   - select: The action that changes the file selection for a press on
  ///     the view, the action of its ``InspectorSelectable``, or `nil` for a
  ///     view that selects no file. With an action, the scope registers the
  ///     ``AgentFileSelectionVerb`` commands that the view binds its
  ///     Command-click and its Shift-click to.
  /// - Returns: A view in the scope of the attachment, or this view.
  @ViewBuilder
  func agentAttachmentScope(
    _ attachment: Attachment?, focusRingCorners: SurfaceCorners = .card,
    select: ((AttachmentSelectionChange) -> Void)? = nil
  ) -> some View {
    if let attachment {
      modifier(AgentAttachmentScope(attachment: attachment, focusRingCorners: focusRingCorners, select: select))
    } else {
      self
    }
  }
}

extension EnvironmentValues {
  /// The segment of the nearest ``AgentAttachmentScope``, or `nil`.
  @Entry var agentAttachmentScopeSegment: FocusSegment? = nil
}

// MARK: - Presentation

/// Applies the file exporter and the Quick Look panel of an
/// ``AttachmentPresenter``.
///
/// The Save command writes the attachment to save, and the Quick Look command
/// writes the file to show, with the files to browse. Each panel clears its
/// value when it closes. A save of several files shows a save panel for each
/// file in turn: the update after a panel closes gives the exporter the next
/// file, so the exporter sees its panel close before it shows the next one.
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
          get: { exported != nil }, set: { if !$0 { presenter.exportDidClose() } }),
        document: exported.map { AttachmentDocument(url: $0.url) },
        contentType: exported?.type ?? .data,
        defaultFilename: exported?.name,
        onCompletion: { FileExportLog.record($0, of: exported?.name ?? "", to: logger) }
      )
      .onChange(of: exported) { presenter.exportNextFile() }
      .quickLookPreview($presenter.quickLookURL, in: presenter.quickLookURLs)
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
/// The coordinator is the ``AgentScopeMount`` that registers the commands at
/// the path. SwiftUI can make a newer view at the same path before it removes
/// the older view, and two windows that show one attachment have the same
/// path. The newest mount registers, and the teardown of an older mount does
/// not remove the commands of the newer mount. When the newer mount goes away
/// first, the path goes back to the older mount on the next pass of the main
/// run loop.
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
    /// The select action of the file view of the scope, or `nil` when the
    /// view selects no file.
    let select: ((AttachmentSelectionChange) -> Void)?
    /// Reads the selected files that a command at the scope acts on, or
    /// `nil` when the view selects no file
    /// (``AgentAttachmentTarget/selection``).
    let selection: (() -> [Attachment])?
  }

  /// The target to keep current.
  let target: AgentAttachmentTarget

  /// The presenter whose share picker shows at this view.
  let presenter: AttachmentPresenter

  /// The current registration of the scope.
  let registration: Registration

  func makeCoordinator() -> AgentScopeMount {
    AgentScopeMount(unregister: AgentAttachmentRegistration.deregister(at:from:))
  }

  func makeNSView(context: Context) -> NSView {
    let anchor = NSView(frame: .zero)
    apply(anchor: anchor, scopeMount: context.coordinator)
    return anchor
  }

  func updateNSView(_ anchor: NSView, context: Context) {
    apply(anchor: anchor, scopeMount: context.coordinator)
  }

  static func dismantleNSView(_ anchor: NSView, coordinator: AgentScopeMount) {
    coordinator.unmount()
  }

  /// Writes the values to the target and the presenter, and registers the
  /// commands at the current path: the file selection commands too when the
  /// registration has a select action.
  ///
  /// A change of the path or of the system ends the registration at the old
  /// place first.
  ///
  /// - Parameters:
  ///   - anchor: The view of the mount.
  ///   - scopeMount: The coordinator, which holds the path.
  private func apply(anchor: NSView, scopeMount: AgentScopeMount) {
    presenter.anchor = anchor
    target.service = registration.service
    target.select = registration.select
    target.selection = registration.selection
    scopeMount.mount(at: registration.path, in: registration.system) {
      [target, path = registration.path, groupsOff = registration.groupsOff,
        selects = registration.select != nil] registry in
      AgentAttachmentRegistration.register(
        target, at: path, into: &registry, groupsOff: groupsOff, selects: selects)
    }
  }
}
