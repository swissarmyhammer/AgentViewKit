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
/// A tap on the view selects the attachment in the ``InspectorSelection`` of
/// the environment. Then the inspector shows the file.
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
  @Environment(\.inspectorSelection) private var selection

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
    identifierPrefix + renderer.rawValue
  }

  public var body: some View {
    if let registered = registry.resolve(type: attachment.type) {
      registered(attachment.url)
        .modifier(SelectOnTap(action: select))
    } else {
      let renderer = Self.renderer(for: attachment.type)
      AttachmentPreview(attachment: attachment, renderer: renderer)
        .modifier(SelectOnTap(action: select))
        .accessibilityElement(children: renderer == .chip ? .combine : .contain)
        .accessibilityIdentifier(Self.identifier(for: renderer))
    }
  }

  /// Selects the attachment in the inspector selection of the environment.
  private func select() {
    selection?.select(attachment)
  }
}

/// Runs an action on a tap and on the default accessibility action.
private struct SelectOnTap: ViewModifier {
  /// The action to run.
  let action: () -> Void

  func body(content: Content) -> some View {
    content
      .contentShape(.rect)
      .onTapGesture(perform: action)
      .accessibilityAction(.default, action)
      .help("Show in the inspector")
  }
}
