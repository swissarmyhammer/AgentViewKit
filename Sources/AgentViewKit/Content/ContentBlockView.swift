import FoundationModelsACP
import SwiftUI

/// The view of one content block of a message (plan.md §3.6, §9 A2).
///
/// The view shows a kit ``ContentBlock`` of a thread message, or an ACP
/// `ContentBlock` that a transcript entry of a `SessionModel` holds. The view
/// of an ACP block reads the ACP value directly, with no kit block between
/// the value and the view.
///
/// For an ACP block, the view uses the registration of the
/// ``ContentBlockRegistry`` for the kind of the block when there is one, and
/// gives it the ACP value. See ``SwiftUI/View/contentBlockView(for:_:)``. The
/// registry keys the ACP block, so a kit block always shows its default view.
/// Otherwise the view uses the default view of the kind:
///
/// - text: a ``ResponseView``, through Textual.
/// - image: an ``ImageView``. A tap selects the image in the inspector.
/// - audio: an ``AudioPlayerView``, through AVKit.
/// - resource link: a ``LinkView`` card that opens the link in the browser.
/// - resource: the text through Textual, or an ``AttachmentChip`` for binary
///   contents.
/// - attachment: an ``AttachmentView``.
/// - unknown: an ``UnknownItemView``.
///
/// Each default view is an accessibility container with the identifier
/// `content-block-<kind>`. A block that is not for the user shows nothing
/// and has no accessibility element.
public struct ContentBlockView: View {
  /// The start of the accessibility identifier of each default view.
  public static let identifierPrefix = "content-block-"

  /// The block to show: a kit block of a thread message, or an ACP block
  /// that a transcript entry holds.
  let source: BlockSource<ContentBlock, FoundationModelsACP.ContentBlock>

  /// The id of the block view.
  let id: String

  @Environment(\.contentBlockRegistry) private var registry

  /// Makes the view of a content block.
  ///
  /// - Parameters:
  ///   - block: The block to show.
  ///   - id: The id of the block view, unique in the thread, such as
  ///     `<message id>-<block index>`. The text view keys its code blocks by
  ///     this id, and the unknown view keys its expanded state by it.
  public init(block: ContentBlock, id: String) {
    self.source = .record(block)
    self.id = id
  }

  /// Makes the view of an ACP content block of a transcript entry.
  ///
  /// The view reads the ACP value directly. A registration of the
  /// ``ContentBlockRegistry`` for the kind of the block replaces the default
  /// view, and gets the same value.
  ///
  /// - Parameters:
  ///   - block: The ACP block to show, as the entry holds it.
  ///   - id: The id of the block view, unique in the thread, such as
  ///     `<row key>-<block index>`.
  public init(block: FoundationModelsACP.ContentBlock, id: String) {
    self.source = .wire(block)
    self.id = id
  }

  /// Makes the view of a block that is a kit block of a thread message or an
  /// ACP block of a transcript entry, such as a content part of a tool call.
  ///
  /// - Parameters:
  ///   - source: The block to show, as the record or the entry holds it.
  ///   - id: The id of the block view, unique in the thread.
  init(source: BlockSource<ContentBlock, FoundationModelsACP.ContentBlock>, id: String) {
    self.source = source
    self.id = id
  }

  /// The accessibility identifier of the default view of a kind.
  ///
  /// - Parameter kind: The block kind.
  /// - Returns: `content-block-<kind>`, such as `content-block-resourceLink`.
  public static func identifier(for kind: ContentBlock.Kind) -> String {
    identifier(named: kind)
  }

  /// The accessibility identifier of the default view of an ACP block kind.
  ///
  /// The kind names are the names of the kit kinds, so an ACP block and a kit
  /// block of one kind have the same identifier.
  ///
  /// - Parameter kind: The ACP block kind.
  /// - Returns: `content-block-<kind>`, such as `content-block-resourceLink`.
  static func identifier(of kind: FoundationModelsACP.ContentBlock.Kind) -> String {
    identifier(named: kind)
  }

  /// The accessibility identifier of the default view of a kind.
  ///
  /// - Parameter kind: The kit or ACP block kind. Its case name is the kind
  ///   name of the identifier.
  /// - Returns: `content-block-<kind>`.
  private static func identifier(named kind: some Sendable) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: String(describing: kind))
  }

  public var body: some View {
    switch source {
    case .record(let block):
      if block.isVisible(to: .user) {
        recordView(of: block)
          .contentContainer(identifier: Self.identifier(for: block.kind))
      }
    case .wire(let block):
      if block.isVisibleToUser {
        if let renderer = registry.resolve(kind: block.kind) {
          renderer(block)
        } else {
          wireView(of: block)
            .contentContainer(identifier: Self.identifier(of: block.kind))
        }
      }
    }
  }

  /// The default view of the kind of a kit block.
  ///
  /// - Parameter block: The kit block.
  /// - Returns: The default view.
  @ViewBuilder private func recordView(of block: ContentBlock) -> some View {
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
    case .unknown(let kind, let raw):
      UnknownItemView(kind: kind, raw: raw, id: id)
    }
  }

  /// The default view of the kind of an ACP block.
  ///
  /// - Parameter block: The ACP block.
  /// - Returns: The default view.
  @ViewBuilder private func wireView(of block: FoundationModelsACP.ContentBlock) -> some View {
    switch block {
    case .text(let text):
      TextBlockView(text: text.text, id: id)
    case .image(let image):
      ImageView(image: image)
    case .audio(let audio):
      AudioPlayerView(audio: audio)
    case .resourceLink(let link):
      LinkView(link: link)
    case .resource(let resource):
      ResourceBlockView(resource: resource, id: id)
    case .unknown(let kind, let raw):
      UnknownItemView(kind: kind, wireValue: raw, id: id)
    }
  }
}

nonisolated extension FoundationModelsACP.ContentBlock {
  /// Tells if the block is for the user.
  ///
  /// A block with no audience is for each audience. A block with an audience
  /// list is only for the audiences in the list. An unknown block has no
  /// annotations, so it is for the user.
  var isVisibleToUser: Bool {
    let annotations: FoundationModelsACP.Annotations? =
      switch self {
      case .text(let text): text.annotations
      case .image(let image): image.annotations
      case .audio(let audio): audio.annotations
      case .resourceLink(let link): link.annotations
      case .resource(let resource): resource.annotations
      case .unknown: nil
      }
    guard let audience = annotations?.audience else { return true }
    return audience.contains(.user)
  }
}
