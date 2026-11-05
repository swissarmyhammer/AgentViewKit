import EditorStyle
import SwiftUI
import UniformTypeIdentifiers

/// The view of an attached file (plan.md §3.6, §9 F).
///
/// The view uses the registration of the attachment registry for the type of
/// the file, or for its nearest supertype. See
/// ``SwiftUI/View/attachmentView(for:_:)``. When the type has no
/// registration, the view uses the default renderer of the type. See
/// ``renderer(for:)``.
///
/// A click on the view selects the attachment in the ``InspectorSelection``
/// of the environment. Then the inspector shows the file. A Command-click
/// adds the attachment to the selection or takes it out, and a Shift-click
/// adds each file from the anchor to it, in transcript order; the actions
/// Add to Selection and Extend Selection do the same. In an
/// ``AgentThreadView`` in the host mode
/// (``SwiftUI/View/agentAttachmentInspector(_:)``), a press changes the list
/// of ``AgentAttachmentSelection`` values of the binding of the host.
///
/// The view is the scope of its attachment (`agentAttachment:<id>`, AVK-11):
/// its context menu and the command palette show the ``AgentAttachmentVerb``
/// commands for the file.
///
/// `Docs/decisions/attachment-types.md` records the default renderer of each
/// type.
public struct AttachmentView: View {
  /// A default view of a file.
  public enum Renderer: String, CaseIterable, Sendable {
    /// A preview of the image.
    case image
    /// A thumbnail of the document from QuickLook.
    case pdf
    /// The text through Textual.
    case text
    /// The text in a ``CodeBlockView``.
    case code
    /// An AVKit player with the controls only.
    case audio
    /// An AVKit player.
    case movie
    /// An ``AttachmentChip``.
    case chip
  }

  /// The start of the accessibility identifier of each default renderer.
  public static let identifierPrefix = "attachment-"

  /// The types that have a default renderer, in the order that
  /// ``renderer(for:)`` checks them.
  ///
  /// A source file conforms to `public.plain-text` too, so
  /// `public.source-code` comes before `public.plain-text`.
  private static let conformanceOrder: [(type: UTType, renderer: Renderer)] = [
    (.image, .image),
    (.pdf, .pdf),
    (.sourceCode, .code),
    (.plainText, .text),
    (.audio, .audio),
    (.movie, .movie),
  ]

  /// The attached file.
  let attachment: Attachment

  @Environment(\.attachmentRegistry) private var registry
  @Environment(\.attachmentSelect) private var selectForInspector

  /// Makes the view of an attached file.
  ///
  /// - Parameter attachment: The attached file.
  public init(_ attachment: Attachment) {
    self.attachment = attachment
  }

  /// The default renderer of a type.
  ///
  /// - Parameter type: The type of the file.
  /// - Returns: The renderer of the first type in the conformance order that
  ///   `type` conforms to, or ``Renderer/chip``.
  public static func renderer(for type: UTType) -> Renderer {
    conformanceOrder.first { type.conforms(to: $0.type) }?.renderer ?? .chip
  }

  /// The name of the default renderer of a type, as the decision table
  /// writes it.
  ///
  /// - Parameter type: The type of the file.
  /// - Returns: The raw value of ``renderer(for:)``.
  public static func defaultRenderer(for type: UTType) -> String {
    renderer(for: type).rawValue
  }

  /// The accessibility identifier of a default renderer, such as
  /// `attachment-code`.
  ///
  /// - Parameter renderer: The renderer.
  /// - Returns: The identifier.
  public static func identifier(for renderer: Renderer) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: renderer.rawValue)
  }

  /// The corners that the shown surface of the default renderer reports
  /// (``AttachmentSurfaceCornersKey``), or `nil` while no surface reports
  /// them.
  @State private var shownCorners: SurfaceCorners?

  public var body: some View {
    renderedFile
      .onPreferenceChange(AttachmentSurfaceCornersKey.self) { shownCorners = $0 }
      .agentAttachmentScope(attachment, focusRingCorners: surfaceCorners)
  }

  /// The corners of the view of the file, which the focus ring of the scope
  /// follows: the corners that the shown surface of the default renderer
  /// reports, and square corners for a surface that reports none, such as a
  /// loaded preview, which has no rounded surface. A registered view keeps
  /// square corners, because the kit does not know its surface.
  ///
  /// The chip reports its corners. So the ring has the corners of the chip
  /// both when the default renderer is the chip and when a preview that
  /// cannot load its file shows the chip in its place. Only the value of the
  /// corners changes, so the view keeps its identity and its state.
  private var surfaceCorners: SurfaceCorners {
    guard registry.resolve(type: attachment.type) == nil else { return .square }
    return shownCorners ?? .square
  }

  /// The registered view of the file, or its default renderer.
  @ViewBuilder private var renderedFile: some View {
    if let registered = registry.resolve(type: attachment.type) {
      registered(attachment.url)
        .modifier(InspectorSelectable(file: attachment, corners: surfaceCorners, action: select))
    } else {
      let renderer = Self.renderer(for: attachment.type)
      AttachmentPreview(attachment: attachment, renderer: renderer)
        .modifier(InspectorSelectable(file: attachment, corners: surfaceCorners, action: select))
        .accessibilityElement(children: renderer == .chip ? .combine : .contain)
        .accessibilityIdentifier(Self.identifier(for: renderer))
    }
  }

  /// Changes the selection of the inspector of the environment for a press
  /// on the attachment: the inspector of the host in the host mode of a
  /// thread view, otherwise the inspector selection.
  ///
  /// - Parameter change: The kind of the press.
  private func select(_ change: AttachmentSelectionChange) {
    selectForInspector(attachment, change: change)
  }
}

/// The preference that carries the corners of the surface that an
/// ``AttachmentView`` shows, such as the ``AttachmentChip`` that a preview
/// shows when it cannot load its file.
///
/// The value is `nil` when no surface in the view reports its corners.
struct AttachmentSurfaceCornersKey: PreferenceKey {
  static var defaultValue: SurfaceCorners? { nil }

  /// Keeps the first corners that a surface reports.
  ///
  /// - Parameters:
  ///   - value: The corners of the surfaces so far.
  ///   - nextValue: The corners of the next surface.
  static func reduce(value: inout SurfaceCorners?, nextValue: () -> SurfaceCorners?) {
    value = value ?? nextValue()
  }
}

/// Makes a file view select its file for the inspector, and shows the
/// selected state while the inspector shows that file (card ^dn1m56r).
///
/// A press runs `action` with the kind of the press, the selection model of
/// EditorKit's lists (card ^4138tmp): a click and the default accessibility
/// action select, a Command-click adds or takes out
/// (``AttachmentSelectionChange/toggle``), and a Shift-click extends
/// (``AttachmentSelectionChange/extend``). The view has a named
/// accessibility action for each kind, Select, Add to Selection and Extend
/// Selection, so VoiceOver and a test do what each click does.
///
/// The view places its file in the ``TranscriptFileOrder`` of the
/// environment, with the position of its row and its frame in that row, so
/// that an extend reads the files of the thread in transcript order.
///
/// While the inspector of the environment shows `file`
/// (``AttachmentSelectAction/isSelected(_:)``), the view sits on the shared
/// selection surface of EditorKit: the accent at a low opacity behind the
/// view while the window is key, and the inactive grey while it is not. The
/// text of the view stays `.primary`.
///
/// The surface has the corners of the view, the same corners that the focus
/// ring of its attachment scope follows (``SurfaceCorners``), and a tap
/// lands in the same shape (``SelectableSurface``). The corners of an
/// ``AttachmentView`` change when its preview shows the chip, and only the
/// value of the radius changes, so the view keeps its identity and its state.
///
/// ``AttachmentView``, ``ImageView`` and the location chips of a tool call
/// use this modifier.
struct InspectorSelectable: ViewModifier {
  /// The file of the view.
  let file: Attachment

  /// The corners of the surface of the view.
  let corners: SurfaceCorners

  /// The action that changes the selection of the inspector for a press of
  /// a kind.
  let action: (AttachmentSelectionChange) -> Void

  @Environment(\.attachmentSelect) private var selectForInspector
  @Environment(\.transcriptFileOrder) private var order
  @Environment(\.transcriptRowPosition) private var row

  /// The id of the view in the transcript order.
  @State private var viewID = UUID()

  func body(content: Content) -> some View {
    let isInRow = row != nil
    return content
      .selectableSurface(selectForInspector.isSelected(file), corners: corners)
      .gesture(pressGesture)
      .accessibilityAction(.default) { action(.select) }
      .accessibilityActions {
        ForEach(AttachmentSelectionChange.allCases, id: \.self) { change in
          Button(change.actionName) { action(change) }
        }
      }
      .help(String(localized: "Show in the inspector", bundle: .module))
      .onGeometryChange(for: CGRect.self, of: { Self.frame(of: $0, isInRow: isInRow) }) { frame in
        order?.place(file, row: row, frame: frame, view: viewID)
      }
      .onDisappear { order?.remove(view: viewID) }
  }

  /// The press on the view: a Shift-click extends, a Command-click toggles,
  /// and a click selects. A Shift-click with Command held extends.
  private var pressGesture: some Gesture {
    tap(.shift, .extend)
      .exclusively(before: tap(.command, .toggle))
      .exclusively(before: TapGesture().onEnded { action(.select) })
  }

  /// A click with a modifier key.
  ///
  /// - Parameters:
  ///   - modifier: The modifier key of the click.
  ///   - change: The kind of the press that the click runs.
  /// - Returns: The tap gesture.
  private func tap(_ modifier: EventModifiers, _ change: AttachmentSelectionChange) -> some Gesture {
    TapGesture().modifiers(modifier).onEnded { action(change) }
  }

  /// The frame of a view in the transcript order: in its row, or in the
  /// window outside each row.
  ///
  /// - Parameters:
  ///   - proxy: The geometry of the view.
  ///   - isInRow: Whether the view is in a row of a thread.
  /// - Returns: The frame.
  private nonisolated static func frame(of proxy: GeometryProxy, isInRow: Bool) -> CGRect {
    isInRow ? proxy.frame(in: .named(TranscriptFileOrder.rowSpace)) : proxy.frame(in: .global)
  }
}

#Preview("Attachment") {
  VStack(alignment: .leading) {
    ForEach(PreviewFixtures.attachments) { attachment in
      AttachmentView(attachment)
    }
  }
}
