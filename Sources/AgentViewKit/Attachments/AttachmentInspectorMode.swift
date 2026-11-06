import FoundationModelsACP
import SwiftUI

/// One attachment that the user selected in one ``AgentThreadView``, for the
/// inspector of the host (AVK-10).
///
/// The value holds the file and the id of the session of the thread view.
/// The binding of the host holds a list of these values, in selection order
/// (``AttachmentInspectorMode/host(_:)``). One host binding can serve more
/// than one thread view, so the session id tells the host which thread the
/// user pressed.
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

/// The inspector that shows the attachments that the presses in an
/// ``AgentThreadView`` select (AVK-10, card ^4138tmp).
///
/// Give the mode with ``SwiftUI/View/agentAttachmentInspector(_:)``. The
/// default is ``builtIn``.
public enum AttachmentInspectorMode {
  /// The thread view shows the attachments in its own trailing inspector.
  /// See ``SwiftUI/View/attachmentInspector(selection:)``. This is the
  /// default.
  case builtIn

  /// The thread view applies no inspector. A press on an attachment changes
  /// the list of ``AgentAttachmentSelection`` values of the binding, in
  /// selection order, with the selection model of EditorKit's lists: a click
  /// writes a list of the one file, a Command-click adds the file to the end
  /// of the list or takes it out, and a Shift-click adds each file from the
  /// anchor of the thread view to the file, in transcript order. A click
  /// replaces the files of each thread view, and a Command-click or a
  /// Shift-click keeps the files of the other thread views. The host shows
  /// the files in its own inspector, for example with
  /// ``AttachmentInspector``, which folds several files into one form. The
  /// host closes its inspector with a write of an empty list.
  case host(Binding<[AgentAttachmentSelection]>)
}

/// The place where a press on an attachment in a thread view in the host
/// mode writes its selection: the binding of the host, the session id of the
/// thread view and the anchor of its presses.
@MainActor struct HostAttachmentTarget {
  /// The binding of the host, in selection order.
  let selection: Binding<[AgentAttachmentSelection]>

  /// The id of the session of the thread view.
  let sessionId: SessionId

  /// The anchor of the presses in the thread view, which the binding of the
  /// host does not hold.
  let anchor: AttachmentSelectionAnchor

  /// Applies one change of the selection model to the binding of the host.
  ///
  /// A select writes a list of the one file. A toggle or an extend changes
  /// the files of this thread view, and keeps the files of the other thread
  /// views where they are: a file that leaves the selection leaves the list,
  /// and each new file joins its end.
  ///
  /// - Parameters:
  ///   - change: The kind of the change.
  ///   - attachment: The file of the press.
  ///   - order: The files of the thread in transcript order.
  func apply(_ change: AttachmentSelectionChange, to attachment: Attachment, order: () -> [Attachment]) {
    let current = selection.wrappedValue
    var list = AttachmentSelectionList(files: current.filter(isOwn).map(\.attachment), anchor: anchor.url)
    list.apply(change, to: attachment, order: order)
    anchor.url = list.anchor
    let kept = change == .select ? [] : current.filter { !isOwn($0) || list.contains($0.attachment) }
    let added = list.files.filter { file in !kept.contains { isOwn($0) && $0.attachment.url == file.url } }
    selection.wrappedValue = kept + added.map { AgentAttachmentSelection(attachment: $0, sessionId: sessionId) }
  }

  /// Whether the inspector of the host shows `file` for the thread view.
  ///
  /// One binding can serve more than one thread view, so a file that the
  /// user selected in another thread view is not the selection of this one.
  /// The read compares the URL of the file (``AttachmentSelectAction/isSelected(_:)``).
  ///
  /// - Parameter file: The file of a view.
  /// - Returns: `true` when the binding holds a selection of this thread view
  ///   whose file has the URL of `file`.
  func isSelected(_ file: Attachment) -> Bool {
    selection.wrappedValue.contains { isOwn($0) && $0.attachment.url == file.url }
  }

  /// The files of the binding that the user selected in the thread view, in
  /// selection order. A file of another thread view is not one of them.
  var selectedFiles: [Attachment] {
    selection.wrappedValue.filter(isOwn).map(\.attachment)
  }

  /// Whether a selection of the binding is a file of this thread view.
  ///
  /// - Parameter selection: A selection of the binding.
  /// - Returns: `true` when the selection holds the session id of the
  ///   thread view.
  private func isOwn(_ selection: AgentAttachmentSelection) -> Bool {
    selection.sessionId == sessionId
  }
}

/// The action that changes the files of an inspector, after a press on an
/// ``AttachmentView``, an ``ImageView`` or a location chip of a tool call.
///
/// In a thread view in the host mode, the action writes to the binding of
/// the host. Otherwise it changes the ``InspectorSelection`` of the
/// environment, when there is one. An extend reads the files of the thread
/// in the ``TranscriptFileOrder`` of the environment.
@MainActor struct AttachmentSelectAction {
  /// The target of the host mode, or `nil`.
  let hostTarget: HostAttachmentTarget?

  /// The inspector selection of the environment, or `nil`.
  let selection: InspectorSelection?

  /// The transcript order of the files of the thread, or `nil`.
  let order: TranscriptFileOrder?

  /// Whether an inspector gets the selection of the action.
  var hasInspector: Bool {
    hostTarget != nil || selection != nil
  }

  /// Changes the files of the inspector for a press on `attachment`.
  ///
  /// - Parameters:
  ///   - attachment: The file of the press.
  ///   - change: The kind of the press. The default is a click.
  func callAsFunction(_ attachment: Attachment, change: AttachmentSelectionChange = .select) {
    let files = { order?.files ?? [] }
    if let hostTarget {
      hostTarget.apply(change, to: attachment, order: files)
    } else {
      selection?.apply(change, to: attachment, order: files)
    }
  }

  /// Whether the inspector that gets the selection of the action shows
  /// `file` now: the inspector of the host in the host mode of a thread
  /// view, otherwise the inspector selection.
  ///
  /// The read compares the URL of the file, not the whole attachment. A view
  /// can name its file with other fields than the attachment that a press
  /// selects: for example, an ``ImageView`` makes its attachment from the
  /// bytes and the MIME type of the block, before its block file exists,
  /// and a press selects `Attachment(url:)` of the written file.
  ///
  /// - Parameter file: The file of a view.
  /// - Returns: `true` when the inspector shows a file with the URL of
  ///   `file`.
  func isSelected(_ file: Attachment) -> Bool {
    if let hostTarget {
      return hostTarget.isSelected(file)
    }
    return selection?.attachments.contains { $0.url == file.url } ?? false
  }

  /// The files that a command at the scope of the view of `file` acts on
  /// (``AttachmentCommandFiles``, card ^zsr2pbf): the files that the
  /// inspector shows, in the transcript order of the thread, when it shows
  /// `file`, and none when it does not.
  ///
  /// - Parameter file: The file of a view.
  /// - Returns: The selected files in transcript order, or an empty list.
  func commandFiles(at file: Attachment) -> [Attachment] {
    let selected = hostTarget?.selectedFiles ?? selection?.attachments ?? []
    return AttachmentCommandFiles.files(at: file, selection: selected, order: order?.files ?? [])
  }
}

extension EnvironmentValues {
  /// The inspector mode of each ``AgentThreadView`` in this view. The
  /// default is ``AttachmentInspectorMode/builtIn``.
  @Entry var agentAttachmentInspector: AttachmentInspectorMode = .builtIn

  /// The target of a press on an attachment in a thread view in the host
  /// mode, or `nil`. ``AgentThreadView`` sets it in the host mode only.
  @Entry var hostAttachmentTarget: HostAttachmentTarget? = nil

  /// The action that changes the files of the inspector of this view.
  var attachmentSelect: AttachmentSelectAction {
    AttachmentSelectAction(
      hostTarget: hostAttachmentTarget, selection: inspectorSelection, order: transcriptFileOrder)
  }
}

extension View {
  /// Sets the inspector that shows the attachments that the presses in an
  /// ``AgentThreadView`` select, for each thread view in this view.
  ///
  /// Apply the modifier one time at the root of a window. With
  /// ``AttachmentInspectorMode/host(_:)``, the thread views apply no
  /// `inspector(isPresented:content:)`. Use this mode when the window has
  /// its own inspector, such as a `NavigationSplitView` with an inspector:
  /// two inspectors make the minimum width of the column equal to the width
  /// of the window, and AppKit can then stop the app. All the thread views
  /// in the window share the binding, a list in selection order, and each
  /// selection holds the session id of the thread view that the user
  /// pressed. The host shows the files, for example with
  /// ``AttachmentInspector``, which folds several files into one form that
  /// lists them, and whose actions Open, Reveal in Finder, Share, Save and
  /// Quick Look work in each mode on every file that it shows (card
  /// ^xbhtytm). The context menu and the keys of a selected
  /// file in a thread view run each action on every selected file of that
  /// thread view (card ^zsr2pbf). The host closes its inspector with a write of
  /// an empty list to the binding.
  ///
  /// For an example window, see `InspectorWindow` in the README.
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
/// ``HostAttachmentTarget`` with the session id of the thread and the anchor
/// of its presses to the content. In each mode it gives the content the
/// ``TranscriptFileOrder`` of the thread.
struct ThreadAttachmentInspector: ViewModifier {
  /// The inspector mode of the thread view.
  let mode: AttachmentInspectorMode

  /// The id of the session of the thread view.
  let sessionId: SessionId

  /// The selection that the built-in inspector shows.
  let selection: InspectorSelection

  /// The transcript order of the files of the thread.
  @State private var order = TranscriptFileOrder()

  /// The anchor of the presses of the thread in the host mode.
  @State private var hostAnchor = AttachmentSelectionAnchor()

  // FoundationModelsACP has a type `Content` too, so the parameter names the
  // content type of the modifier with `Self`.
  func body(content: Self.Content) -> some View {
    inspected(content).environment(\.transcriptFileOrder, order)
  }

  /// The content with the inspector of the mode.
  ///
  /// - Parameter content: The content of the thread view.
  /// - Returns: The content with the built-in inspector, or with the target
  ///   of the host.
  @ViewBuilder private func inspected(_ content: Self.Content) -> some View {
    switch mode {
    case .builtIn:
      content.attachmentInspector(selection: selection)
    case .host(let binding):
      content.environment(
        \.hostAttachmentTarget,
        HostAttachmentTarget(selection: binding, sessionId: sessionId, anchor: hostAnchor))
    }
  }
}
