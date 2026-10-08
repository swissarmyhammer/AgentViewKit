import FoundationModelsACP
import SwiftUI

/// The view of one content block of a message (plan.md §3.6, §9 A2).
///
/// The view shows an ACP `ContentBlock` that a transcript entry of a
/// `SessionModel` holds. It reads the ACP value directly, with no kit block
/// between the value and the view.
///
/// The view uses the registration of the ``ContentBlockRegistry`` for the
/// kind of the block when there is one, and gives it the ACP value. See
/// ``SwiftUI/View/contentBlockView(for:_:)``. Otherwise the view uses the
/// default view of the kind:
///
/// - text: a ``ResponseView``, through Textual.
/// - image: an ``ImageView``. A tap selects the image in the inspector.
/// - audio: an ``AudioPlayerView``, through AVKit.
/// - resource link: a ``LinkView`` card that opens the link in the browser.
/// - resource: the text through Textual, or an ``AttachmentChip`` for binary
///   contents.
/// - unknown: an ``UnknownItemView``.
///
/// Each default view is an accessibility container with the identifier
/// `content-block-<kind>`. A block that is not for the user shows nothing
/// and has no accessibility element.
public struct ContentBlockView: View {
  /// The start of the accessibility identifier of each default view.
  public static let identifierPrefix = "content-block-"

  /// The ACP block to show, as the transcript entry holds it.
  let block: FoundationModelsACP.ContentBlock

  /// The id of the block view.
  let id: String

  @Environment(\.contentBlockRegistry) private var registry

  /// Makes the view of an ACP content block of a transcript entry.
  ///
  /// The view reads the ACP value directly. A registration of the
  /// ``ContentBlockRegistry`` for the kind of the block replaces the default
  /// view, and gets the same value.
  ///
  /// - Parameters:
  ///   - block: The ACP block to show, as the entry holds it.
  ///   - id: The id of the block view, unique in the thread, such as
  ///     `<row key>-<block index>`. The text view keys its code blocks by
  ///     this id, and the unknown view keys its expanded state by it.
  public init(block: FoundationModelsACP.ContentBlock, id: String) {
    self.block = block
    self.id = id
  }

  /// The accessibility identifier of the default view of an ACP block kind.
  ///
  /// - Parameter kind: The ACP block kind. Its case name is the kind name of
  ///   the identifier.
  /// - Returns: `content-block-<kind>`, such as `content-block-resourceLink`.
  public static func identifier(for kind: FoundationModelsACP.ContentBlock.Kind) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: String(describing: kind))
  }

  public var body: some View {
    if block.isVisibleToUser {
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
      UnknownItemView(kind: kind, raw: raw, id: id)
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
