import FoundationModelsACP
import SwiftUI
import UniformTypeIdentifiers

/// The default view of an embedded resource block (plan.md §9 A2).
///
/// Text contents show through ``AttachmentTextContent``: a source type shows
/// in a ``CodeBlockView``, and other text shows through Textual. Binary
/// contents show through ``BlobResourceView``: the view writes the bytes to a
/// local file and shows that file in an ``AttachmentView``, so a press
/// selects the file in the inspector, as a message attachment does.
///
/// The view shows an ACP `EmbeddedResource` that a transcript entry holds.
/// The view reads the members of its raw JSON when it shows it. A resource
/// with no `uri`, or with no `text` and no base64 `blob`, shows its JSON in
/// an ``UnknownItemView``.
struct ResourceBlockView: View {
  /// The kind name of the raw view of a resource that the view cannot read.
  private static let rawKind = "resource"

  /// The file name stem of a resource with no file name in its URI.
  private static let fileStem = "resource"

  /// The ACP resource to show, as the transcript entry holds it.
  let resource: FoundationModelsACP.EmbeddedResource

  /// The id of the block view. It keys the expanded state of the raw view of
  /// a resource that the view cannot read.
  let id: String

  var body: some View {
    if let uri = resource.resourceURI, let text = resource.resourceText {
      Self.textView(text: text, uri: uri, mimeType: resource.resourceMimeType)
    } else if let uri = resource.resourceURI, let data = resource.resourceBlob {
      BlobResourceView(data: data, file: Self.blobFile(data: data, uri: uri, mimeType: resource.resourceMimeType))
    } else {
      UnknownItemView(kind: Self.rawKind, raw: resource.resource, id: id)
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

  /// The attachment of the block file of binary contents: the file that
  /// ``ContentBlockFile/write(_:named:)`` writes for the bytes.
  ///
  /// - Parameters:
  ///   - data: The bytes of the contents.
  ///   - uri: The URI of the resource.
  ///   - mimeType: The MIME type of the resource, or `nil`.
  /// - Returns: The attachment, also before the file exists.
  private static func blobFile(data: Data, uri: String, mimeType: String?) -> Attachment {
    ContentBlockFile.attachment(
      of: data, named: fileName(uri: uri, mimeType: mimeType),
      type: ContentBlockFile.type(mimeType: mimeType, fallback: .data))
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

#Preview("Text resource") {
  ResourceBlockView(resource: PreviewFixtures.textResource, id: "preview-resource-text")
    .padding()
}

#Preview("Binary resource") {
  ResourceBlockView(resource: PreviewFixtures.binaryResource, id: "preview-resource-binary")
    .padding()
}

#Preview("Resource with a long URI") {
  ResourceBlockView(resource: PreviewFixtures.longURIResource, id: "preview-resource-long-uri")
    .frame(width: PreviewFixtures.narrowWidth)
    .padding()
}
