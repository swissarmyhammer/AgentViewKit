import SwiftUI

/// The view of one content block of a message (plan.md §3.6, §9 A2).
///
/// The view uses the registration of the ``ContentBlockRegistry`` for the
/// kind of the block when there is one. See
/// ``SwiftUI/View/contentBlockView(for:_:)``. Otherwise it uses the default
/// view of the kind:
///
/// - text: a ``ResponseView``, through Textual.
/// - image: an ``ImageView``. A tap selects the image in the inspector.
/// - audio: an ``AudioPlayerView``, through AVKit.
/// - resource link: a ``LinkView`` card that opens the link in the browser.
/// - resource: the text through Textual, or an ``AttachmentChip`` for binary
///   contents.
/// - attachment: an ``AttachmentView``.
/// - structured: the registration of the schema name, or a
///   ``StructuredItemView``. See ``SwiftUI/View/structuredItem(_:_:)``.
/// - unknown: an ``UnknownItemView``.
///
/// Each default view is an accessibility container with the identifier
/// `content-block-<kind>`. A block that is not for the user shows nothing
/// and has no accessibility element.
public struct ContentBlockView: View {
  /// The start of the accessibility identifier of each default view.
  public static let identifierPrefix = "content-block-"

  /// The block to show.
  let block: ContentBlock

  /// The id of the block view.
  let id: String

  @Environment(\.contentBlockRegistry) private var registry

  /// Makes the view of a content block.
  ///
  /// - Parameters:
  ///   - block: The block to show.
  ///   - id: The id of the block view, unique in the thread, such as
  ///     `<message id>-<block index>`. The text view keys its code blocks by
  ///     this id, and the structured and unknown views key their expanded
  ///     state by it.
  public init(block: ContentBlock, id: String) {
    self.block = block
    self.id = id
  }

  /// The accessibility identifier of the default view of a kind.
  ///
  /// - Parameter kind: The block kind.
  /// - Returns: `content-block-<kind>`, such as `content-block-resourceLink`.
  public static func identifier(for kind: ContentBlock.Kind) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: String(describing: kind))
  }

  public var body: some View {
    if block.isVisible(to: .user) {
      if let renderer = registry.resolve(kind: block.kind) {
        renderer(block)
      } else {
        defaultView
          .contentContainer(identifier: Self.identifier(for: block.kind))
      }
    }
  }

  /// The default view of the kind of the block.
  @ViewBuilder private var defaultView: some View {
    switch block.content {
    case .text(let text):
      TextBlockView(text: text, id: id)
    case .image(let image):
      ImageView(image: image)
    case .audio(let audio):
      AudioPlayerView(audio: audio)
    case .resourceLink(let link):
      LinkView(link: link)
    case .resource(let resource):
      ResourceBlockView(resource: resource)
    case .attachment(let url):
      AttachmentView(Attachment(url: url))
    case .structured(let schemaName, let payload):
      RegisteredStructuredView(
        content: StructuredItemContent(schemaName: schemaName, payload: payload), id: id)
    case .unknown(let kind, let raw):
      UnknownItemView(kind: kind, raw: raw, id: id)
    }
  }
}
