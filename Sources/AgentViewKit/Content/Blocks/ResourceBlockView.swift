import FoundationModelsACP
import SwiftUI
import UniformTypeIdentifiers

/// The default view of an embedded resource block (plan.md §9 A2).
///
/// Text contents show through ``AttachmentTextContent``: a source type shows
/// in a ``CodeBlockView``, and other text shows through Textual. Binary
/// contents show as an ``AttachmentChip`` with the name, the type icon, and
/// the size of the resource.
///
/// The view shows a kit ``EmbeddedResource``, or an ACP `EmbeddedResource`
/// that a transcript entry holds. The view of an ACP resource reads the
/// members of its raw JSON when it shows it. An ACP resource with no `uri`,
/// or with no `text` and no base64 `blob`, shows its JSON in an
/// ``UnknownItemView``.
struct ResourceBlockView: View {
  /// The kind name of the raw view of an ACP resource that the view cannot
  /// read.
  private static let wireKind = "resource"

  /// The file name stem of a resource with no file name in its URI.
  private static let fileStem = "resource"

  /// The resource that the view shows.
  enum Source {
    /// A kit resource of a thread message.
    case record(EmbeddedResource)

    /// An ACP resource that a transcript entry holds, with the id that keys
    /// the expanded state of its raw view.
    case wire(FoundationModelsACP.EmbeddedResource, id: String)
  }

  /// The resource to show.
  let source: Source

  /// Makes the view of a kit resource.
  ///
  /// - Parameter resource: The resource to show.
  init(resource: EmbeddedResource) {
    self.source = .record(resource)
  }

  /// Makes the view of an ACP resource of a transcript entry.
  ///
  /// - Parameters:
  ///   - resource: The ACP resource to show, as the entry holds it.
  ///   - id: The id of the block view. It keys the expanded state of the raw
  ///     view of a resource that the view cannot read.
  init(resource: FoundationModelsACP.EmbeddedResource, id: String) {
    self.source = .wire(resource, id: id)
  }

  var body: some View {
    switch source {
    case .record(let resource):
      switch resource.contents {
      case .text(let text):
        Self.textView(text: text, uri: resource.uri, mimeType: resource.mimeType)
      case .blob(let data):
        Self.blobChip(data: data, uri: resource.uri, mimeType: resource.mimeType)
      }
    case .wire(let resource, let id):
      Self.wireView(of: resource, id: id)
    }
  }

  /// The view of an ACP resource.
  ///
  /// - Parameters:
  ///   - resource: The ACP resource.
  ///   - id: The id that keys the expanded state of the raw view.
  /// - Returns: The text view, the chip, or the raw view of a resource that
  ///   the view cannot read.
  @ViewBuilder private static func wireView(
    of resource: FoundationModelsACP.EmbeddedResource, id: String
  ) -> some View {
    if let uri = resource.resourceURI, let text = resource.resourceText {
      textView(text: text, uri: uri, mimeType: resource.resourceMimeType)
    } else if let uri = resource.resourceURI, let data = resource.resourceBlob {
      blobChip(data: data, uri: uri, mimeType: resource.resourceMimeType)
    } else {
      UnknownItemView(kind: wireKind, wireValue: resource.resource, id: id)
    }
  }

  /// The view of text contents.
  ///
  /// - Parameters:
  ///   - text: The text contents.
  ///   - uri: The URI of the resource.
  ///   - mimeType: The MIME type of the resource, or `nil`.
  /// - Returns: The text view.
  private static func textView(text: String, uri: String, mimeType: String?) -> some View {
    AttachmentTextContent(
      text: text,
      type: ContentBlockFile.type(mimeType: mimeType, fallback: .plainText),
      filename: fileName(uri: uri, mimeType: mimeType))
  }

  /// The chip of binary contents.
  ///
  /// - Parameters:
  ///   - data: The bytes of the contents.
  ///   - uri: The URI of the resource.
  ///   - mimeType: The MIME type of the resource, or `nil`.
  /// - Returns: The chip.
  private static func blobChip(data: Data, uri: String, mimeType: String?) -> some View {
    let name = fileName(uri: uri, mimeType: mimeType)
    return AttachmentChip(
      Attachment(
        id: AttachmentID(uri),
        url: URL(string: uri) ?? URL(filePath: name),
        type: ContentBlockFile.type(mimeType: mimeType, fallback: .data),
        name: name,
        size: data.count))
  }

  /// The file name of a resource: the last part of its URI, or `resource`
  /// with the extension of its MIME type.
  ///
  /// - Parameters:
  ///   - uri: The URI of the resource.
  ///   - mimeType: The MIME type of the resource, or `nil`.
  /// - Returns: The file name.
  private static func fileName(uri: String, mimeType: String?) -> String {
    ContentBlockFile.fileName(uri: uri, mimeType: mimeType, stem: fileStem)
  }
}
