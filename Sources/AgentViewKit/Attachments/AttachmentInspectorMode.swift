import FoundationModelsACP
import SwiftUI

/// The attachment that the user selected in one ``AgentThreadView``, for the
/// inspector of the host (AVK-10).
///
/// The value holds the file and the id of the session of the thread view.
/// One host binding can serve more than one thread view, so the session id
/// tells the host which thread the user pressed.
public nonisolated struct AgentAttachmentSelection: Hashable, Sendable {
  /// The selected file.
  public let attachment: Attachment

  /// The id of the session of the thread view that the user pressed.
  public let sessionId: SessionId

  /// Makes the selection of a file in the thread view of a session.
  ///
  /// - Parameters:
  ///   - attachment: The selected file.
  ///   - sessionId: The id of the session of the thread view.
  public init(attachment: Attachment, sessionId: SessionId) {
    self.attachment = attachment
    self.sessionId = sessionId
  }
}

/// The inspector that shows the attachment that a press in an
/// ``AgentThreadView`` selects (AVK-10).
///
/// Give the mode with ``SwiftUI/View/agentAttachmentInspector(_:)``. The
/// default is ``builtIn``.
public enum AttachmentInspectorMode {
  /// The thread view shows the attachment in its own trailing inspector. See
  /// ``SwiftUI/View/attachmentInspector(selection:)``. This is the default.
  case builtIn

  /// The thread view applies no inspector. A press on an attachment writes
  /// an ``AgentAttachmentSelection`` to the binding, and the host shows the
  /// file in its own inspector, for example with ``AttachmentInspector``.
  /// The host closes its inspector with a write of `nil`.
  case host(Binding<AgentAttachmentSelection?>)
}

/// The place where a press on an attachment in a thread view in the host
/// mode writes its selection: the binding of the host and the session id of
/// the thread view.
struct HostAttachmentTarget {
  /// The binding of the host.
  let selection: Binding<AgentAttachmentSelection?>

  /// The id of the session of the thread view.
  let sessionId: SessionId

  /// Writes the selection of `attachment` in the thread view to the binding
  /// of the host.
  ///
  /// - Parameter attachment: The selected file.
  func select(_ attachment: Attachment) {
    selection.wrappedValue = AgentAttachmentSelection(attachment: attachment, sessionId: sessionId)
  }
}

/// The action that selects a file for an inspector, after a press on an
/// ``AttachmentView`` or an ``ImageView``.
///
/// In a thread view in the host mode, the action writes to the binding of
/// the host. Otherwise it selects the file in the ``InspectorSelection`` of
/// the environment, when there is one.
struct AttachmentSelectAction {
  /// The target of the host mode, or `nil`.
  let hostTarget: HostAttachmentTarget?

  /// The inspector selection of the environment, or `nil`.
  let selection: InspectorSelection?

  /// Whether an inspector gets the selection of the action.
  var hasInspector: Bool {
    hostTarget != nil || selection != nil
  }

  /// Selects `attachment` for the inspector.
  ///
  /// - Parameter attachment: The file to select.
  func callAsFunction(_ attachment: Attachment) {
    if let hostTarget {
      hostTarget.select(attachment)
    } else {
      selection?.select(attachment)
    }
  }
}

extension EnvironmentValues {
  /// The inspector mode of each ``AgentThreadView`` in this view. The
  /// default is ``AttachmentInspectorMode/builtIn``.
  @Entry var agentAttachmentInspector: AttachmentInspectorMode = .builtIn

  /// The target of a press on an attachment in a thread view in the host
  /// mode, or `nil`. ``AgentThreadView`` sets it in the host mode only.
  @Entry var hostAttachmentTarget: HostAttachmentTarget? = nil

  /// The action that selects a file for the inspector of this view.
  var attachmentSelect: AttachmentSelectAction {
    AttachmentSelectAction(hostTarget: hostAttachmentTarget, selection: inspectorSelection)
  }
}

extension View {
  /// Sets the inspector that shows the attachment that a press in an
  /// ``AgentThreadView`` selects, for each thread view in this view.
  ///
  /// Apply the modifier one time at the root of a window. With
  /// ``AttachmentInspectorMode/host(_:)``, the thread views apply no
  /// `inspector(isPresented:content:)`. Use this mode when the window has
  /// its own inspector, such as a `NavigationSplitView` with an inspector:
  /// two inspectors make the minimum width of the column equal to the width
  /// of the window, and AppKit can then stop the app. All the thread views
  /// in the window share the binding, and each selection holds the session
  /// id of the thread view that the user pressed. The host shows the file,
  /// for example with ``AttachmentInspector``, whose actions Open, Reveal in
  /// Finder, Share, Save and Quick Look work in each mode. The host closes
  /// its inspector with a write of `nil` to the binding.
  ///
  /// For an example window, see `InspectorWindow` in
  /// `Examples/ReadmeSnippets/Snippets/HostInspector.swift`. The build
  /// compiles that snippet, and the README shows it.
  ///
  /// - Parameter mode: The inspector mode.
  /// - Returns: A view whose thread views use `mode`.
  public func agentAttachmentInspector(_ mode: AttachmentInspectorMode) -> some View {
    environment(\.agentAttachmentInspector, mode)
  }
}

/// Applies the inspector mode of a thread view to its content.
///
/// In the built-in mode, the modifier applies
/// ``SwiftUI/View/attachmentInspector(selection:)`` with `selection`. In the
/// host mode, it applies no inspector, and it gives a
/// ``HostAttachmentTarget`` with the session id of the thread to the
/// content.
struct ThreadAttachmentInspector: ViewModifier {
  /// The inspector mode of the thread view.
  let mode: AttachmentInspectorMode

  /// The id of the session of the thread view.
  let sessionId: SessionId

  /// The selection that the built-in inspector shows.
  let selection: InspectorSelection

  // FoundationModelsACP has a type `Content` too, so the parameter names the
  // content type of the modifier with `Self`.
  @ViewBuilder func body(content: Self.Content) -> some View {
    switch mode {
    case .builtIn:
      content.attachmentInspector(selection: selection)
    case .host(let binding):
      content.environment(
        \.hostAttachmentTarget, HostAttachmentTarget(selection: binding, sessionId: sessionId))
    }
  }
}
